import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/review/data/review_api.dart';
import 'package:nyaya/features/update/application/update_check.dart';
import 'package:nyaya/features/update/data/app_config_api.dart';
import 'package:nyaya/features/update/domain/app_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

class _FakeConfig implements AppConfigApi {
  _FakeConfig(this.settings);

  Object settings; // AppSettings, or an ApiException to throw
  var calls = 0;

  @override
  Future<AppSettings> fetch() async {
    calls++;
    final s = settings;
    if (s is ApiException) throw s;
    return s as AppSettings;
  }
}

void main() {
  setUpAll(() => AppTheme.useGoogleFonts = false);

  test('older means older: numbers are compared one by one, not as text', () {
    expect(isOlderThan('0.1.0', '0.2.0'), isTrue);
    expect(isOlderThan('0.9.0', '0.10.0'), isTrue);
    expect(isOlderThan('1.0.0', '0.9.9'), isFalse);
    expect(isOlderThan('0.2.0', '0.2.0'), isFalse);
    expect(isOlderThan('0.2.1+9', '0.2.1'), isFalse); // the build number is ignored
    expect(isOlderThan('1.2', '1.2.1'), isTrue); // a missing number counts as 0
    expect(isOlderThan('2.0.0-beta', '1.9.9'), isFalse);
  });

  test('a version that cannot be read never blocks anyone', () {
    expect(isOlderThan('', '1.0.0'), isFalse);
    expect(isOlderThan('abc', '1.0.0'), isFalse);
    expect(isOlderThan('1.0.0', 'soon'), isFalse);
    expect(isOlderThan('1.2.3.4', '9.0.0'), isFalse);
  });

  ProviderContainer containerFor(String? installed, _FakeConfig config) {
    final c = ProviderContainer(overrides: [
      appVersionProvider.overrideWithValue(installed),
      appConfigApiProvider.overrideWithValue(config),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('an old build is told to update, and gets the link', () async {
    final config = _FakeConfig(const AppSettings(minVersion: '0.2.0', updateUrl: 'https://apps.apple.com/app/id1'));
    final c = containerFor('0.1.0', config);
    await c.read(updateCheckProvider.notifier).check();
    expect(c.read(updateCheckProvider)?.updateUrl, 'https://apps.apple.com/app/id1');
  });

  test('a current build, or no minimum, is left alone', () async {
    final config = _FakeConfig(const AppSettings(minVersion: '0.1.0'));
    final c = containerFor('0.1.0', config);
    await c.read(updateCheckProvider.notifier).check();
    expect(c.read(updateCheckProvider), isNull);

    config.settings = const AppSettings();
    await c.read(updateCheckProvider.notifier).check();
    expect(c.read(updateCheckProvider), isNull);
  });

  test('trouble reaching the server never blocks, and a build that was blocked is let in once allowed', () async {
    final config = _FakeConfig(const AppSettings(minVersion: '0.2.0'));
    final c = containerFor('0.1.0', config);
    await c.read(updateCheckProvider.notifier).check();
    expect(c.read(updateCheckProvider), isNotNull);

    // Offline later: the last answer stands, it neither blocks nor unblocks.
    config.settings = const ApiException(0, 'network', 'offline');
    await c.read(updateCheckProvider.notifier).check();
    expect(c.read(updateCheckProvider), isNotNull);

    config.settings = const AppSettings(minVersion: '0.1.0');
    await c.read(updateCheckProvider.notifier).check();
    expect(c.read(updateCheckProvider), isNull);

    // On a fresh start with no connection nothing is blocked.
    final offline = containerFor('0.1.0', _FakeConfig(const ApiException(0, 'network', 'offline')));
    await offline.read(updateCheckProvider.notifier).check();
    expect(offline.read(updateCheckProvider), isNull);
  });

  test('without a known version the server is not even asked', () async {
    final config = _FakeConfig(const AppSettings(minVersion: '9.0.0'));
    final c = containerFor(null, config);
    await c.read(updateCheckProvider.notifier).check();
    expect(config.calls, 0);
    expect(c.read(updateCheckProvider), isNull);
  });

  Future<void> pump(WidgetTester tester, String installed, _FakeConfig config) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final tokens = signedInTokens();
    final api = FakeQuizApi();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      tokenStoreProvider.overrideWithValue(tokens),
      quizApiProvider.overrideWithValue(api),
      progressApiProvider.overrideWithValue(api),
      leagueApiProvider.overrideWithValue(api),
      reviewApiProvider.overrideWithValue(api),
      authApiProvider.overrideWithValue(FakeAuthApi(tokens)),
      appVersionProvider.overrideWithValue(installed),
      appConfigApiProvider.overrideWithValue(config),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NyayaApp()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('an old build sees only the update screen', (tester) async {
    await pump(tester, '0.1.0', _FakeConfig(const AppSettings(minVersion: '0.2.0', updateUrl: 'https://apps.apple.com/app/id1')));
    expect(find.text('Please update Nyaya'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Choose your language'), findsNothing);
  });

  testWidgets('without a store link there is a message but no button', (tester) async {
    await pump(tester, '0.1.0', _FakeConfig(const AppSettings(minVersion: '0.2.0')));
    expect(find.text('Please update Nyaya'), findsOneWidget);
    expect(find.text('Update'), findsNothing);
  });

  testWidgets('a current build opens the app as usual', (tester) async {
    await pump(tester, '0.2.0', _FakeConfig(const AppSettings(minVersion: '0.2.0')));
    expect(find.text('Please update Nyaya'), findsNothing);
    expect(find.text('Choose your language'), findsOneWidget);
  });
}
