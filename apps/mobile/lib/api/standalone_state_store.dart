import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class StandaloneStateStore {
  Future<Map<String, Object?>?> load();
  Future<void> save(Map<String, Object?> state);
  Future<void> clear();
}

class SharedPreferencesStandaloneStateStore implements StandaloneStateStore {
  SharedPreferencesStandaloneStateStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'caiyou.standalone.state.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<Map<String, Object?>?> load() async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, Object?>.from(decoded);
  }

  @override
  Future<void> save(Map<String, Object?> state) async {
    await _preferences.setString(_key, jsonEncode(state));
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_key);
  }
}
