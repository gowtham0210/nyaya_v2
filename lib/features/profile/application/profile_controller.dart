import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/game_rules.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/day.dart';
import '../../gamification/domain/daily_policy.dart';
import '../../progress/domain/server_progress.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

final profileProvider = NotifierProvider<ProfileController, UserProfile>(ProfileController.new);

/// Convenience selectors so widgets rebuild only on what they show.
final localeProvider = Provider<Locale>((ref) => Locale(ref.watch(profileProvider.select((p) => p.language.code))));
final themeModeProvider = Provider<ThemeMode>((ref) => ref.watch(profileProvider.select((p) => p.themeMode)));

/// Single owner of the learner's persistent state. All economy mutations go
/// through here so rules stay in one place.
class ProfileController extends Notifier<UserProfile> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  UserProfile build() {
    final loaded = ref.watch(profileRepositoryProvider).load();
    final rolled = DailyPolicy.rollover(loaded, ref.read(clockProvider)());
    if (!identical(rolled, loaded)) ref.read(profileRepositoryProvider).save(rolled);
    return rolled;
  }

  void _set(UserProfile p) {
    state = p;
    _repo.save(p);
  }

  /// Call on app resume — handles midnight energy reset, streak checks and
  /// weekly league close.
  void refreshDay() {
    final rolled = DailyPolicy.rollover(state, _now());
    if (!identical(rolled, state)) _set(rolled);
  }

  // ── Onboarding & settings ─────────────────────────────────────────────────

  void completeOnboarding({
    required String name,
    required Persona persona,
    required AppLanguage language,
    required int dailyGoal,
  }) {
    _set(state.copyWith(
      onboarded: true,
      name: name.trim(),
      persona: persona,
      language: language,
      dailyGoal: dailyGoal,
      coins: state.coins == 0 ? GameRules.startingCoins : state.coins,
    ));
  }

  void setLanguage(AppLanguage l) => _set(state.copyWith(language: l));
  void setThemeMode(ThemeMode m) => _set(state.copyWith(themeMode: m));
  void setDailyGoal(int g) => _set(state.copyWith(dailyGoal: g));
  void setPersona(Persona p) => _set(state.copyWith(persona: p));
  void setName(String n) => _set(state.copyWith(name: n.trim()));
  void setSound(bool v) => _set(state.copyWith(soundOn: v));
  void setHaptics(bool v) => _set(state.copyWith(hapticsOn: v));
  void setReminders(bool v) => _set(state.copyWith(remindersOn: v));

  // ── Energy ────────────────────────────────────────────────────────────────

  bool canAfford(int cost) => state.isPremium || state.energy >= cost;

  /// Charges energy at quiz start (never mid-quiz). Returns false if short.
  bool spendEnergy(int cost) {
    if (state.isPremium || cost == 0) return true;
    if (state.energy < cost) return false;
    _set(state.copyWith(energy: state.energy - cost));
    return true;
  }

  /// Refund when a quiz is abandoned before the first answer.
  void refundEnergy(int cost) {
    if (state.isPremium || cost == 0) return;
    _set(state.copyWith(energy: state.energy + cost));
  }

  void addEnergy(int amount) => _set(state.copyWith(energy: state.energy + amount));

  bool refillEnergyWithCoins() {
    if (state.coins < GameRules.energyRefillCoinCost) return false;
    _set(state.copyWith(
      coins: state.coins - GameRules.energyRefillCoinCost,
      energy: state.energy + 1,
    ));
    return true;
  }

  // ── Coins & store ─────────────────────────────────────────────────────────

  void addCoins(int n) => _set(state.copyWith(coins: state.coins + n));

  void activatePremium() => _set(state.copyWith(isPremium: true));

  void cancelPremium() => _set(state.copyWith(isPremium: false));

  // ── AI assistant quota ────────────────────────────────────────────────────

  int get aiMessagesLeft => state.isPremium
      ? 1 << 30
      : (GameRules.freeDailyAiMessages - state.aiMessagesToday).clamp(0, GameRules.freeDailyAiMessages);

  bool consumeAiMessage() {
    if (state.isPremium) return true;
    if (aiMessagesLeft <= 0) return false;
    _set(state.copyWith(aiMessagesToday: state.aiMessagesToday + 1));
    return true;
  }

  // ── Server progress (XP, streak, totals) ──────────────────────────────────

  /// Copies the server's learning progress into the profile. The server works
  /// it out from submitted quizzes; the phone never changes these itself.
  void applyServerProgress(ServerProgress p) {
    final today = Day.key(_now());
    var next = state;
    // A new week: close last week's league with the server's figure first.
    if (next.weekId != p.weekId) {
      final closing = next.weekId == p.lastWeekId ? p.lastWeekXp : 0;
      next = DailyPolicy.rollover(next.copyWith(weeklyXp: closing), _now());
    }
    _set(next.copyWith(
      totalXp: p.totalXp,
      weekId: p.weekId,
      weeklyXp: p.weeklyXp,
      streak: p.streak,
      longestStreak: p.longestStreak,
      streakFreezes: p.streakFreezes,
      lastActiveDay: p.lastActiveDay,
      clearLastActiveDay: p.lastActiveDay == null,
      activeDays: p.activeDays,
      frozenDays: p.frozenDays,
      totalAnswered: p.questionsAnswered,
      totalCorrect: p.correct,
      quizzesCompleted: p.quizzesCompleted,
      quizzesToday: p.quizzesToday,
      quizzesTodayDay: today,
      lastDocketDay: p.docketDoneToday ? today : null,
      clearLastDocketDay: !p.docketDoneToday && state.lastDocketDay == today,
    ));
  }

  /// Signed out: show no learning progress (it belongs to the account).
  void clearServerProgress() => _set(state.copyWith(
        totalXp: 0,
        weeklyXp: 0,
        streak: 0,
        longestStreak: 0,
        streakFreezes: 0,
        clearLastActiveDay: true,
        activeDays: const [],
        frozenDays: const [],
        totalAnswered: 0,
        totalCorrect: 0,
        quizzesCompleted: 0,
        quizzesToday: 0,
        clearLastDocketDay: true,
      ));

  /// Coins and energy earned by a quiz. They stay on the phone for now.
  void applyQuizEconomy({required int coins, required int energyBonus}) => _set(state.copyWith(
        coins: state.coins + coins,
        energy: state.isPremium ? state.energy : state.energy + energyBonus,
      ));

  void applyDuel({required int newRating, required bool won}) => _set(state.copyWith(
        duelRating: newRating,
        duelsPlayed: state.duelsPlayed + 1,
        duelsWon: state.duelsWon + (won ? 1 : 0),
      ));

  void acknowledgeLeagueOutcome() => _set(state.copyWith(clearLeagueOutcome: true));

  bool get docketDoneToday => state.lastDocketDay == Day.key(_now());

  int get quizzesTodayCount => state.quizzesTodayDay == Day.key(_now()) ? state.quizzesToday : 0;

  /// Wipes progress but keeps language/theme so the restart feels familiar.
  Future<void> resetAll() async {
    final keep = state;
    await ref.read(localStoreProvider).clear();
    _set(DailyPolicy.rollover(
      UserProfile(language: keep.language, themeMode: keep.themeMode),
      _now(),
    ));
  }
}
