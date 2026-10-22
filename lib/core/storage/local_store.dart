import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` once SharedPreferences has loaded, so every
/// repository can read synchronously at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final localStoreProvider =
    Provider<LocalStore>((ref) => LocalStore(ref.watch(sharedPreferencesProvider)));

/// Thin JSON key-value wrapper. Swap for Hive/Isar/Drift later without
/// touching repositories' public APIs.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  Map<String, dynamic>? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  List<dynamic>? readJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clear() => _prefs.clear();
}

/// Injectable clock so daily/weekly logic is testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
