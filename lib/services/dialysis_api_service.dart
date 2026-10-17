import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../utils/token_storage.dart';
import '../utils/local_storage.dart';

class DialysisApiService {
  static Future<String> _token() async {
    return await TokenStorage.getToken() ??
        await LocalStorage.getToken() ??
        '';
  }

  static Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  static Future<List<dynamic>> getCenters({
    String? city,
    String? q,
  }) async {
    final token = await _token();
    final body = <String, dynamic>{};
    if (city != null && city.isNotEmpty) body['city'] = city;
    if (q != null && q.isNotEmpty) body['q'] = q;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/dialysis-centers'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    final data = _decode(response.body);
    if (response.statusCode == 200 && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    throw Exception(friendlyApiError(data, fallback: 'Could not load dialysis centres. Please try again.'));
  }

  static Future<Map<String, dynamic>> getCenterDetail(int id) async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/dialysis-center/$id'),
      headers: _headers(token),
    );
    final data = _decode(response.body);
    if (response.statusCode == 200 && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(friendlyApiError(data, fallback: 'Could not load this dialysis centre.'));
  }

  static Future<Map<String, dynamic>> getMachineSlots({
    required int machineId,
    required String date,
    int? ignoreBookingId,
  }) async {
    final token = await _token();
    final ignore = ignoreBookingId != null
        ? '&ignore_booking_id=$ignoreBookingId'
        : '';
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/dialysis-machines/$machineId/slots?date=$date$ignore',
      ),
      headers: _headers(token),
    );
    final data = _decode(response.body);
    if (response.statusCode == 200 && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(friendlyApiError(data, fallback: 'Could not load time slots. Please try another date.'));
  }

  static Future<Map<String, dynamic>> createBooking({
    required int patientId,
    required int centerId,
    required int branchId,
    required int machineId,
    required String bookingDate,
    required String slotTime,
    String? serviceType,
    String? notes,
  }) async {
    final token = await _token();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/dialysis-booking'),
      headers: _headers(token),
      body: jsonEncode({
        'patient_id': patientId,
        'dialysis_center_id': centerId,
        'dialysis_branch_id': branchId,
        'dialysis_machine_id': machineId,
        'booking_date': bookingDate,
        'slot_time': slotTime,
        if (serviceType != null) 'service_type': serviceType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    final data = _decode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        (data['success'] == true || data['status'] == true)) {
      return Map<String, dynamic>.from(data['data'] as Map? ?? {});
    }
    throw Exception(friendlyApiError(data, fallback: 'Could not complete the booking. Please try again.'));
  }

  static Future<Map<String, dynamic>> rescheduleBooking({
    required int bookingId,
    required String bookingDate,
    required String slotTime,
    int? branchId,
    int? machineId,
    String? notes,
  }) async {
    final token = await _token();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/dialysis-bookings/$bookingId'),
      headers: _headers(token),
      body: jsonEncode({
        'booking_date': bookingDate,
        'slot_time': slotTime,
        if (branchId != null) 'dialysis_branch_id': branchId,
        if (machineId != null) 'dialysis_machine_id': machineId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    final data = _decode(response.body);
    if (response.statusCode == 200 &&
        (data['success'] == true || data['status'] == true)) {
      return Map<String, dynamic>.from(data['data'] as Map? ?? {});
    }
    throw Exception(friendlyApiError(
      data,
      fallback: 'Could not reschedule this booking. Please try again.',
    ));
  }

  static Future<Map<String, dynamic>> getBookings() async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/dialysis-bookings'),
      headers: _headers(token),
    );
    final data = _decode(response.body);
    if (response.statusCode == 200 && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(friendlyApiError(data, fallback: 'Could not load your dialysis bookings.'));
  }

  static Future<void> cancelBooking(int id) async {
    final token = await _token();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/dialysis-bookings/$id'),
      headers: _headers(token),
    );
    final data = response.body.isNotEmpty ? _decode(response.body) : {};
    if (response.statusCode != 200) {
      throw Exception(friendlyApiError(data, fallback: 'Could not cancel this booking. Please try again.'));
    }
  }

  static Future<List<dynamic>> getFamilyProfiles() async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/patient/family-profiles'),
      headers: _headers(token),
    );
    final data = _decode(response.body);
    if (response.statusCode == 200 && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    throw Exception(friendlyApiError(data, fallback: 'Could not load family profiles.'));
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {}
    return {};
  }
}
