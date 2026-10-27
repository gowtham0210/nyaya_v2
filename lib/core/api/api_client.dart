import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_store.dart';

/// An error from the API (its `{ code, message }` body) or from the network.
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);

  /// HTTP status, or 0 when the server could not be reached.
  final int status;
  final String code;
  final String message;

  bool get isNetwork => status == 0;

  @override
  String toString() => 'ApiException($status $code: $message)';
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ApiClient(
    baseUrl: ApiConfig.baseUrl,
    client: client,
    tokens: ref.watch(tokenStoreProvider),
  );
});

/// JSON over HTTP to the Nyaya API. Adds the access token, and when it has
/// expired swaps the refresh token for a new pair once and retries. If that
/// fails the stored session is cleared and [onSessionEnded] fires.
class ApiClient {
  ApiClient({required this.baseUrl, required http.Client client, required this.tokens}) : _http = client;

  final String baseUrl;
  final http.Client _http;
  final TokenStore tokens;
  void Function()? onSessionEnded;

  static const _timeout = Duration(seconds: 15);
  Future<_Refresh>? _refreshing;

  Future<dynamic> get(String path, {Map<String, String>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query, required bool auth}) async {
    var res = await _raw(method, path, body: body, query: query, auth: auth);
    if (res.statusCode == 401 && auth && tokens.current != null) {
      switch (await _refresh()) {
        case _Refresh.ok:
          res = await _raw(method, path, body: body, query: query, auth: auth);
        case _Refresh.rejected:
          await tokens.clear();
          onSessionEnded?.call();
        case _Refresh.offline:
          throw const ApiException(0, 'network', 'Could not reach the server');
      }
    }
    final decoded = res.body.isEmpty ? null : _decode(res.body);
    if (res.statusCode >= 400) {
      final err = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      throw ApiException(
        res.statusCode,
        err['code'] as String? ?? 'error',
        err['message'] as String? ?? 'Request failed (${res.statusCode})',
      );
    }
    return decoded;
  }

  Future<http.Response> _raw(String method, String path, {Object? body, Map<String, String>? query, required bool auth}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final token = auth ? tokens.current?.accessToken : null;
    final request = http.Request(method, uri)
      ..headers['accept'] = 'application/json'
      ..headers.addAll({if (token != null) 'authorization': 'Bearer $token'});
    if (body != null) {
      request
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    try {
      return await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException(0, 'network', 'The server took too long to respond');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(0, 'network', 'Could not reach the server');
    }
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// One refresh at a time; concurrent callers share it (refresh tokens are single-use).
  Future<_Refresh> _refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<_Refresh> _doRefresh() async {
    final session = tokens.current;
    if (session == null) return _Refresh.rejected;
    try {
      final res = await _raw('POST', '/v1/auth/refresh', body: {'refresh_token': session.refreshToken}, auth: false);
      if (res.statusCode >= 500) return _Refresh.offline;
      if (res.statusCode != 200) return _Refresh.rejected;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      await tokens.save(session.withTokens(j['access_token'] as String, j['refresh_token'] as String));
      return _Refresh.ok;
    } on ApiException {
      // Offline: keep the session so it works again once the network is back.
      return _Refresh.offline;
    }
  }
}

enum _Refresh { ok, rejected, offline }
