import 'package:shared_preferences/shared_preferences.dart';

/// Centralized session token storage.
/// Reads/writes both legacy keys so deep links and API calls stay in sync.
/// Also keeps an in-memory logged-in flag so go_router redirects after OTP
/// do not race with SharedPreferences.
class TokenStorage {
  static const String tokenKey = 'token';
  static const String legacyTokenKey = 'auth_token';

  static bool _loggedIn = false;

  /// Sync flag for go_router redirects (set before prefs write completes).
  static bool get isLoggedIn => _loggedIn;

  static Future<void> saveToken(String token) async {
    _loggedIn = token.isNotEmpty;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setString(legacyTokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey) ?? prefs.getString(legacyTokenKey);
  }

  static Future<bool> hasToken() async {
    if (_loggedIn) return true;
    final token = await getToken();
    final ok = token != null && token.isNotEmpty;
    _loggedIn = ok;
    return ok;
  }

  /// Restore in-memory flag from disk (call once at app start).
  static Future<void> hydrate() async {
    final token = await getToken();
    _loggedIn = token != null && token.isNotEmpty;
  }

  /// Remove both token keys only (keeps other prefs like is_first_time).
  static Future<void> clearTokens() async {
    _loggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(legacyTokenKey);
  }

  /// Full local session clear (logout / delete account).
  static Future<void> clearSession() async {
    _loggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
