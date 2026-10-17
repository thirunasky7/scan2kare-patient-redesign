import 'doctor.dart';

class DoctorApiResponse {
  final List<Doctor> doctors;
  final Map<int, String> departments;
  final Map<int, String> specializations;

  DoctorApiResponse({
    required this.doctors,
    required this.departments,
    required this.specializations,
  });
}
