class ScanAppointmentModel {
  final int appointmentId;
  final String? appointmentDate;
  final String? appointmentTime;
  final String? status;

  final String? patientName;
  final String? branchName; // center name
  final String? doctorName; // scan name
  final String? scanCategory;
  final String? profileImage;

  ScanAppointmentModel({
    required this.appointmentId,
    this.appointmentDate,
    this.appointmentTime,
    this.status,
    this.patientName,
    this.branchName,
    this.doctorName,
    this.scanCategory,
    this.profileImage,
  });

  factory ScanAppointmentModel.fromJson(Map<String, dynamic> json) {
    return ScanAppointmentModel(
      appointmentId: json['id'] ?? 0,
      appointmentDate: json['appointment_date']?.toString(),
      appointmentTime: json['appointment_time']?.toString(),
      status: json['status']?.toString(),
      patientName: json['patient_name']?.toString(),
      branchName: json['center_name']?.toString(),
      doctorName: json['scan_name']?.toString(),
      scanCategory: json['scan_category']?.toString(),
      profileImage: json['image']?.toString(),
    );
  }
}
