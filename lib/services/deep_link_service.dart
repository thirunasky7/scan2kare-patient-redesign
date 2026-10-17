import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../router/app_router.dart';
import '../utils/local_storage.dart';
import '../utils/profile_completeness.dart';
import '../utils/token_storage.dart';

class DeepLinkService {
  static const String pendingDeepLinkPathKey = 'pending_deeplink_path';

  static const _protectedPrefixes = [
    '/view-hospital-details',
    '/view-doctor-profile',
    '/view-doctor-details',
    '/view-diagnostic-center-detail',
    '/view-dialysis-center-detail',
    '/appointments',
  ];

  // ---------------------------------------------------------------------------
  // URI / path helpers
  // ---------------------------------------------------------------------------

  static String uriToLocation(Uri uri) {
    if (uri.query.isNotEmpty) {
      return '${uri.path}?${uri.query}';
    }
    return uri.path;
  }

  static String? extractPathFromUri(Uri uri) {
    if (uri.scheme == 'scan2kare') {
      final queryPath = uri.queryParameters['path'];
      if (queryPath != null && queryPath.isNotEmpty) {
        return queryPath.startsWith('/') ? queryPath : '/$queryPath';
      }
      if (uri.pathSegments.isNotEmpty) {
        return '/${uri.pathSegments.join('/')}';
      }
      return null;
    }

    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        (uri.host.replaceFirst('www.', '') == 'scan2kare.com' ||
            uri.host.replaceFirst('www.', '') == 'dev.scan2kare.com')) {
      return uriToLocation(uri);
    }

    // Relative app path stored without host
    if ((uri.scheme.isEmpty || uri.scheme == 'file') &&
        uri.path.isNotEmpty &&
        isSupportedPath(uri.path.startsWith('/') ? uri.path : '/${uri.path}')) {
      return uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    }

    return null;
  }

  static bool isDeepLinkPath(String path) {
    final uri = _parseLocation(path);
    final p = uri.path;
    return _protectedPrefixes.any((prefix) => p.startsWith(prefix));
  }

  static bool isSupportedPath(String path) {
    final uri = _parseLocation(path);
    final p = uri.path;
    return isDeepLinkPath(p) || p == '/r';
  }

  static Uri _parseLocation(String path) {
    if (path.startsWith('http')) return Uri.parse(path);
    if (path.contains('?')) return Uri.parse('${ApiConfig.host}$path');
    return Uri.parse('${ApiConfig.host}$path');
  }

  static String? deeplinkToPath(Map<String, dynamic> deeplink) {
    final type = deeplink['type']?.toString() ?? '';
    final code = deeplink['code']?.toString() ?? '';
    if (code.isEmpty) return null;

    switch (type) {
      case 'hospital':
        return '/view-hospital-details/$code';
      case 'doctor_profile':
        return '/view-doctor-profile/$code';
      case 'doctor_details':
        return '/view-doctor-details/$code';
      case 'diagnostic':
        return '/view-diagnostic-center-detail/$code';
      case 'dialysis':
        return '/view-dialysis-center-detail/$code';
      case 'appointment_live':
        return '/appointments/$code/live';
      default:
        final webUrl = deeplink['web_url']?.toString();
        if (webUrl != null) {
          final uri = Uri.tryParse(webUrl);
          if (uri != null) return extractPathFromUri(uri);
        }
        return null;
    }
  }

  static Map<String, dynamic>? deeplinkFromPath(String path) {
    final uri = _parseLocation(path);
    final p = uri.path;
    final code = p.split('/').last;
    if (code.isEmpty) return null;

    if (p.contains('view-hospital-details')) {
      return {'type': 'hospital', 'code': code};
    }
    if (p.contains('view-doctor-profile')) {
      return {'type': 'doctor_profile', 'code': code};
    }
    if (p.contains('view-doctor-details')) {
      return {'type': 'doctor_details', 'code': code};
    }
    if (p.contains('view-diagnostic-center-detail')) {
      return {'type': 'diagnostic', 'code': code};
    }
    if (p.contains('view-dialysis-center-detail')) {
      return {'type': 'dialysis', 'code': code};
    }
    if (p.contains('/appointments/') && p.endsWith('/live')) {
      final parts = p.split('/');
      final id = parts.length >= 3 ? parts[2] : code;
      return {'type': 'appointment_live', 'code': id};
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  static Future<void> savePendingPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = path.startsWith('/') ? path : '/$path';
    await prefs.setString(pendingDeepLinkPathKey, normalized);
  }

  static Future<String?> getPendingPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(pendingDeepLinkPathKey);
    if (path == null || path.isEmpty) return null;
    return path;
  }

  static Future<void> clearPendingPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingDeepLinkPathKey);
  }

  static Future<bool> hasAuthToken() => TokenStorage.hasToken();

  // ---------------------------------------------------------------------------
  // Navigation via go_router
  // ---------------------------------------------------------------------------

  static void handleUri(Uri uri) {
    final location = extractPathFromUri(uri);
    if (location == null || !isSupportedPath(location)) return;
    appRouter.go(location.startsWith('/') ? location : '/$location');
  }

  static Future<void> navigateAfterLogin({
    Map<String, dynamic>? deeplink,
    String? redirectPath,
  }) async {
    String? target;

    if (deeplink != null && deeplink.isNotEmpty) {
      target = deeplinkToPath(deeplink);
    }

    if (target == null && redirectPath != null && redirectPath.isNotEmpty) {
      target = redirectPath.startsWith('/') ? redirectPath : '/$redirectPath';
    }

    if (target == null) {
      target = await getPendingPath();
    }

    final destination = (target != null && isSupportedPath(target))
        ? (target.startsWith('/') ? target : '/$target')
        : '/home';

    // New users: complete name/age/address once before Home / deep link.
    final user = await LocalStorage.getUser();
    if (ProfileCompleteness.isIncomplete(user)) {
      if (destination != '/home' && isSupportedPath(destination)) {
        await savePendingPath(destination);
      } else {
        await clearPendingPath();
      }
      appRouter.go('/edit-profile?setup=1');
      return;
    }

    await clearPendingPath();
    appRouter.go(destination);
  }

  /// After first-time profile save: resume pending deep link or go Home.
  static Future<void> navigateAfterProfileSetup() async {
    final pending = await getPendingPath();
    await clearPendingPath();
    if (pending != null && isSupportedPath(pending)) {
      appRouter.go(pending.startsWith('/') ? pending : '/$pending');
    } else {
      appRouter.go('/home');
    }
  }

  static Future<Map<String, dynamic>?> parsePath(String path) async {
    try {
      final uri = _parseLocation(path);
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.deeplinkParse}?path=${Uri.encodeComponent(uri.path)}',
        ),
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return body['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(body['data'])
            : body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parse install referrer: `deeplink=view-hospital-details%2F{code}`
  static String? pathFromInstallReferrer(String referrer) {
    if (referrer.isEmpty) return null;

    final decoded = Uri.decodeComponent(referrer);
    for (final part in decoded.split('&')) {
      final segments = part.split('=');
      if (segments.length == 2 && segments[0] == 'deeplink') {
        final value = Uri.decodeComponent(segments[1]);
        if (value.startsWith('/')) return value;
        return '/$value';
      }
    }
    return null;
  }
}
