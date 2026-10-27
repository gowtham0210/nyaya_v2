/// Where the Nyaya API runs. Override per build:
///
///   flutter run --dart-define=NYAYA_API_URL=http://192.168.0.10:3000
///
/// The default suits the iOS Simulator with the backend on this Mac. An
/// Android emulator reaches the Mac at http://10.0.2.2:3000 and a physical
/// phone needs the Mac's LAN address.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment('NYAYA_API_URL', defaultValue: 'http://localhost:3000');
}
