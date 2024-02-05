use std::time::{Duration, Instant};
use qlog::events::EventData;
use qlog::events::resume::*;
use crate::recovery::Acked;

const CR_EVENT_MAXIMUM_GAP: Duration = Duration::from_secs(60);

// No observe state as that always applies to the previous connection and never the current connection
#[derive(Default, Debug, Copy, Clone, Eq, PartialEq)]
pub enum CrState {
    #[default]
    Reconnaissance,
    // The next two states store the first packet sent when entering that state
    Unvalidated(u64),
    Validating(u64),
    // Stores the last packet sent during the Unvalidated Phase
    SafeRetreat(u64),
    Normal,
}

pub struct Resume {
    trace_id: String,
    enabled: bool,
    cr_state: CrState,
    previous_rtt: Duration,
    previous_cwnd: usize,
    pipesize: usize,

    #[cfg(feature = "qlog")]
    qlog_metrics: QlogMetrics,
    #[cfg(feature = "qlog")]
    last_trigger: Option<CarefulResumeTrigger>,
}

impl std::fmt::Debug for Resume {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "cr_state={:?} ", self.cr_state)?;
        write!(f, "previous_rtt={:?} ", self.previous_rtt)?;
        write!(f, "previous_cwnd={:?} ", self.previous_cwnd)?;
        write!(f, "pipesize={:?} ", self.pipesize)?;

        Ok(())
    }
}

impl Resume {
    pub fn new(trace_id: &str) -> Self {
        Self {
            trace_id: trace_id.to_string(),
            enabled: false,
            cr_state: CrState::default(),
            previous_rtt: Duration::ZERO,
            previous_cwnd: 0,
            pipesize: 0,

            #[cfg(feature = "qlog")]
            qlog_metrics: QlogMetrics::default(),
            #[cfg(feature = "qlog")]
            last_trigger: None
        }
    }

    pub fn setup(&mut self, previous_rtt: Duration, previous_cwnd: usize) {
        self.enabled = true;
        self.previous_rtt = previous_rtt;
        self.previous_cwnd = previous_cwnd;
        trace!("{} careful resume configured", self.trace_id);
    }

    pub fn reset(&mut self) {
        self.cr_state = CrState::default();
        self.pipesize = 0;
    }

    pub fn enabled(&self) -> bool {
        if self.enabled {
            self.cr_state != CrState::Normal
        } else {
            false
        }
    }

