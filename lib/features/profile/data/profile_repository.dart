import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(localStoreProvider)));

/// Local persistence for [UserProfile]. A remote implementation (Firestore,
/// Supabase…) can implement the same two methods for cloud sync.
class ProfileRepository {
  ProfileRepository(this._store);

  static const _key = 'profile_v1';
  final LocalStore _store;

  UserProfile load() {
    final json = _store.readJson(_key);
    return json == null ? const UserProfile() : UserProfile.fromJson(json);
  }

  Future<void> save(UserProfile p) => _store.writeJson(_key, p.toJson());
}
