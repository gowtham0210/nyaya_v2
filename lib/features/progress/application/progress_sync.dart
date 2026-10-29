import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../journey/application/journey_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/user_profile.dart';
import '../data/progress_api.dart';
import '../domain/server_progress.dart';

/// Keeps the phone's copy of the learner's progress in step with the server:
/// loads it when someone signs in (and on start and resume), clears it on
/// sign-out. Watch it once near the root so it stays alive.
final progressSyncProvider = NotifierProvider<ProgressSync, void>(ProgressSync.new);

class ProgressSync extends Notifier<void> {
  @override
  void build() {
    ref.listen(authProvider, (before, after) {
      if (after == null) {
        _clear();
      } else if (before?.id != after.id) {
        refresh();
      }
    });
  }

  /// Loads progress from the server. Offline, signed out, or given a response
  /// this build can't read, the last copy stays and null comes back.
  ///
  /// The first time an account is used, it takes the phone's settings (and
  /// demo premium), since onboarding happens before sign-in. After that the
  /// account's settings win.
  Future<ServerProgress?> refresh() async {
    if (!ref.read(authProvider.notifier).isSignedIn) return null;
    final api = ref.read(progressApiProvider);
    ServerProgress? p = await _guard(api.fetch);
    if (p == null || !ref.mounted) return p;
    final local = ref.read(profileProvider);
    if (p.settings == null && local.onboarded) {
      final uploaded = await _guard(() async {
        await api.saveSettings(_settingsOf(local));
        return local.isPremium && !p!.premium ? api.setPremium(true) : api.fetch();
      });
      if (uploaded != null) p = uploaded;
    }
    if (ref.mounted) apply(p);
    return p;
  }

  /// Spends coins on energy or a freeze, or switches demo premium, on the
  /// server. Returns the error code when the server says no (e.g.
  /// `not_enough_coins`), or null when it worked.
  Future<String?> refillEnergy() => _act((api) => api.refillEnergy());
  Future<String?> buyStreakFreeze() => _act((api) => api.buyStreakFreeze());
  Future<String?> setPremium(bool on) => _act((api) => api.setPremium(on));

  /// Saves the learning settings to the account (no-op when signed out).
  Future<void> pushSettings() async {
    if (!ref.read(authProvider.notifier).isSignedIn) return;
    await _guard(() async {
      await ref.read(progressApiProvider).saveSettings(_settingsOf(ref.read(profileProvider)));
      return null;
    });
  }

  void apply(ServerProgress p) {
    ref.read(profileProvider.notifier).applyServerProgress(p);
    ref.read(journeyProvider.notifier).applyServer(stars: p.stars, openedChests: p.openedChests);
  }

  Future<String?> _act(Future<ServerProgress> Function(ProgressApi api) call) async {
    if (!ref.read(authProvider.notifier).isSignedIn) return 'signed_out';
    try {
      final p = await call(ref.read(progressApiProvider));
      if (ref.mounted) apply(p);
      return null;
    } on ApiException catch (e) {
      return e.code;
    } on TypeError {
      return 'error';
    }
  }

  /// Network trouble or a response this build can't read count as offline.
  Future<T?> _guard<T>(Future<T?> Function() call) async {
    try {
      return await call();
    } on ApiException {
      return null;
    } on TypeError {
      // E.g. the API and this build are deployed out of step.
      return null;
    }
  }

  static ServerSettings _settingsOf(UserProfile p) => ServerSettings(
        name: p.name.trim().isEmpty ? 'Learner' : p.name.trim(),
        persona: p.persona.name,
        language: p.language.code,
        dailyGoal: p.dailyGoal,
        onboarded: p.onboarded,
      );

  void _clear() {
    ref.read(profileProvider.notifier).clearServerProgress();
    ref.read(journeyProvider.notifier).reset();
  }
}
