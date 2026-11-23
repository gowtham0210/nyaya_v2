/// Where the Nyaya API runs. Override per build:
///
///   flutter run --dart-define=NYAYA_API_URL=http://192.168.0.10:3000
///
/// The default suits the iOS Simulator with the backend on this Mac. An
/// Android emulator reaches the Mac at http://10.0.2.2:3000 and a physical
/// phone needs the Mac's LAN address.
///
/// Development uses the default above. A RELEASE build must always be given the
/// hosted API: the default is localhost, which a phone cannot reach, so Daily
/// Tips (and everything else) would show their error states. Build releases
/// with `tool/build_release_apk.ps1 -ApiUrl https://...`, which checks this.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment('NYAYA_API_URL', defaultValue: 'http://localhost:3000');
}