    #[inline]
    fn change_state(&mut self, state: CrState, trigger: CarefulResumeTrigger) {
        self.cr_state = state;
        #[cfg(feature = "qlog")] {
            self.last_trigger = Some(trigger);
        }
    }

    // Returns (new_cwnd, new_ssthresh), both optional
    pub fn process_ack(
        &mut self, largest_pkt_sent: u64, packet: &Acked, flightsize: usize
    ) -> (Option<usize>, Option<usize>) {
        match self.cr_state {
            CrState::Unvalidated(first_packet) => {
                self.pipesize += packet.size;
                if packet.pkt_num >= first_packet {
                    trace!("{} entering careful resume validating phase", self.trace_id);
                    // Store the last packet number that was sent in the Unvalidated Phase
                    self.change_state(CrState::Validating(largest_pkt_sent), CarefulResumeTrigger::CrMarkAcknowledged);
                    (Some(flightsize), None)
                } else {
                    (None, None)
                }
            }
            CrState::Validating(last_packet) => {
                self.pipesize += packet.size;
                if packet.pkt_num >= last_packet {
                    trace!("{} careful resume complete", self.trace_id);
                    self.change_state(CrState::Normal, CarefulResumeTrigger::CrMarkAcknowledged);
                }
                (None, None)
            }
            CrState::SafeRetreat(last_packet) => {
                if packet.pkt_num >= last_packet {
                    trace!("{} careful resume complete", self.trace_id);
                    self.change_state(CrState::Normal, CarefulResumeTrigger::ExitRecovery);
                    (None, Some(self.pipesize))
                } else {
                    self.pipesize += packet.size;
                    (None, None)
                }
            }
            _ => (None, None)
        }
    }

    pub fn send_packet(
        &mut self, rtt_sample: Duration, cwnd: usize, largest_pkt_sent: u64, app_limited: bool,
    ) -> usize {
        // Do nothing when data limited to avoid having insufficient data
        // to be able to validate transmission at a higher rate
        if app_limited {
            return 0;
        }

        if self.cr_state == CrState::Reconnaissance {
            let jump = (self.previous_cwnd / 2).saturating_sub(cwnd);

            if jump == 0 {
                self.change_state(CrState::Normal, CarefulResumeTrigger::CwndLimited);
                return 0;
            }

            // Confirm RTT is similar to that of the previous connection
            if rtt_sample <= self.previous_rtt / 2 || rtt_sample >= self.previous_rtt * 10 {
                trace!(
                    "{} current RTT too divergent from previous RTT - not using careful resume; \
                    rtt_sample={:?} previous_rtt={:?}",
                    self.trace_id, rtt_sample, self.previous_rtt
                );
                self.change_state(CrState::Normal, CarefulResumeTrigger::RttNotValidated);
                return 0;
            }

            // Store the first packet number that was sent in the Unvalidated Phase
            trace!("{} entering careful resume unvalidated phase", self.trace_id);
            self.change_state(CrState::Unvalidated(largest_pkt_sent), CarefulResumeTrigger::CwndLimited);
            self.pipesize = cwnd;
            // we return the jump in window, CC code handles the increase in cwnd
            return jump;
        }

        0
    }

    pub fn congestion_event(&mut self, largest_pkt_sent: u64) -> usize {
        match self.cr_state {
            CrState::Unvalidated(_) => {
                trace!("{} congestion during unvalidated phase", self.trace_id);

                // TODO: mark used CR parameters as invalid for future connections

                self.change_state(CrState::SafeRetreat(largest_pkt_sent), CarefulResumeTrigger::PacketLoss);
                self.pipesize / 2
            }
            CrState::Validating(p) => {
                trace!("{} congestion during validating phase", self.trace_id);

                // TODO: mark used CR parameters as invalid for future connections

                self.change_state(CrState::SafeRetreat(p), CarefulResumeTrigger::PacketLoss);
                self.pipesize / 2
            }
            CrState::Reconnaissance => {
                trace!("{} congestion during reconnaissance - abandoning careful resume", self.trace_id);

                self.change_state(CrState::Normal, CarefulResumeTrigger::PacketLoss);
                0
            }
            _ => {
                0
            }
        }
    }

    #[cfg(feature = "qlog")]
    pub fn maybe_qlog(&mut self, cwnd: usize, ssthresh: usize) -> Option<EventData> {
        let qlog_metrics = QlogMetrics {
            state: Some(self.cr_state),
            pipesize: self.pipesize as u64,
            cwnd: cwnd as u64,
            ssthresh: ssthresh as u64,
            trigger: self.last_trigger,
            previous_rtt: self.previous_rtt,
            previous_cwnd: self.previous_cwnd as u64,
        };

        self.qlog_metrics.maybe_update(qlog_metrics)
    }
}

pub struct CRMetrics {
    trace_id: String,
    iw: usize,
    min_rtt: Duration,
    cwnd: usize,
    last_update: Instant,
}

impl CRMetrics {
    pub fn new(trace_id: &str, iw: usize) -> Self {
        Self {
            trace_id: trace_id.to_string(),
            iw,
            min_rtt: Duration::ZERO,
            cwnd: 0,
            last_update: Instant::now(),
        }
    }

