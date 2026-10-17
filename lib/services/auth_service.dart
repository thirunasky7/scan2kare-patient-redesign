import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/token_storage.dart';
import '../utils/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sendOtp),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "phone": phone,
        }),
      );

      Map<String, dynamic>? body;
      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            body = decoded;
          } else if (decoded is Map) {
            body = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }

      final message = (body?['message'] ?? '').toString().trim();
      final status = body?['status'];
      final statusOk = status == true ||
          status == 1 ||
          status == '1' ||
          status == 'true' ||
          status == 'success';

      if (response.statusCode == 200 && (body == null || statusOk || status == null)) {
        return {
          'success': true,
          'message': message.isNotEmpty ? message : 'OTP sent successfully',
        };
      }

      return {
        'success': false,
        'message': message.isNotEmpty
            ? message
            : 'Failed to send OTP',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp, {
    String? pendingPath,
  }) async {
    try {
      final body = <String, dynamic>{
        'phone': phone,
        'otp': otp,
      };
      if (pendingPath != null && pendingPath.isNotEmpty) {
        body['pending_path'] = pendingPath;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.verifyOtp),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final token = data['token']?.toString();
        final username = data['data'] is Map
            ? data['data']['name']?.toString()
            : null;

        if (token != null && token.isNotEmpty) {
          await TokenStorage.saveToken(token);
          if (username != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_name', username);
          }
        }

        return data;
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorBody is Map
              ? (errorBody['message'] ?? 'Invalid OTP')
              : 'Invalid OTP',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<bool> logout() async {
    final token = await TokenStorage.getToken();

    try {
      if (token != null && token.isNotEmpty) {
        // Correct patient API route (auth:api → PatientAuthController@logout).
        await http
            .post(
              Uri.parse('$baseUrl/patient/logout'),
              headers: {
                "Accept": "application/json",
                "Authorization": "Bearer $token",
              },
            )
            .timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      // Always clear locally even if API fails.
    }

    await LocalStorage.clear();
    return true;
  }

  /// Soft-delete / deactivate patient account on the server.
  /// Returns `{success: bool, message: String}`.
  static Future<Map<String, dynamic>> deleteAccount() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Please login again'};
    }

    final headers = <String, String>{
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    // Backend method is updateDelete(); routes may vary by deploy.
    final attempts = <({String method, String url})>[
      (method: 'POST', url: '$baseUrl/profile/delete'),
      (method: 'POST', url: '$baseUrl/patient/delete'),
      (method: 'DELETE', url: '$baseUrl/profile/delete'),
      (method: 'POST', url: '$baseUrl/patient/update-delete'),
    ];

    String lastMessage = 'Delete failed';

    for (final attempt in attempts) {
      try {
        late final http.Response response;
        final uri = Uri.parse(attempt.url);
        if (attempt.method == 'DELETE') {
          response = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
        } else {
          response = await http
              .post(uri, headers: headers, body: '{}')
              .timeout(const Duration(seconds: 20));
        }

        Map<String, dynamic>? body;
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              body = decoded;
            } else if (decoded is Map) {
              body = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {
            // Non-JSON (HTML error page, etc.)
          }
        }

        final okStatus = response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204;

        final statusVal = body?['status'];
        final statusOk = statusVal == true ||
            statusVal == 1 ||
            statusVal == '1' ||
            statusVal == 'true' ||
            statusVal == 'success' ||
            body?['success'] == true;

        final msg = (body?['message'] ?? '').toString();
        if (msg.isNotEmpty) lastMessage = msg;

        // 404/405 → try next route/method
        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }

        if (okStatus && (body == null || statusOk || statusVal == null)) {
          await LocalStorage.clear();
          return {
            'success': true,
            'message': msg.isNotEmpty ? msg : 'Account deleted successfully',
          };
        }

        // Auth failure — stop trying
        if (response.statusCode == 401 || response.statusCode == 403) {
          return {
            'success': false,
            'message':
                msg.isNotEmpty ? msg : 'Session expired. Please login again.',
          };
        }

        // Explicit API failure (or server error) — stop and report
        if (body != null || response.statusCode >= 500) {
          return {
            'success': false,
            'message': msg.isNotEmpty
                ? msg
                : 'Delete failed (${response.statusCode})',
          };
        }

        lastMessage = 'Delete failed (${response.statusCode})';
      } catch (e) {
        lastMessage = 'Network error. Please try again.';
      }
    }

    return {'success': false, 'message': lastMessage};
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final token = await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token is missing");
    }

    final response = await http.get(
      Uri.parse('$baseUrl/patient/profile'),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to get user profile: ${response.statusCode}");
    }

    final decoded = json.decode(response.body);
    return decoded['data'] ?? {};
  }
}
