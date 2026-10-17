import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/token_storage.dart';

class ScanApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<String> _token() async {
    return await TokenStorage.getToken() ?? "";
  }

  static Future<List<dynamic>> getDiagnosticCenters(
    double lat,
    double lng,
  ) async {
    final token = await _token();

    final response = await http.post(
      Uri.parse("$baseUrl/diagnostic-centers"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
      body: {
        "latitude": lat.toString(),
        "longitude": lng.toString(),
      },
    );

    final body = jsonDecode(response.body);
    return body is Map && body['data'] is List ? List.from(body['data']) : [];
  }

  static Future<List<dynamic>> getCategories(
    int centerId,
  ) async {
    final token = await _token();

    final response = await http.get(
      Uri.parse("$baseUrl/scan-categories/$centerId"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    final body = jsonDecode(response.body);
    return body is Map && body['data'] is List ? List.from(body['data']) : [];
  }

  /// Center-scoped scan types for a category (same catalog as website).
  static Future<List<dynamic>> getScanTypes({
    required int categoryId,
    required int centerId,
  }) async {
    final token = await _token();

    final response = await http.get(
      Uri.parse(
        "$baseUrl/types-category-scans/$categoryId?center_id=$centerId",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    final body = jsonDecode(response.body);
    return body is Map && body['data'] is List ? List.from(body['data']) : [];
  }

  /// Available 30-min booking slots for center + scan + date.
  static Future<Map<String, dynamic>> getSlots({
    required int centerId,
    required int scanTypeId,
    required String date,
  }) async {
    final token = await _token();

    final response = await http.get(
      Uri.parse(
        "$baseUrl/diagnostic-centers/$centerId/scan-types/$scanTypeId/slots?date=$date",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    final body = jsonDecode(response.body);
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data']);
    }
    return {
      'slots': <dynamic>[],
      'message': body is Map
          ? (body['message']?.toString() ?? 'No slots available')
          : 'No slots available',
    };
  }

  static Future<List<dynamic>> getlabsCenters(
    double lat,
    double lng,
  ) async {
    final token = await _token();

    final response = await http.post(
      Uri.parse("$baseUrl/labs"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
      body: {
        "latitude": lat.toString(),
        "longitude": lng.toString(),
      },
    );

    final body = jsonDecode(response.body);
    return body is Map && body['data'] is List ? List.from(body['data']) : [];
  }
}
