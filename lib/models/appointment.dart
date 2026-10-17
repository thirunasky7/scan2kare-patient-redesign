class AppointmentModel {
  final int appointmentId;
  final int doctorId;
  final int hospitalId;
  final String doctorName;
  final String specialization;
  final String branchName;
  final String hospitalName;
  final String profileImage;
  final String appointmentDate;
  final String appointmentTime;
  final String status;
  final String departmentName;

  AppointmentModel({
    required this.appointmentId,
    required this.doctorId,
    required this.hospitalId,
    required this.doctorName,
    required this.specialization,
    required this.branchName,
    required this.hospitalName,
    required this.profileImage,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    required this.departmentName,
  });

  /// Prefer specialization name; never show a numeric ID as the label.
  static String _specializationName(Map<String, dynamic> json) {
    final named = (json['specialization_name'] ?? '').toString().trim();
    if (named.isNotEmpty && int.tryParse(named) == null) return named;

    final raw = (json['specialization'] ?? '').toString().trim();
    if (raw.isNotEmpty && int.tryParse(raw) == null) return raw;

    return '';
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final hospitalName = (json['hospital_name'] ?? '').toString().trim();
    final branchName = (json['branch_name'] ?? '').toString().trim();

    return AppointmentModel(
      appointmentId:
          int.tryParse(json['appointment_id']?.toString() ?? '') ?? 0,
      doctorId: int.tryParse(json['doctor_id']?.toString() ?? '') ?? 0,
      hospitalId: int.tryParse(json['hospital_id']?.toString() ?? '') ?? 0,
      doctorName: json['doctor_name']?.toString() ?? '',
      specialization: _specializationName(json),
      branchName: branchName,
      hospitalName: hospitalName.isNotEmpty ? hospitalName : branchName,
      profileImage: json['profile_image']?.toString() ?? '',
      appointmentDate: json['appointment_date']?.toString() ?? '',
      appointmentTime: json['appointment_time']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      departmentName: json['department_name']?.toString() ?? '',
    );
  }
}
