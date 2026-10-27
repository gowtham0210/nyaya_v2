import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The signed-in session: API tokens plus the user they belong to.
@immutable
class StoredSession {
  const StoredSession({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;

  /// The API's `user` object (id, email, display_name, roles).
  final Map<String, dynamic> user;

  StoredSession withTokens(String access, String refresh) =>
      StoredSession(accessToken: access, refreshToken: refresh, user: user);

  Map<String, dynamic> toJson() => {'access': accessToken, 'refresh': refreshToken, 'user': user};

  static StoredSession? fromJson(Map<String, dynamic> j) {
    final access = j['access'], refresh = j['refresh'], user = j['user'];
    if (access is! String || refresh is! String || user is! Map<String, dynamic>) return null;
    return StoredSession(accessToken: access, refreshToken: refresh, user: user);
  }
}

/// Holds the session in memory, backed by persistent storage. Loaded once in
/// `main()` so the rest of the app can read it synchronously.
abstract class TokenStore {
  StoredSession? get current;
  Future<void> save(StoredSession session);
  Future<void> clear();
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('tokenStoreProvider not overridden'),
);

/// Keychain (iOS) / Keystore-encrypted storage (Android): tokens never go to
/// SharedPreferences or logs.
class SecureTokenStore extends TokenStore {
  SecureTokenStore._(this._storage, this._current);

  static const _key = 'nyaya_session_v1';
  final FlutterSecureStorage _storage;
  StoredSession? _current;

  static Future<SecureTokenStore> load() async {
    const storage = FlutterSecureStorage();
    StoredSession? session;
    try {
      final raw = await storage.read(key: _key);
      if (raw != null) session = StoredSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Unreadable (e.g. restored from another device): start signed out.
      session = null;
    }
    return SecureTokenStore._(storage, session);
  }

  @override
  StoredSession? get current => _current;

  @override
  Future<void> save(StoredSession session) async {
    _current = session;
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    _current = null;
    await _storage.delete(key: _key);
  }
}

/// For tests.
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore([this._current]);

  StoredSession? _current;

  @override
  StoredSession? get current => _current;

  @override
  Future<void> save(StoredSession session) async => _current = session;

  @override
  Future<void> clear() async => _current = null;
}
