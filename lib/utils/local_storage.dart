import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/favorites_service.dart';
import 'token_storage.dart';

class LocalStorage {
  static const String _userKey = "user_data";

  /// Notifies Home / listeners when the visible patient name changes.
  static final ValueNotifier<String> displayNameNotifier =
      ValueNotifier<String>('Guest');

  static Future<void> saveToken(String token) async {
    await TokenStorage.saveToken(token);
  }

  static Future<String?> getToken() async {
    return TokenStorage.getToken();
  }

  /// Restore display name from prefs (call once at app start).
  static Future<void> hydrateDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    displayNameNotifier.value = prefs.getString('user_name') ?? 'Guest';
  }

  /// Save user JSON and keep Home / Drawer display keys in sync.
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
    await syncDisplayPrefs(user);
  }

  /// Keys used by Home, Drawer, Hospital screens for the visible name.
  static Future<void> syncDisplayPrefs(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final name = (user['name'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString().trim();
    final address = (user['address'] ?? '').toString().trim();
    final phone = (user['phone'] ?? '').toString().trim();

    if (name.isNotEmpty) {
      await prefs.setString('user_name', name);
      displayNameNotifier.value = name;
    }
    if (email.isNotEmpty) {
      await prefs.setString('user_email', email);
    }
    if (address.isNotEmpty) {
      await prefs.setString('address', address);
    }
    if (phone.isNotEmpty) {
      await prefs.setString('user_phone', phone);
    }
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);
    if (userString == null) return null;
    return jsonDecode(userString);
  }

  static Future<void> clear() async {
    await TokenStorage.clearSession();
    displayNameNotifier.value = 'Guest';
    FavoritesService.clear();
  }
}