    // Implementation of the CR observe phase
    pub fn maybe_update(&mut self, new_min_rtt: Duration, new_cwnd: usize) -> Option<CREvent> {
        // Initial guess at something that might work, needs further research
        let now = Instant::now();
        let time_since_last_update = now - self.last_update;

        let should_update = if new_cwnd < self.iw * 4 {
            false
        } else if time_since_last_update > CR_EVENT_MAXIMUM_GAP {
            true
        } else {
            let secs_since_last_update = time_since_last_update.as_secs_f64();
            if secs_since_last_update == 0.0 {
                false
            } else {
                let range = 1.0f64 / secs_since_last_update;

                let min_rtt_micros = self.min_rtt.as_micros() as f64;
                let min_rtt_range_spread = min_rtt_micros * range;
                let min_rtt_range_min = min_rtt_micros - min_rtt_range_spread;
                let min_rtt_range_max = min_rtt_micros + min_rtt_range_spread;

                let cwnd = self.cwnd as f64;
                let cwnd_range_spread = cwnd * range;
                let cwnd_range_min = cwnd - cwnd_range_spread;
                let cwnd_range_max = cwnd + cwnd_range_spread;

                let new_min_rtt_micros = new_min_rtt.as_micros() as f64;
                let new_cwnd_float = new_cwnd as f64;

                new_min_rtt_micros < min_rtt_range_min || new_min_rtt_micros > min_rtt_range_max ||
                    new_cwnd_float < cwnd_range_min || new_cwnd_float > cwnd_range_max
            }
        };

        trace!(
            "{} maybe_update(new_min_rtt={:?}, new_cwnd={}); updating={}",
            self.trace_id, new_min_rtt, new_cwnd, should_update
        );

        if should_update {
            self.min_rtt = new_min_rtt;
            self.cwnd = new_cwnd;
            self.last_update = now;

            Some(CREvent {
                cwnd: new_cwnd,
                min_rtt: new_min_rtt,
            })
        } else {
            None
        }
    }
}

/// An update in Careful Resume observed parameters to be stored/transmitted for future connections
#[derive(Clone, Copy, Debug)]
pub struct CREvent {
    /// A windowed minimum round-trip-time observation
    pub min_rtt: Duration,
    /// The current congestion window, in bytes
    pub cwnd: usize,
}

#[derive(Default)]
#[cfg(feature = "qlog")]
struct QlogMetrics {
    state: Option<CrState>,
    pipesize: u64,
    cwnd: u64,
    ssthresh: u64,
    trigger: Option<CarefulResumeTrigger>,
    previous_rtt: Duration,
    previous_cwnd: u64,
}

#[cfg(feature = "qlog")]
impl QlogMetrics {
    fn map_state(state: CrState) -> CarefulResumePhase {
        match state {
            CrState::Reconnaissance => CarefulResumePhase::Reconnaissance,
            CrState::Unvalidated(_) => CarefulResumePhase::Unvalidated,
            CrState::Validating(_) => CarefulResumePhase::Validating,
            CrState::SafeRetreat(_) => CarefulResumePhase::SafeRetreat,
            CrState::Normal => CarefulResumePhase::Normal,
        }
    }

    fn map_cr_mark(state: CrState) -> u64 {
        match state {
            CrState::Reconnaissance | CrState::Normal => 0,
            CrState::Unvalidated(m) | CrState::Validating(m) | CrState::SafeRetreat(m) => m,
        }
    }

