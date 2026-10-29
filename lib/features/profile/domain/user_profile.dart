import 'package:material_ui/material_ui.dart';

enum Persona { advocate, aspirant, citizen }

/// Supported content + UI languages. English is the authoring language; the
/// rest are the five launch Indian languages.
enum AppLanguage {
  en('en', 'English', 'English'),
  hi('hi', 'हिन्दी', 'Hindi'),
  ta('ta', 'தமிழ்', 'Tamil'),
  te('te', 'తెలుగు', 'Telugu'),
  kn('kn', 'ಕನ್ನಡ', 'Kannada'),
  ml('ml', 'മലയാളം', 'Malayalam');

  const AppLanguage(this.code, this.nativeName, this.englishName);

  final String code;
  final String nativeName;
  final String englishName;

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.en);
}

/// Outcome of last week's league, shown once on next open.
class LeagueOutcome {
  const LeagueOutcome({required this.rank, required this.fromTier, required this.toTier});

  final int rank;
  final int fromTier;
  final int toTier;

  bool get promoted => toTier > fromTier;
  bool get demoted => toTier < fromTier;

  Map<String, dynamic> toJson() => {'rank': rank, 'from': fromTier, 'to': toTier};

  factory LeagueOutcome.fromJson(Map<String, dynamic> j) => LeagueOutcome(
        rank: j['rank'] as int,
        fromTier: j['from'] as int,
        toTier: j['to'] as int,
      );
}

/// Everything about the learner that persists across sessions. Immutable;
/// mutations go through `ProfileController`.
@immutable
class UserProfile {
  const UserProfile({
    this.onboarded = false,
    this.name = '',
    this.persona = Persona.citizen,
    this.language = AppLanguage.en,
    this.dailyGoal = 3,
    this.themeMode = ThemeMode.system,
    this.soundOn = true,
    this.hapticsOn = true,
    this.remindersOn = true,
    this.isPremium = false,
    this.totalXp = 0,
    this.coins = 0,
    this.energy = 0,
    this.energyDay = '',
    this.streak = 0,
    this.longestStreak = 0,
    this.lastActiveDay,
    this.streakFreezes = 0,
    this.frozenDays = const [],
    this.activeDays = const [],
    this.quizzesToday = 0,
    this.quizzesTodayDay = '',
    this.aiMessagesToday = 0,
    this.lastDocketDay,
    this.weekId = '',
    this.weeklyXp = 0,
    this.leagueTier = 1,
    this.pendingLeagueOutcome,
    this.leagueResultSeen = '',
    this.duelRating = 1000,
    this.duelsPlayed = 0,
    this.duelsWon = 0,
    this.totalAnswered = 0,
    this.totalCorrect = 0,
    this.quizzesCompleted = 0,
  });

  final bool onboarded;
  final String name;
  final Persona persona;
  final AppLanguage language;
  final int dailyGoal;
  final ThemeMode themeMode;
  final bool soundOn;
  final bool hapticsOn;
  final bool remindersOn;
  final bool isPremium;

  final int totalXp;
  final int coins;

  final int energy;
  /// Day key the energy was last reset on.
  final String energyDay;

  final int streak;
  final int longestStreak;
  /// Last day a quiz was completed (day key).
  final String? lastActiveDay;
  final int streakFreezes;
  /// Days protected by a freeze — rendered on the week strip.
  final List<String> frozenDays;
  /// Recent active days (last ~14) for the week strip.
  final List<String> activeDays;

  final int quizzesToday;
  final String quizzesTodayDay;
  final int aiMessagesToday;
  final String? lastDocketDay;

  final String weekId;
  final int weeklyXp;
  final int leagueTier;
  final LeagueOutcome? pendingLeagueOutcome;

  /// Week id of the last league result shown, so each is shown once.
  final String leagueResultSeen;

  final int duelRating;
  final int duelsPlayed;
  final int duelsWon;

  final int totalAnswered;
  final int totalCorrect;
  final int quizzesCompleted;

