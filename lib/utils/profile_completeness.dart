/// Helpers to decide if a patient must complete basic profile once after OTP.
import 'app_date_format.dart';

class ProfileCompleteness {
  /// True when name / gender / dob / address are missing (first-time setup needed).
  static bool isIncomplete(Map<String, dynamic>? user) {
    if (user == null) return true;

    if (user['is_new_user'] == true ||
        user['is_new_user'] == 1 ||
        user['is_new_user']?.toString() == '1') {
      return true;
    }

    if (user['profile_completed'] == false ||
        user['profile_completed'] == 0 ||
        user['profile_completed']?.toString() == '0') {
      return true;
    }

    final name = (user['name'] ?? '').toString().trim();
    final address = (user['address'] ?? '').toString().trim();
    final gender = (user['gender'] ?? '').toString().trim();
    final dob = (user['dob'] ?? '').toString().trim();

    return name.isEmpty ||
        address.isEmpty ||
        gender.isEmpty ||
        dob.isEmpty;
  }

  /// Approximate DOB (Jan 1) from age for backends that only store dob.
  static String dobFromAge(int age) {
    final year = DateTime.now().year - age;
    return '$year-01-01';
  }

  /// Age from dob string, or null if invalid.
  static int? ageFromDob(String? dob) {
    return AppDateFormat.ageFromDob(dob);
  }
}
