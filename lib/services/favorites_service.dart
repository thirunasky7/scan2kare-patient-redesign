import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../network/api_client.dart';

/// Favourited doctors and hospitals.
///
/// Tries the patient favourites API when it exists, and always mirrors state
/// in SharedPreferences so hearts work on this app even if those endpoints
/// are not deployed yet.
class FavoritesService {
  FavoritesService._();

  static const String doctor = 'doctor';
  static const String hospital = 'hospital';

  static const String _idsPref = 'favorites_ids_v1';
  static const String _snapPref = 'favorites_snapshots_v1';

  static final Map<String, ValueNotifier<Set<int>>> _byType = {
    doctor: ValueNotifier<Set<int>>(<int>{}),
    hospital: ValueNotifier<Set<int>>(<int>{}),
  };

  static final Map<String, Map<String, dynamic>> _snapshots = {};

  static bool seeded = false;

  static ValueNotifier<Set<int>> notifierFor(String type) =>
      _byType[type] ?? (throw ArgumentError('Unknown favourite type: $type'));

  static bool isFavorite(String type, int id) =>
      notifierFor(type).value.contains(id);

  static Future<void> seed() async {
    await _loadLocal();
    seeded = true;

    try {
      final res = await ApiClient.get(ApiConfig.favoriteIds);
      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      final data = decoded['data'];
      if (data is! Map) return;

      for (final type in _byType.keys) {
        final ids = data[type];
        if (ids is List) {
          _byType[type]!.value = ids
              .map((e) => int.tryParse('$e') ?? -1)
              .where((e) => e > 0)
              .toSet();
        }
      }
      await _saveLocal();
    } catch (_) {
      // Offline or API not present: local cache is enough.
    }
  }

  static Future<bool> toggle({
    required String type,
    required int id,
    Map<String, dynamic>? snapshot,
  }) async {
    final notifier = notifierFor(type);
    final previous = Set<int>.from(notifier.value);
    final wasFavorite = previous.contains(id);

    _setMembership(type, id, !wasFavorite);
    if (!wasFavorite) {
      final data = Map<String, dynamic>.from(snapshot ?? {'id': id, 'name': ''});
      data['id'] = id;
      _snapshots[_snapKey(type, id)] = data;
    } else {
      _snapshots.remove(_snapKey(type, id));
    }
    await _saveLocal();

    try {
      final res = await ApiClient.post(
        ApiConfig.favoritesToggle,
        body: {'type': type, 'id': id},
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final favorited = decoded['favorited'] == true;
        _setMembership(type, id, favorited);
        if (!favorited) {
          _snapshots.remove(_snapKey(type, id));
        }
        await _saveLocal();
        return favorited;
      }

      // 404/405: Laravel does not have these routes yet — keep local state.
      if (res.statusCode == 404 ||
          res.statusCode == 405 ||
          res.statusCode == 501) {
        return !wasFavorite;
      }

      throw Exception('Toggle failed (${res.statusCode})');
    } catch (e) {
      if (e is Exception && e.toString().contains('Toggle failed')) {
        notifier.value = previous;
        if (wasFavorite) {
          if (snapshot != null) {
            _snapshots[_snapKey(type, id)] = Map<String, dynamic>.from(snapshot)
              ..['id'] = id;
          }
        } else {
          _snapshots.remove(_snapKey(type, id));
        }
        await _saveLocal();
        rethrow;
      }
      // Network / missing API: keep the optimistic local flip.
      return !wasFavorite;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchFavorites({
    required String type,
  }) async {
    try {
      final res = await ApiClient.get('${ApiConfig.favorites}?type=$type');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['data'];
        if (list is! List) return _localList(type);

        final mapped = list.cast<Map<String, dynamic>>().map((e) {
          final id = int.tryParse('${e['id']}') ?? 0;
          final copy = Map<String, dynamic>.from(e);
          copy['id'] = id;
          if (id > 0) {
            _snapshots[_snapKey(type, id)] = copy;
          }
          return copy;
        }).toList();

        _byType[type]?.value = mapped
            .map((e) => e['id'] as int)
            .where((e) => e > 0)
            .toSet();
        seeded = true;
        await _saveLocal();
        return mapped.where((e) => (e['id'] as int) > 0).toList();
      }
    } catch (_) {}

    return _localList(type);
  }

  static void clear() {
    for (final notifier in _byType.values) {
      notifier.value = <int>{};
    }
    _snapshots.clear();
    seeded = false;
    unawaited(_wipeLocal());
  }

  static void _setMembership(String type, int id, bool member) {
    final notifier = notifierFor(type);
    final next = Set<int>.from(notifier.value);
    member ? next.add(id) : next.remove(id);
    notifier.value = next;
  }

  static String _snapKey(String type, int id) => '$type:$id';

  static List<Map<String, dynamic>> _localList(String type) {
    final ids = notifierFor(type).value;
    return ids.map((id) {
      final snap = _snapshots[_snapKey(type, id)];
      if (snap != null) {
        final copy = Map<String, dynamic>.from(snap);
        copy['id'] = id;
        return copy;
      }
      return <String, dynamic>{'id': id, 'name': ''};
    }).toList();
  }

  static Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsRaw = prefs.getString(_idsPref);
      if (idsRaw != null) {
        final decoded = jsonDecode(idsRaw);
        if (decoded is Map) {
          for (final type in _byType.keys) {
            final ids = decoded[type];
            if (ids is List) {
              _byType[type]!.value = ids
                  .map((e) => int.tryParse('$e') ?? -1)
                  .where((e) => e > 0)
                  .toSet();
            }
          }
        }
      }
      final snapRaw = prefs.getString(_snapPref);
      if (snapRaw != null) {
        final decoded = jsonDecode(snapRaw);
        if (decoded is Map) {
          _snapshots
            ..clear()
            ..addAll(
              decoded.map(
                (key, value) => MapEntry(
                  key.toString(),
                  Map<String, dynamic>.from(value as Map),
                ),
              ),
            );
        }
      }
    } catch (_) {}
  }

  static Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _idsPref,
        jsonEncode({
          for (final e in _byType.entries) e.key: e.value.value.toList(),
        }),
      );
      await prefs.setString(_snapPref, jsonEncode(_snapshots));
    } catch (_) {}
  }

  static Future<void> _wipeLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_idsPref);
      await prefs.remove(_snapPref);
    } catch (_) {}
  }
}
