import 'dart:convert';
import '../config/api_config.dart';
import '../network/api_client.dart';

class PatientService {
  static Future<Map<String, dynamic>?> getProfile() async {
    final response = await ApiClient.get(
      "${ApiConfig.baseUrl}/patient/profile",
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
