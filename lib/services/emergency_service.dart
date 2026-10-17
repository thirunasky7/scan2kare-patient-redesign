import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/local_storage.dart';

class EmergencyService {
  static final String baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> bookEmergency({
    required int patientId,
    required int hospitalId,
    required String reason,
    String? notes,
    int? doctorId,
  }) async {
    final token = await LocalStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Authentication token missing. Please sign in again.");
    }

    final url = Uri.parse('$baseUrl/emergency-booking');

    final response = await http.post(
      url,
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "patient_id": patientId,
        "hospital_id": hospitalId,
        "reason": reason,
        if (notes != null && notes.isNotEmpty) "notes": notes,
        if (doctorId != null) "doctor_id": doctorId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      if (decoded['status'] == true || decoded['success'] == true) {
        return decoded['data'] ?? decoded;
      }
      throw Exception(decoded['message'] ?? 'Failed to book emergency.');
    }

    try {
      final decoded = jsonDecode(response.body);
      throw Exception(
        decoded['message'] ?? 'Server error (${response.statusCode})',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Server error (${response.statusCode})');
    }
  }
}
