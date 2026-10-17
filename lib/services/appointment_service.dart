import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AppointmentService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<bool> createAppointment({
    required int doctorId,
    required int hospitalId,
    required int patientId, // ✅ NEW
    required DateTime date,
    required String time,
    String notes = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception("Token is missing");
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final url = Uri.parse('$baseUrl/doctors/$doctorId/appointments');

    final response = await http.post(
      url,
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "patient_id": patientId, // ✅ IMPORTANT
        "appointment_date": formattedDate,
        "appointment_time": time,
        "notes": notes,
        "hospital_id": hospitalId,
      }),
    );

    // 🔍 Debug (very important)
    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);

      // Handle multiple API formats safely
      return decoded['success'] == true ||
          decoded['status'] == true ||
          decoded['status'] == 'success';
    } else {
      throw Exception(
        'Failed to create appointment: ${response.statusCode} ${response.body}',
      );
    }
  }

  static Future<List<String>> fetchSlots(int doctorId, DateTime date) async {
    // Format the date
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    // Create the base URL
    final url = '$baseUrl/doctor/$doctorId/available-slots';

    try {
      final response = await Dio().get(
        url,
        queryParameters: {
          'date': formattedDate,
        },
      );

      return List<String>.from(response.data['slots']);
    } catch (e) {
      if (e is DioException) {
        // print('Dio Error: ${e.message}');
      } else {
        // print('Other error: $e');
      }
      rethrow;
    }
  }

  static Future<bool> rescheduleAppointment({
    required int appointmentId,
    required DateTime newDate,
    required String newTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/reschedule-appointment"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
      body: {
        "appointment_id": appointmentId.toString(),
        "appointment_date": DateFormat('yyyy-MM-dd').format(newDate),
        "appointment_time": newTime,
      },
    );

    return response.statusCode == 200;
  }

  static Future<bool> rescheduleAppointmentUpdate({
    required int appointmentId,
    required int doctorId,
    required DateTime newDate,
    required String newTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final formattedDate = DateFormat('yyyy-MM-dd').format(newDate);

    final url = Uri.parse(
        "${ApiConfig.baseUrl}/doctors/$doctorId/appointments/$appointmentId");

    final response = await http.put(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "appointment_date": formattedDate,
        "appointment_time": newTime,
      }),
    );

    if (response.statusCode == 200) {
      //print("Reschedule Success: ${response.body}");
      return true;
    } else {
      //print("Reschedule Failed: ${response.body}");
      return false;
    }
  }
}
