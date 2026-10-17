class PatientLiveView {
  const PatientLiveView({
    required this.live,
    required this.inQueue,
    required this.appointmentId,
    this.message,
    this.doctorStatus = '',
    this.sessionStatus = '',
    this.paused = false,
    this.emergency = false,
    this.state = '',
    this.checkedIn = false,
    this.isCurrent = false,
    this.patientsAhead = 0,
    this.etaMinutes,
    this.delayMinutes,
    this.plannedTime,
    this.etaStartAt,
  });

  final bool live;
  final bool inQueue;
  final int appointmentId;
  final String? message;
  final String doctorStatus;
  final String sessionStatus;
  final bool paused;
  final bool emergency;
  final String state;
  final bool checkedIn;
  final bool isCurrent;
  final int patientsAhead;
  final int? etaMinutes;
  final int? delayMinutes;
  final String? plannedTime;
  final DateTime? etaStartAt;

  int get queueNumber {
    if (!inQueue) return 0;
    if (isCurrent) return 1;
    return patientsAhead + 1;
  }

  bool get doctorUnavailable =>
      paused ||
      emergency ||
      doctorStatus == 'PAUSED' ||
      doctorStatus == 'EMERGENCY';

  factory PatientLiveView.fromJson(Map<String, dynamic> json) {
    return PatientLiveView(
      live: json['live'] == true,
      inQueue: json['in_queue'] == true,
      appointmentId: (json['appointment_id'] as num?)?.toInt() ?? 0,
      message: json['message'] as String?,
      doctorStatus: (json['doctor_status'] ?? '').toString(),
      sessionStatus: (json['session_status'] ?? '').toString(),
      paused: json['paused'] == true,
      emergency: json['emergency'] == true,
      state: (json['state'] ?? '').toString(),
      checkedIn: json['checked_in'] == true,
      isCurrent: json['is_current'] == true,
      patientsAhead: (json['patients_ahead'] as num?)?.toInt() ?? 0,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt(),
      delayMinutes: (json['delay_minutes'] as num?)?.toInt(),
      plannedTime: json['planned_time'] as String?,
      etaStartAt: json['eta_start_at'] != null
          ? DateTime.tryParse(json['eta_start_at'].toString())
          : null,
    );
  }
}

class PatientLiveEventPage {
  const PatientLiveEventPage({
    required this.events,
    this.latestEventId,
    this.sessionVersion,
  });

  final List<PatientLiveEvent> events;
  final int? latestEventId;
  final int? sessionVersion;
}

class PatientLiveEvent {
  const PatientLiveEvent({
    required this.eventId,
    required this.eventType,
    this.clientEvent,
    this.sessionVersion,
  });

  final int eventId;
  final String eventType;
  final String? clientEvent;
  final int? sessionVersion;

  factory PatientLiveEvent.fromJson(Map<String, dynamic> json) {
    return PatientLiveEvent(
      eventId: (json['event_id'] as num?)?.toInt() ?? 0,
      eventType: (json['event_type'] ?? '').toString(),
      clientEvent: json['client_event'] as String?,
      sessionVersion: (json['session_version'] as num?)?.toInt(),
    );
  }
}
