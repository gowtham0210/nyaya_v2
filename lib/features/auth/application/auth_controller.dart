import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/token_store.dart';
import '../data/auth_api.dart';

final authProvider = NotifierProvider<AuthController, Account?>(AuthController.new);

/// The signed-in learner, or null. Starts from the stored session and drops
/// to null if the API ends the session (e.g. the refresh token was revoked).
class AuthController extends Notifier<Account?> {
  @override
  Account? build() {
    ref.read(apiClientProvider).onSessionEnded = () => state = null;
    final user = ref.read(tokenStoreProvider).current?.user;
    return user == null ? null : Account.fromJson(user);
  }

  bool get isSignedIn => state != null;

  Future<void> signIn({required String email, required String password}) async {
    state = await ref.read(authApiProvider).signIn(email: email.trim(), password: password);
  }

  Future<void> register({required String name, required String email, required String password}) async {
    state = await ref.read(authApiProvider).register(name: name.trim(), email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    await ref.read(authApiProvider).signOut();
    state = null;
  }

  Future<void> deleteAccount({required String password}) async {
    await ref.read(authApiProvider).deleteAccount(password: password);
    state = null;
  }
}
