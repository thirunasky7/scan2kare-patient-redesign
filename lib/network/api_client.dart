import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/local_storage.dart';

class ApiClient {
  static Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final token = await LocalStorage.getToken();

    return http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body ?? {}),
    );
  }

  static Future<http.Response> get(String url) async {
    final token = await LocalStorage.getToken();

    return http.get(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
  }

  static Future<http.Response> put(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final token = await LocalStorage.getToken();

    return http.put(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body ?? {}),
    );
  }

  static Future<http.Response> delete(String url) async {
    final token = await LocalStorage.getToken();

    return http.delete(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
  }
}
