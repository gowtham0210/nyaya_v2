import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/game_rules.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/day.dart';
import '../../gamification/domain/daily_policy.dart';
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

  bool buyStreakFreeze() {
    if (state.coins < GameRules.streakFreezeCoinCost ||
        state.streakFreezes >= GameRules.maxStreakFreezes) {
      return false;
    }
    _set(state.copyWith(
      coins: state.coins - GameRules.streakFreezeCoinCost,
      streakFreezes: state.streakFreezes + 1,
    ));
    return true;
  }

  void activatePremium() => _set(state.copyWith(
        isPremium: true,
        streakFreezes: GameRules.maxStreakFreezes,
      ));

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

  // ── Quiz results (called by QuizCompletionService) ───────────────────────

  /// Applies XP/coins/stats and the streak tick. Returns
  /// `(milestone, streakExtended, dailyGoalJustReached)`.
  (int?, bool, bool) applyQuizOutcome({
    required int xp,
    required int coins,
    required int answered,
    required int correct,
    required int energyBonus,
    bool isDocket = false,
  }) {
    final now = _now();
    final today = Day.key(now);
    final quizzesToday = (state.quizzesTodayDay == today ? state.quizzesToday : 0) + 1;
    final goalJustReached = quizzesToday == state.dailyGoal;

    var p = state.copyWith(
      totalXp: state.totalXp + xp,
      weeklyXp: state.weeklyXp + xp,
      coins: state.coins + coins + (goalJustReached ? GameRules.coinsForDailyGoal : 0),
      totalAnswered: state.totalAnswered + answered,
      totalCorrect: state.totalCorrect + correct,
      quizzesCompleted: state.quizzesCompleted + 1,
      quizzesToday: quizzesToday,
      quizzesTodayDay: today,
      energy: state.isPremium ? state.energy : state.energy + energyBonus,
      lastDocketDay: isDocket ? today : state.lastDocketDay,
    );
    final (streaked, milestone, extended) = DailyPolicy.onQuizCompleted(p, now);
    p = streaked;
    _set(p);
    return (milestone, extended, goalJustReached);
  }

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
