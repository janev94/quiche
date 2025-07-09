use serde::Deserialize;
use serde::Serialize;

#[serde_with::skip_serializing_none]
#[derive(Serialize, Deserialize, Clone, PartialEq, Debug)]
pub struct CarefulResumePhaseUpdated {
    pub old: Option<CarefulResumePhase>,
    pub new: CarefulResumePhase,
    pub state_data: CarefulResumeStateParameters,
    pub restored_data: Option<CarefulResumeRestoredParameters>,
    pub trigger: Option<CarefulResumeTrigger>,
}

#[derive(Serialize, Deserialize, Copy, Clone, PartialEq, Eq, Debug)]
#[serde(rename_all = "snake_case")]
pub enum CarefulResumeTrigger {
    /*
//<<<<<<< HEAD
    //When sender has confirmed the RTT, has received an ACK for the initial data 
    //without reported congestion and has more data to send than the CWND would allow
    CongestionWindowLimited, // Trigger for moving from recon to unvalidated
    //If the current_rtt is not confirmed the sender MUST enter the normal phase
    RttNotValidated, // Trigger for moving from recon and unvalidated to normal, when CR not allowed
    //Completed sending all unvalidated packets e.g. when flight_size is
    //equal to the CWND after the jump
    LastUnvalidatedPacketSent, //NEW Trigger for moving from unvalidated to validated
    //The sender enters the validating phase when an ACK is received for the
    //first packet number (or higher) sent in the unvalidated phase.
    FirstUnvalidatedPacketAcknowledged, //NEW Trigger for moving from unvalidated to validated
    //When greater than 1 RTT has passed in unvalidated phase
    RTTExceeded, //NEW Trigger for moving from unvalidated to validated
    //If the flight_size is less than or equal to the PipeSize seeder enters normal phase
    RateLimited, //NEW Trigger for moving from unvalidated to normal
    //The sender enters the normal phase when an ACK is received for the last packet
    //number (or higher) that was sent in the unvalidated phase.
    LastUnvalidatedPacketAcknowledged, // Trigger for moving from validated to normal
    //If a sender determines that it is not valid to use the previous CC parameters
    //due to a detected path change e.g. a change in RTT or an explicit signal
    //indicating a path change
    PathChanged, //NEW Trigger for moving from unvalidated to safe retreat
    //If a sender determines that congestion was experienced e.g. packet loss, the
    //sender enters the safe retreat phase. If the sender determines congestion
    //was experienced in the recon phase, the sender enters the normal phase.
    PacketLoss, // Trigger for moving from unvalidated to safe retreat or recon to normal
    //If a sender determines that congestion was experienced e.g. ECN-CE marking, sender enters the
    //safe retreat phase. If the sender determines congestion was experienced in the recon phase,
    //the sender enters the normal phase.
    #[serde(rename = "ECN_CE")]
    EcnCe, // Trigger for moving to safe retreat.
    //The sender enters the normal phase when the last packet sent in the unvalidated phase is ACKed.
    ExitRecovery, // Trigger for moving to normal 1rtt after a congestion event
//=======
*/
    /// From Recon to Unvalidated
    /// When sender has confirmed the RTT, has received an ACK for the initial
    /// data without reported congestion and has more data to send than the CWND
    /// would allow.
    #[serde(rename = "cwnd_limited")]
    CongestionWindowLimited,
    /// From Recon/Unvalidated to Normal
    /// If the current_rtt is not confirmed the sender MUST enter the Normal
    /// Phase.
    RttNotValidated,
    /// From Unvalidated to Normal
    /// Completed sending all packets, e.g., when flight_size is equal to the
    /// CWND after the jump
    LastUnvalidatedPacketSent,
    /// From Unvalidated to Validating
    /// The sender enters the Validating Phase when an ACK is received for the
    /// first packet number (or higher) sent in the Unvalidated Phase.
    FirstUnvalidatedPacketAcknowledged,
    /// From Unvalidated to Validating
    /// When greater than 1 RTT has passed in Unvalidated Phase.
    RttExceeded,
    /// From Unvalidated to Normal
    /// If the flight_size is less than or equal to the PipeSize sender enters
    /// Normal Phase.
    RateLimited,
    /// From Validating to Normal
    /// The sender enters the Normal Phase when an ACK is received for the last
    /// packet number (or higher) that was sent in the Unvalidated Phase.
    LastUnvalidatedPacketAcknowledged,
    /// From Unvalidated/Validating to Safe Retreat
    /// If a sender determines that congestion was experienced, e.g., packet
    /// loss, the sender enters the Safe Retreat Phase.
    PacketLoss,
    /// From Unvalidated/Validating to Safe Retreat
    /// If a sender determines that congestion was experienced, e.g., ECN-CE
    /// marking, sender enters the Safe Retreat Phase.
    #[serde(rename = "ECN_CE")]
    EcnCe,
    /// From Safe Retreat to Normal
    /// The sender enters the Normal Phase when the last packet sent in the
    /// Unvalidated Phase is ACKed.
    ExitRecovery,
//>>>>>>> 4778638d49f4033bfd6b03a67112eb6cd63855d9
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
//<<<<<<< HEAD
    pub previous_congestion_window: u64,
    pub previous_rtt: f32,
//=======
    pub saved_congestion_window: u64,
    pub saved_rtt: f32,
//>>>>>>> 4778638d49f4033bfd6b03a67112eb6cd63855d9
}
