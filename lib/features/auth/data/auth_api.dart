import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/token_store.dart';

@immutable
class Account {
  const Account({required this.id, required this.email, required this.displayName});

  final String id;
  final String email;
  final String displayName;

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: j['display_name'] as String? ?? '',
      );
}

final authApiProvider = Provider<AuthApi>(
  (ref) => HttpAuthApi(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)),
);

/// Learner accounts on the Nyaya API. Successful calls store the session.
abstract interface class AuthApi {
  Future<Account> signIn({required String email, required String password});
  Future<Account> register({required String name, required String email, required String password});
  Future<void> signOut();

  /// Emails a 6-digit code to choose a new password. Answers the same whether
  /// or not the email has an account.
  Future<void> requestPasswordReset({required String email});

  /// Sets a new password with the emailed code and signs in. Throws an
  /// [ApiException] with code `invalid_reset_code` for a wrong or old code.
  Future<Account> resetPassword({required String email, required String code, required String newPassword});

  /// Deletes the account and everything on it; the session ends with it.
  /// Throws an [ApiException] with code `wrong_password` when the password is wrong.
  Future<void> deleteAccount({required String password});
}

class HttpAuthApi implements AuthApi {
  HttpAuthApi(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  @override
  Future<Account> signIn({required String email, required String password}) =>
      _store(_client.post('/v1/auth/session', body: {'email': email, 'password': password}, auth: false));

  @override
  Future<Account> register({required String name, required String email, required String password}) => _store(
        _client.post(
          '/v1/auth/register',
          body: {'display_name': name, 'email': email, 'password': password},
          auth: false,
        ),
      );

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _client.post('/v1/auth/password-reset', body: {'email': email}, auth: false);
  }

  @override
  Future<Account> resetPassword({required String email, required String code, required String newPassword}) =>
      _store(
        _client.post(
          '/v1/auth/password-reset/confirm',
          body: {'email': email, 'code': code, 'new_password': newPassword},
          auth: false,
        ),
      );

  @override
  Future<void> signOut() async {
    final refresh = _tokens.current?.refreshToken;
    await _tokens.clear();
    if (refresh == null) return;
    try {
      await _client.post('/v1/auth/sign-out', body: {'refresh_token': refresh}, auth: false);
    } on ApiException {
      // Signed out on this device regardless; the token expires on its own.
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    await _client.post('/v1/me/delete-account', body: {'password': password});
    await _tokens.clear();
  }

  Future<Account> _store(Future<dynamic> call) async {
    final j = await call as Map<String, dynamic>;
    final user = j['user'] as Map<String, dynamic>;
    await _tokens.save(
      StoredSession(accessToken: j['access_token'] as String, refreshToken: j['refresh_token'] as String, user: user),
    );
    return Account.fromJson(user);
  }
}
