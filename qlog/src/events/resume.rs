use serde::Deserialize;
use serde::Serialize;

#[serde_with::skip_serializing_none]
#[derive(Serialize, Deserialize, Clone, PartialEq, Debug)]
pub struct CarefulResumePhaseUpdated {
    pub old_phase: Option<CarefulResumePhase>,
    pub new_phase: CarefulResumePhase,
    pub state_data: CarefulResumeStateParameters,
    pub restored_data: Option<CarefulResumeRestoredParameters>,
    pub trigger: Option<CarefulResumeTrigger>,
}

#[derive(Serialize, Deserialize, Copy, Clone, PartialEq, Eq, Debug)]
#[serde(rename_all = "snake_case")]
pub enum CarefulResumeTrigger {
    // for the Unvalidated phase, when no unvalidated packets
    CongestionWindowLimited, // Trigger for moving to unvalidated
    // for the Validating phase
    FirstUnvalidatedPacketAcknowledged,
    // for the Normal phase and no remaining unvalidated packets to be acknowledged
    LastUnvalidatedPacketAcknowledged,
    // for the Normal phase, when CR not allowed
    RttNotValidated, // Trigger for moving to normal, when CR not allowed
    // for the Normal phase, when sending fewer unvalidated packets than CWND permits
    RateLimited,
    // for the Safe Retreat phase, when loss detected
    PacketLoss, // Loss triggers moving to safe retreat
    // for the Safe Retreat phase, when ECN congestion experienced reported
    #[serde(rename = "ECN_CE")]
    EcnCe, // Trigger for moving to safe retreat.
    // for the Normal phase 1 RTT after a congestion event
    ExitRecovery, // Trigger for moving to normal 1rtt after a congestion event
}

#[derive(Serialize, Deserialize, Copy, Clone, PartialEq, Eq, Debug)]
#[serde(rename_all = "snake_case")]
pub enum CarefulResumePhase {
    Reconnaissance,
    Unvalidated,
    Validating,
    Normal,
    SafeRetreat,
}

#[serde_with::skip_serializing_none]
#[derive(Serialize, Deserialize, Copy, Clone, PartialEq, Eq, Debug)]
pub struct CarefulResumeStateParameters {
    pub pipesize: u64,
    pub first_unvalidated_packet: u64,
    pub last_unvalidated_packet: u64,
    pub congestion_window: Option<u64>,
    pub ssthresh: Option<u64>,
}

#[serde_with::skip_serializing_none]
#[derive(Serialize, Deserialize, Copy, Clone, PartialEq, Debug)]
pub struct CarefulResumeRestoredParameters {
    pub saved_congestion_window: u64,
    pub saved_rtt: f32,
}