    fn maybe_update(&mut self, latest: Self) -> Option<EventData> {
        if let Some(new_state) = latest.state {
            if self.state != Some(new_state) {
                let old_state = self.state;
                self.state = Some(new_state);
                self.pipesize = latest.pipesize;
                self.trigger = latest.trigger;
                self.cwnd = latest.cwnd;
                self.ssthresh = latest.ssthresh;
                self.previous_rtt = latest.previous_rtt;
                self.previous_cwnd = latest.previous_cwnd;

                Some(EventData::CarefulResumePhaseUpdated(CarefulResumePhaseUpdated {
                    old: old_state.map(Self::map_state),
                    new: Self::map_state(new_state),
                    state_data: CarefulResumeStateParameters {
                        pipesize: latest.pipesize,
                        cr_mark: Self::map_cr_mark(new_state),
                        cwnd: Some(latest.cwnd),
                        ssthresh: Some(latest.ssthresh),
                    },
                    restored_data: if latest.previous_rtt != Duration::ZERO || latest.previous_cwnd != 0 {
                        Some(CarefulResumeRestoredParameters {
                            previous_cwnd: latest.previous_cwnd,
                            previous_rtt: latest.previous_rtt.as_secs_f32() * 1000.0
                        })
                    } else {
                        None
                    },
                    trigger: latest.trigger,
                }))
            } else {
                None
            }
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use smallvec::smallvec;
    use crate::{CongestionControlAlgorithm, packet, ranges};
    use crate::recovery::{HandshakeStatus, Recovery, Sent};
    use super::*;

    // for cwnd > jump window, check crstate moves to normal
    #[test]
    fn cwnd_larger_than_jump() {
        let mut r = Resume::new("");
        r.setup(Duration::ZERO, 12_000);
        r.send_packet(Duration::ZERO, 15_000, 50, false);

        assert_eq!(r.cr_state, CrState::Normal);
    }

    // for a set rtt that does not meet the conditions, check crstate moves to normal
    #[test]
    fn rtt_less_than_half() {
        let mut r = Resume::new("");
        r.setup(Duration::from_millis(50), 12_000);
        r.send_packet(Duration::from_millis(10), 1_350, 10, false);

        assert_eq!(r.cr_state, CrState::Normal);
    }

    #[test]
    fn rtt_greater_than_10() {
        let mut r = Resume::new("");
        r.setup(Duration::from_millis(50), 12_000);
        r.send_packet(Duration::from_millis(600), 1_350, 10, false);

        assert_eq!(r.cr_state, CrState::Normal);
    }

    // for a set rtt that meets the conditions and assuming cwnd = jump window already, check we move to unvalidated
    #[test]
    fn valid_rtt() {
        let mut r = Resume::new("");
        r.setup(Duration::from_millis(50), 12_000);

        let jump = r.send_packet(Duration::from_millis(60), 1_350, 10, false);
        assert_eq!(jump, 4_650);

        assert_eq!(r.cr_state, CrState::Unvalidated(10));
        assert_eq!(r.pipesize, 1_350);
    }

    #[test]
    fn invalid_rtt_full() {
        let mut cfg = crate::Config::new(crate::PROTOCOL_VERSION).unwrap();
        cfg.set_cc_algorithm(CongestionControlAlgorithm::Reno);
        cfg.enable_resume(true);

        let mut r = Recovery::new(&cfg, "");
        let mut now = Instant::now();

        r.setup_careful_resume(Duration::from_millis(30), 120_000);

        assert_eq!(r.sent[packet::Epoch::Application].len(), 0);

        for i in 0..4 {
            let p = Sent {
                pkt_num: i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Reconnaissance);

        now += Duration::from_millis(10);

        let mut acked = ranges::RangeSet::default();
        acked.insert(0..4);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        // Send significantly more than the CWND to enter app limited
        for i in 0..20 {
            let p = Sent {
                pkt_num: 4 + i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Normal);
    }


    #[test]
    fn cr_full() {
        let mut cfg = crate::Config::new(crate::PROTOCOL_VERSION).unwrap();
        cfg.set_cc_algorithm(CongestionControlAlgorithm::Reno);
        cfg.enable_resume(true);

        let mut r = Recovery::new(&cfg, "");
        let mut now = Instant::now();

        r.setup_careful_resume(Duration::from_millis(30), 120_000);

        assert_eq!(r.sent[packet::Epoch::Application].len(), 0);

        for i in 0..4 {
            let p = Sent {
                pkt_num: i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Reconnaissance);

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(0..4);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        // Send significantly more than the CWND to enter app limited
        for i in 0..20 {
            let p = Sent {
                pkt_num: 4 + i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Unvalidated(15));
        assert_eq!(r.congestion_window, 60_000);

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(4..15);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        assert_eq!(r.resume.cr_state, CrState::Unvalidated(15));

        let mut acked = ranges::RangeSet::default();
        acked.insert(15..16);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        assert_eq!(r.resume.cr_state, CrState::Validating(23));

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(16..24);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        assert_eq!(r.resume.cr_state, CrState::Normal);
    }

    #[test]
    fn reconnaissance_congestion_full() {
        let mut cfg = crate::Config::new(crate::PROTOCOL_VERSION).unwrap();
        cfg.set_cc_algorithm(CongestionControlAlgorithm::Reno);
        cfg.enable_resume(true);

        let mut r = Recovery::new(&cfg, "");
        let mut now = Instant::now();

        r.setup_careful_resume(Duration::from_millis(30), 120_000);

        assert_eq!(r.sent[packet::Epoch::Application].len(), 0);

        for i in 0..4 {
            let p = Sent {
                pkt_num: i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Reconnaissance);

        now += Duration::from_millis(25);

        // Ack with one missing
        let mut acked = ranges::RangeSet::default();
        acked.insert(1..4);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((1, 1000))
        );

        assert_eq!(r.resume.cr_state, CrState::Normal);
    }

    #[test]
    fn congestion_full() {
        let mut cfg = crate::Config::new(crate::PROTOCOL_VERSION).unwrap();
        cfg.set_cc_algorithm(CongestionControlAlgorithm::Reno);
        cfg.enable_resume(true);

        let mut r = Recovery::new(&cfg, "");
        let mut now = Instant::now();

        r.setup_careful_resume(Duration::from_millis(30), 120_000);

        assert_eq!(r.sent[packet::Epoch::Application].len(), 0);

        for i in 0..4 {
            let p = Sent {
                pkt_num: i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Reconnaissance);

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(0..4);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        assert_eq!(r.resume.cr_state, CrState::Reconnaissance);

        // Send significantly more than the CWND to enter app limited
        for i in 0..20 {
            let p = Sent {
                pkt_num: 4 + i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Unvalidated(15));
        assert_eq!(r.congestion_window, 60_000);
        let mut expected_pipesize = r.resume.pipesize;

        now += Duration::from_millis(25);

        // Ack with one missing
        let mut acked = ranges::RangeSet::default();
        acked.insert(5..15);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((1, 1000))
        );

        assert_eq!(r.resume.cr_state, CrState::SafeRetreat(23));
        assert_eq!(r.congestion_window, 12_000);
        expected_pipesize += 10_000;
        assert_eq!(r.resume.pipesize, expected_pipesize);

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(16..24);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((1, 1000))
        );

        assert_eq!(r.resume.cr_state, CrState::Normal);
        expected_pipesize += 7_000;
        assert_eq!(r.resume.pipesize, expected_pipesize);
        assert_eq!(r.ssthresh, expected_pipesize);
    }

    #[test]
    fn congestion_full_2() {
        let mut cfg = crate::Config::new(crate::PROTOCOL_VERSION).unwrap();
        cfg.set_cc_algorithm(CongestionControlAlgorithm::Reno);
        cfg.enable_resume(true);

        let mut r = Recovery::new(&cfg, "");
        let mut now = Instant::now();

        r.setup_careful_resume(Duration::from_millis(30), 120_000);

        assert_eq!(r.sent[packet::Epoch::Application].len(), 0);

        for i in 0..4 {
            let p = Sent {
                pkt_num: i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Reconnaissance);

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(0..4);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        assert_eq!(r.resume.cr_state, CrState::Reconnaissance);

        // Send significantly more than the CWND to enter app limited
        for i in 0..20 {
            let p = Sent {
                pkt_num: 4 + i as u64,
                frames: smallvec![],
                time_sent: now,
                time_acked: None,
                time_lost: None,
                size: 1000,
                ack_eliciting: true,
                in_flight: true,
                delivered: 0,
                delivered_time: now,
                first_sent_time: now,
                is_app_limited: false,
                tx_in_flight: 0,
                lost: 0,
                has_data: false,
            };

            r.on_packet_sent(
                p,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
            );
            assert_eq!(r.sent[packet::Epoch::Application].len(), i + 1);
            assert_eq!(r.bytes_in_flight, 1000 * (i + 1));
        }

        assert_eq!(r.resume.cr_state, CrState::Unvalidated(15));
        assert_eq!(r.congestion_window, 60_000);
        let mut expected_pipesize = r.resume.pipesize;

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(4..16);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        assert_eq!(r.resume.cr_state, CrState::Validating(23));
        expected_pipesize += 12_000;
        assert_eq!(r.resume.pipesize, expected_pipesize);

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(17..20);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((1, 1000))
        );

        assert_eq!(r.resume.cr_state, CrState::SafeRetreat(23));
        expected_pipesize += 3_000;
        assert_eq!(r.resume.pipesize, expected_pipesize);

        now += Duration::from_millis(25);

        let mut acked = ranges::RangeSet::default();
        acked.insert(20..24);

        assert_eq!(
            r.on_ack_received(
                &acked,
                25,
                packet::Epoch::Application,
                HandshakeStatus::default(),
                now,
                "",
                &mut Vec::new(),
            ),
            Ok((0, 0))
        );

        assert_eq!(r.resume.cr_state, CrState::Normal);
        expected_pipesize += 3_000;
        assert_eq!(r.resume.pipesize, expected_pipesize);
        assert_eq!(r.ssthresh, expected_pipesize);
    }
}