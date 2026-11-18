/// Build-time switches.
abstract final class Features {
  /// No daily limit on Ask AI messages, in every build including release. To
  /// bring the limit of [GameRules.freeDailyAiMessages] back, build with
  /// `--dart-define=NYAYA_UNLIMITED_AI=false`, and set CHAT_FREE_DAILY_LIMIT
  /// on the API, which has its own limit.
  static const unlimitedAi = bool.fromEnvironment('NYAYA_UNLIMITED_AI', defaultValue: true);

  /// Premium stays out of sight until store payments are real. Build with
  /// `--dart-define=NYAYA_PREMIUM=true` to show it (the API must also allow
  /// demo premium: DEMO_PREMIUM=true).
  static const premium = bool.fromEnvironment('NYAYA_PREMIUM');
}
