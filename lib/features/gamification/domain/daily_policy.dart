import '../../../core/config/game_rules.dart';
import '../../../core/utils/day.dart';
import '../../profile/domain/user_profile.dart';

/// Pure day/week rollover rules. Called on launch and on every resume, so the
/// app is always consistent no matter how long it was closed.
abstract final class DailyPolicy {
  static UserProfile rollover(UserProfile p, DateTime now) {
    final today = Day.key(now);
    var next = p;

    // ── Energy & daily counters ─────────────────────────────────────────────
    if (next.energyDay != today) {
      next = next.copyWith(
        energy: GameRules.freeDailyEnergy,
        energyDay: today,
        quizzesToday: 0,
        quizzesTodayDay: today,
        aiMessagesToday: 0,
      );
    }

    // The streak is worked out by the server (see ProfileController.applyServerProgress).

    // Weekly leagues are closed by the server (GET /v1/me/league).
    return next;
  }
}
