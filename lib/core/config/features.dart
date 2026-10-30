/// Build-time switches.
abstract final class Features {
  /// Premium stays out of sight until store payments are real. Build with
  /// `--dart-define=NYAYA_PREMIUM=true` to show it (the API must also allow
  /// demo premium: DEMO_PREMIUM=true).
  static const premium = bool.fromEnvironment('NYAYA_PREMIUM');
}
