import 'doctor.dart';

class DoctorMetaResponse {
  final List<Doctor> doctors;
  final Map<int, String> departments;
  final Map<int, String> specializations;

  DoctorMetaResponse({
    required this.doctors,
    required this.departments,
    required this.specializations,
  });
}