  double get accuracy => totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  UserProfile copyWith({
    bool? onboarded,
    String? name,
    Persona? persona,
    AppLanguage? language,
    int? dailyGoal,
    ThemeMode? themeMode,
    bool? soundOn,
    bool? hapticsOn,
    bool? remindersOn,
    bool? isPremium,
    int? totalXp,
    int? coins,
    int? energy,
    String? energyDay,
    int? streak,
    int? longestStreak,
    String? lastActiveDay,
    int? streakFreezes,
    List<String>? frozenDays,
    List<String>? activeDays,
    int? quizzesToday,
    String? quizzesTodayDay,
    int? aiMessagesToday,
    String? lastDocketDay,
    String? weekId,
    int? weeklyXp,
    int? leagueTier,
    LeagueOutcome? pendingLeagueOutcome,
    String? leagueResultSeen,
    bool clearLeagueOutcome = false,
    bool clearLastActiveDay = false,
    bool clearLastDocketDay = false,
    int? duelRating,
    int? duelsPlayed,
    int? duelsWon,
    int? totalAnswered,
    int? totalCorrect,
    int? quizzesCompleted,
  }) {
    return UserProfile(
      onboarded: onboarded ?? this.onboarded,
      name: name ?? this.name,
      persona: persona ?? this.persona,
      language: language ?? this.language,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      themeMode: themeMode ?? this.themeMode,
      soundOn: soundOn ?? this.soundOn,
      hapticsOn: hapticsOn ?? this.hapticsOn,
      remindersOn: remindersOn ?? this.remindersOn,
      isPremium: isPremium ?? this.isPremium,
      totalXp: totalXp ?? this.totalXp,
      coins: coins ?? this.coins,
      energy: energy ?? this.energy,
      energyDay: energyDay ?? this.energyDay,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDay: clearLastActiveDay ? null : (lastActiveDay ?? this.lastActiveDay),
      streakFreezes: streakFreezes ?? this.streakFreezes,
      frozenDays: frozenDays ?? this.frozenDays,
      activeDays: activeDays ?? this.activeDays,
      quizzesToday: quizzesToday ?? this.quizzesToday,
      quizzesTodayDay: quizzesTodayDay ?? this.quizzesTodayDay,
      aiMessagesToday: aiMessagesToday ?? this.aiMessagesToday,
      lastDocketDay: clearLastDocketDay ? null : (lastDocketDay ?? this.lastDocketDay),
      weekId: weekId ?? this.weekId,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      leagueTier: leagueTier ?? this.leagueTier,
      leagueResultSeen: leagueResultSeen ?? this.leagueResultSeen,
      pendingLeagueOutcome:
          clearLeagueOutcome ? null : (pendingLeagueOutcome ?? this.pendingLeagueOutcome),
      duelRating: duelRating ?? this.duelRating,
      duelsPlayed: duelsPlayed ?? this.duelsPlayed,
      duelsWon: duelsWon ?? this.duelsWon,
      totalAnswered: totalAnswered ?? this.totalAnswered,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      quizzesCompleted: quizzesCompleted ?? this.quizzesCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'name': name,
        'persona': persona.name,
        'language': language.code,
        'dailyGoal': dailyGoal,
        'themeMode': themeMode.name,
        'soundOn': soundOn,
        'hapticsOn': hapticsOn,
        'remindersOn': remindersOn,
        'isPremium': isPremium,
        'totalXp': totalXp,
        'coins': coins,
        'energy': energy,
        'energyDay': energyDay,
        'streak': streak,
        'longestStreak': longestStreak,
        'lastActiveDay': lastActiveDay,
        'streakFreezes': streakFreezes,
        'frozenDays': frozenDays,
        'activeDays': activeDays,
        'quizzesToday': quizzesToday,
        'quizzesTodayDay': quizzesTodayDay,
        'aiMessagesToday': aiMessagesToday,
        'lastDocketDay': lastDocketDay,
        'weekId': weekId,
        'weeklyXp': weeklyXp,
        'leagueTier': leagueTier,
        'pendingLeagueOutcome': pendingLeagueOutcome?.toJson(),
        'leagueResultSeen': leagueResultSeen,
        'duelRating': duelRating,
        'duelsPlayed': duelsPlayed,
        'duelsWon': duelsWon,
        'totalAnswered': totalAnswered,
        'totalCorrect': totalCorrect,
        'quizzesCompleted': quizzesCompleted,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    T v<T>(String k, T fallback) => j[k] is T ? j[k] as T : fallback;
    List<String> strings(String k) =>
        (j[k] as List<dynamic>? ?? const []).whereType<String>().toList();
    return UserProfile(
      onboarded: v('onboarded', false),
      name: v('name', ''),
      persona: Persona.values.asNameMap()[j['persona']] ?? Persona.citizen,
      language: AppLanguage.fromCode(j['language'] as String?),
      dailyGoal: v('dailyGoal', 3),
      themeMode: ThemeMode.values.asNameMap()[j['themeMode']] ?? ThemeMode.system,
      soundOn: v('soundOn', true),
      hapticsOn: v('hapticsOn', true),
      remindersOn: v('remindersOn', true),
      isPremium: v('isPremium', false),
      totalXp: v('totalXp', 0),
      coins: v('coins', 0),
      energy: v('energy', 0),
      energyDay: v('energyDay', ''),
      streak: v('streak', 0),
      longestStreak: v('longestStreak', 0),
      lastActiveDay: j['lastActiveDay'] as String?,
      streakFreezes: v('streakFreezes', 0),
      frozenDays: strings('frozenDays'),
      activeDays: strings('activeDays'),
      quizzesToday: v('quizzesToday', 0),
      quizzesTodayDay: v('quizzesTodayDay', ''),
      aiMessagesToday: v('aiMessagesToday', 0),
      lastDocketDay: j['lastDocketDay'] as String?,
      weekId: v('weekId', ''),
      weeklyXp: v('weeklyXp', 0),
      leagueTier: v('leagueTier', 1),
      leagueResultSeen: v('leagueResultSeen', ''),
      pendingLeagueOutcome: j['pendingLeagueOutcome'] is Map<String, dynamic>
          ? LeagueOutcome.fromJson(j['pendingLeagueOutcome'] as Map<String, dynamic>)
          : null,
      duelRating: v('duelRating', 1000),
      duelsPlayed: v('duelsPlayed', 0),
      duelsWon: v('duelsWon', 0),
      totalAnswered: v('totalAnswered', 0),
      totalCorrect: v('totalCorrect', 0),
      quizzesCompleted: v('quizzesCompleted', 0),
    );
  }
}
