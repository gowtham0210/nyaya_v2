import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../journey/application/journey_controller.dart';
import '../../profile/application/profile_controller.dart';
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
  Future<ServerProgress?> refresh() async {
    if (!ref.read(authProvider.notifier).isSignedIn) return null;
    final ServerProgress p;
    try {
      p = await ref.read(progressApiProvider).fetch();
    } on ApiException {
      return null;
    } on TypeError {
      // E.g. the API and this build are deployed out of step.
      return null;
    }
    if (ref.mounted) apply(p);
    return p;
  }

  void apply(ServerProgress p) {
    ref.read(profileProvider.notifier).applyServerProgress(p);
    ref.read(journeyProvider.notifier).applyServer(stars: p.stars, openedChests: p.openedChests);
  }

  void _clear() {
    ref.read(profileProvider.notifier).clearServerProgress();
    ref.read(journeyProvider.notifier).reset();
  }
}
