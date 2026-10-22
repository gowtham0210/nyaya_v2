/// Central, tweakable game-economy rules.
///
/// Keeping every number here means product can tune the economy without
/// touching feature code (and later move these values to Remote Config).
/// Rationale for each value lives in docs/DESIGN.md.
abstract final class GameRules {
  // ── Energy (resets at local midnight) ─────────────────────────────────────
  static const int freeDailyEnergy = 5;
  static const int casePathEnergyCost = 1;
  static const int duelEnergyCost = 1;
  static const int examEnergyCost = 2;

  /// Daily Docket is always free so the streak can never be blocked by energy.
  static const int dailyDocketEnergyCost = 0;

  /// A 3-star Case Path clear refunds energy — makes the cost feel earnable.
  static const int threeStarEnergyBonus = 1;
  static const int energyRefillCoinCost = 30;

  // ── Coins ─────────────────────────────────────────────────────────────────
  static const int startingCoins = 60;
  static const int coinsPerNewStar = 5;
  static const int coinsPerChest = 30;
  static const int coinsForDailyDocket = 10;
  static const int coinsForDailyGoal = 15;
  static const int coinsForDuelWin = 10;
  static const int streakFreezeCoinCost = 100;
  static const int maxStreakFreezes = 2;

  // ── XP (per question) ─────────────────────────────────────────────────────
  // qXP = (10 + speedBonus + comboBonus) × difficulty
  static const int xpPerCorrect = 10;
  static const int maxSpeedBonus = 5;
  static const int comboStart = 3;
  static const int comboBonusStep = 2;
  static const int maxComboBonus = 6;
  static const Map<int, double> difficultyMultiplier = {
    1: 1.0,
    2: 1.25,
    3: 1.5,
    4: 2.0,
  };

  // ── XP (per session) ──────────────────────────────────────────────────────
  static const int xpCompletionBonus = 10;
  static const int xpPerfectBonus = 10;
  static const double dailyDocketMultiplier = 1.25;
  static const double replayMultiplier = 0.5;
  static const int duelWinXp = 15;

  /// Streak multiplier: 0–2 days ×1.0, 3–6 ×1.1, 7–29 ×1.2, 30+ ×1.3.
  static double streakMultiplier(int streak) {
    if (streak >= 30) return 1.3;
    if (streak >= 7) return 1.2;
    if (streak >= 3) return 1.1;
    return 1.0;
  }

  // ── Stars / unlocking ─────────────────────────────────────────────────────
  static const double oneStarAccuracy = 0.5;
  static const double twoStarAccuracy = 0.8;

  // ── Modes ─────────────────────────────────────────────────────────────────
  static const int casePathSoftSeconds = 60;
  static const int dailyDocketQuestions = 5;
  static const int dailyDocketSeconds = 30;
  static const int duelQuestions = 7;
  static const int duelSeconds = 15;
  static const int examQuestions = 20;
  static const int examSeconds = 20 * 60;
  static const double examCorrectMarks = 1.0;
  static const double examNegativeMarks = 0.25;

  // ── Duel rating (hidden Elo, separate from XP) ────────────────────────────
  static const int startingDuelRating = 1000;
  static const int eloKProvisional = 32;
  static const int eloKSettled = 16;
  static const int provisionalDuels = 20;

  // ── AI assistant ──────────────────────────────────────────────────────────
  static const int freeDailyAiMessages = 5;

  // ── Streak milestones (days) → bonus coins ────────────────────────────────
  static const Map<int, int> streakMilestones = {
    3: 15,
    7: 30,
    14: 50,
    30: 100,
    50: 150,
    100: 300,
    365: 1000,
  };

  /// A free streak freeze is granted at these milestones.
  static const Set<int> freezeMilestones = {7, 30, 100};
}
