import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/live_appointment.dart';
import '../utils/token_storage.dart';

class LiveAppointmentService {
  static Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _dataOf(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid live queue response');
    }
    if ((decoded['status'] ?? '') == 'error') {
      throw Exception((decoded['message'] ?? 'Request failed').toString());
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    throw Exception('Invalid live queue response');
  }

  static Future<PatientLiveView> fetchLive(int appointmentId) async {
    final response = await http.get(
      Uri.parse(ApiConfig.liveAppointment(appointmentId)),
      headers: await _headers(),
    );
    if (response.statusCode == 403) {
      throw Exception('You are not allowed to view this appointment.');
    }
    if (response.statusCode == 401) {
      throw Exception('Please sign in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Unable to load live view';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
    return PatientLiveView.fromJson(_dataOf(response));
  }

  static Future<PatientLiveEventPage> fetchEvents(
    int appointmentId, {
    int? sinceId,
  }) async {
    final uri = Uri.parse(ApiConfig.liveAppointmentEvents(appointmentId))
        .replace(queryParameters: {
      'limit': '50',
      if (sinceId != null) 'since_id': '$sinceId',
    });
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const PatientLiveEventPage(events: []);
    }
    final data = _dataOf(response);
    final list = data['events'] as List? ?? [];
    return PatientLiveEventPage(
      events: list
          .whereType<Map<String, dynamic>>()
          .map(PatientLiveEvent.fromJson)
          .toList(),
      latestEventId: (data['latest_event_id'] as num?)?.toInt(),
      sessionVersion: (data['session_version'] as num?)?.toInt(),
    );
  }

  /// Check-in via V3. The POST body may include a full queue snapshot;
  /// callers must ignore it and reload [fetchLive] for a privacy-safe view.
  static Future<void> checkIn(int appointmentId) async {
    final response = await http.post(
      Uri.parse(ApiConfig.liveAppointmentCheckIn(appointmentId)),
      headers: await _headers(),
      body: jsonEncode({}),
    );
    if (response.statusCode == 403) {
      throw Exception('You are not allowed to check in for this visit.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body);
      final message = decoded is Map ? decoded['message'] : null;
      throw Exception((message ?? 'Check-in failed').toString());
    }
  }
}
