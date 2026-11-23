import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/app/app.dart';
import 'package:nyaya/core/api/api_client.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/services/sounds.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/auth/data/auth_api.dart';
import 'package:nyaya/features/constitution/application/document_opener.dart';
import 'package:nyaya/features/constitution/data/constitution_repository.dart';
import 'package:nyaya/features/constitution/domain/constitution_edition.dart';
import 'package:nyaya/features/daily_tip/data/daily_tip_repository.dart';
import 'package:nyaya/features/leaderboard/data/league_api.dart';
import 'package:nyaya/features/legal_updates/data/legal_updates_repository.dart';
import 'package:nyaya/features/profile/domain/user_profile.dart';
import 'package:nyaya/features/progress/data/progress_api.dart';
import 'package:nyaya/features/quiz/data/quiz_api.dart';
import 'package:nyaya/features/reminders/data/reminder_notifications.dart';
import 'package:nyaya/features/review/data/review_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

void main() {
  setUpAll(() => AppTheme.useGoogleFonts = false);

  group('reading the API body', () {
    test('keeps every field the API gives, and the original apart from the editions', () {
      final lib = ConstitutionLibrary.fromJson(sampleConstitutionJson());
      expect(lib.editions.map((e) => e.id), ['en', 'hi', 'kn', 'kok', 'ml', 'sd-Arab', 'ta', 'te']);
      expect(lib.original?.id, 'original');
      expect(lib.editions.any((e) => e.id == 'original'), isFalse);
      expect(lib.original?.languageCode, isNull);
      expect(lib.stale, isFalse);
      expect(lib.fromCache, isFalse);
      expect(lib.fetchedAt, DateTime.utc(2026, 11, 17, 6));
      expect(lib.collectionUri.toString(), 'https://indiacode.gov.in/handle/123456789/618379');
      final ta = lib.editions.firstWhere((e) => e.id == 'ta');
      expect(ta.languageName, 'Tamil');
      expect(ta.nativeName, 'தமிழ்');
      expect(ta.script, 'Tamil');
      expect(ta.title, 'The Constitution of India in Tamil');
      expect(ta.sizeBytes, 10479267);
      expect(ta.modified, DateTime(2026, 8, 12));
      expect(ta.downloadUri.toString(), 'https://indiacode.gov.in/server/api/core/bitstreams/pdf-ta/content');
      expect(ta.sourcePageUri.toString(), 'https://indiacode.gov.in/handle/123456789/ta');
      expect(ta.large, isFalse);
      expect(ta.scanned, isFalse);
      expect(ta.authorityNote, isNull, reason: 'nothing is claimed about authority unless the API says it');
    });

    test('reads the warnings from the API and invents none', () {
      final lib = ConstitutionLibrary.fromJson(sampleConstitutionJson());
      ConstitutionEdition e(String id) => lib.editions.firstWhere((x) => x.id == id);
      expect((e('kok').large, e('kok').scanned), (true, true));
      expect((e('sd-Arab').large, e('sd-Arab').scanned), (false, true));
      expect((e('en').large, e('en').scanned), (false, false));
      expect((lib.original!.large, lib.original!.scanned), (true, true));
    });

    test('keeps reviewed wording about authority only when the API provides it', () {
      final json = sampleConstitutionJson();
      (json['editions'] as List).first['authority_note'] = 'Reviewed wording.';
      expect(ConstitutionLibrary.fromJson(json).editions.first.authorityNote, 'Reviewed wording.');
    });

    test('leaves out an edition it cannot use safely, and keeps the rest', () {
      final json = sampleConstitutionJson();
      final list = json['editions'] as List;
      list[0]['download_url'] = 'http://indiacode.gov.in/insecure.pdf'; // not https
      list[1].remove('file'); // no size
      list[2]['download_url'] = 'javascript:alert(1)';
      list[3]['language_name'] = '';
      final lib = ConstitutionLibrary.fromJson(json);
      expect(lib.editions.map((e) => e.id), ['ml', 'sd-Arab', 'ta', 'te']);
    });

    test('drops an unsafe source-page link but keeps the edition', () {
      final json = sampleConstitutionJson();
      (json['editions'] as List).first['source_page_url'] = 'http://example.com';
      expect(ConstitutionLibrary.fromJson(json).editions.first.sourcePageUri, isNull);
    });

    test('a body with no list of editions is an error; an empty list is fine', () {
      expect(() => ConstitutionLibrary.fromJson({'source': {}}), throwsFormatException);
      final empty = ConstitutionLibrary.fromJson({'editions': [], 'original': null});
      expect(empty.isEmpty, isTrue);
    });

    test('reports when the details may be out of date', () {
      expect(ConstitutionLibrary.fromJson(sampleConstitutionJson()).maybeOutOfDate, isFalse);
      expect(ConstitutionLibrary.fromJson(sampleConstitutionJson(stale: true)).maybeOutOfDate, isTrue);
      expect(ConstitutionLibrary.fromJson(sampleConstitutionJson()).asCached().maybeOutOfDate, isTrue);
    });
  });

  group('the language shown first', () {
    final lib = ConstitutionLibrary.fromJson(sampleConstitutionJson(without: ['hi']));

    test("is the app's own language when there is an edition in it", () {
      final r = lib.forLanguage('ta');
      expect(r.edition?.id, 'ta');
      expect(r.fellBack, isFalse);
    });

    test('is English, marked as a fallback, when there is none', () {
      final r = lib.forLanguage('hi');
      expect(r.edition?.id, 'en');
      expect(r.fellBack, isTrue);
    });

    test('is nothing when there is neither', () {
      final noEnglish = ConstitutionLibrary.fromJson(sampleConstitutionJson(without: ['en', 'hi']));
      expect(noEnglish.forLanguage('hi').edition, isNull);
    });
  });

  test('file sizes are rounded for people', () {
    expect(formatFileSize(512), '1 KB');
    expect(formatFileSize(468000), '468 KB');
    expect(formatFileSize(2404584), '2.4 MB');
    expect(formatFileSize(78814676), '78.8 MB');
    expect(formatFileSize(137000000), '137 MB');
  });

  /// Like the real API: JSON declared as UTF-8 (Tamil and Hindi names need it).
  http.Response json200(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  group('the API repository', () {
    late LocalStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = LocalStore(await SharedPreferences.getInstance());
    });

    HttpConstitutionRepository repoWith(Future<http.Response> Function(http.Request) handler, [List<Uri>? seen]) =>
        HttpConstitutionRepository(
          ApiClient(
            baseUrl: 'https://api.test',
            client: MockClient((req) {
              seen?.add(req.url);
              return handler(req);
            }),
            tokens: signedInTokens(),
          ),
          store,
        );

    test('asks for the list only, without a token, and never for a document', () async {
      final seen = <Uri>[];
      final repo = repoWith((req) async {
        expect(req.method, 'GET');
        expect(req.headers['authorization'], isNull);
        return json200(sampleConstitutionJson());
      }, seen);
      final lib = await repo.fetch();
      expect(lib.editions, hasLength(8));
      expect(seen.map((u) => u.toString()), ['https://api.test/v1/constitution']);
    });

    test('keeps the last list, and uses it marked out of date when the API is unreachable', () async {
      var up = true;
      final repo = repoWith((req) async {
        if (!up) return json200({'code': 'down', 'message': 'down'}, 503);
        return json200(sampleConstitutionJson());
      });
      expect((await repo.fetch()).fromCache, isFalse);
      up = false;
      final offline = await repo.fetch();
      expect(offline.fromCache, isTrue);
      expect(offline.maybeOutOfDate, isTrue);
      expect(offline.editions, hasLength(8));
    });

    test('with no list kept and the API down, it is an error', () async {
      final repo = repoWith((req) async => json200({'code': 'down', 'message': 'down'}, 503));
      await expectLater(repo.fetch(), throwsA(isA<ApiException>()));
    });

    test('a body it cannot read is an error, and is not kept', () async {
      final repo = repoWith((req) async => json200({'editions': 'nope'}));
      await expectLater(repo.fetch(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unreadable')));
      expect(store.readJson('constitution_library_v1'), isNull);
    });
  });

  group('opening an address', () {
    test('only ever hands on secure links', () async {
      const opener = UrlLauncherOpener();
      expect(await opener.open(Uri.parse('http://indiacode.gov.in/x.pdf')), isFalse);
      expect(await opener.open(Uri.parse('file:///etc/passwd')), isFalse);
      expect(await opener.open(Uri.parse('https:///no-host')), isFalse);
    });
  });

  group('the screen', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    /// Opens the app on Home with fakes for everything outside it.
    Future<ProviderContainer> pumpHome(
      WidgetTester tester, {
      required FakeConstitution constitution,
      required FakeDocumentOpener opener,
      AppLanguage language = AppLanguage.en,
      Size size = const Size(1170, 2532),
      double pixelRatio = 3,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = pixelRatio;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'profile_v1': jsonEncode({'onboarded': true, 'name': 'Ravi', 'persona': 'citizen', 'language': language.code}),
      });
      final sp = await SharedPreferences.getInstance();
      final tokens = signedInTokens();
      final api = FakeQuizApi();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          tokenStoreProvider.overrideWithValue(tokens),
          quizApiProvider.overrideWithValue(api),
          progressApiProvider.overrideWithValue(api),
          leagueApiProvider.overrideWithValue(api),
          reviewApiProvider.overrideWithValue(api),
          legalUpdatesRepositoryProvider.overrideWithValue(FakeLegalUpdates()),
          dailyTipRepositoryProvider.overrideWithValue(FakeDailyTips()),
          constitutionRepositoryProvider.overrideWithValue(constitution),
          documentOpenerProvider.overrideWithValue(opener),
          reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
          soundPlayerProvider.overrideWithValue(FakeSounds()),
          authApiProvider.overrideWithValue(FakeAuthApi(tokens)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NyayaApp()));
      await settle(tester);
      return container;
    }

    /// Taps Home's Constitution row and waits for the screen.
    Future<void> openScreen(
      WidgetTester tester, {
      String desc = 'Read the official text on India Code, in many languages',
    }) async {
      final row = find.text(desc);
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(row);
      await settle(tester);
    }

    Future<void> scrollTo(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
    }

    testWidgets('Home has its own Constitution entry that opens the screen, and the Journey card stays', (
      tester,
    ) async {
      await pumpHome(tester, constitution: FakeConstitution(), opener: FakeDocumentOpener());
      // The existing "Start here" Constitution card is still on Home.
      expect(find.text('Constitution of India'), findsWidgets);
      await openScreen(tester);
      expect(find.text('Constitution of India'), findsOneWidget);
      expect(
        find.text('Published on India Code by the Legislative Department, Ministry of Law and Justice.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Each edition is shown as published there. For legal or official use, please refer to the official source.',
        ),
        findsOneWidget,
      );
      expect(find.text('PDFs open in your browser or PDF app.'), findsOneWidget);
    });

    testWidgets('shows a loading state, then the editions', (tester) async {
      final repo = FakeConstitution()..gate = Completer<void>();
      await pumpHome(tester, constitution: repo, opener: FakeDocumentOpener());
      await openScreen(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Tamil'), findsNothing);
      repo.gate!.complete();
      await settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('All languages'), findsOneWidget);
    });

    testWidgets('shows every edition with its names, script, size and date, and the original apart', (tester) async {
      final json = sampleConstitutionJson();
      final list = json['editions'] as List;
      for (var i = 0; i < 18; i++) {
        list.add(
          constitutionEditionJson('x$i', 'Language $i', native: 'Native $i', script: 'Script $i', size: 1000000 + i),
        );
      }
      await pumpHome(
        tester,
        constitution: FakeConstitution(json: json),
        opener: FakeDocumentOpener(),
        // 390 x 6000 points: tall enough to build the whole list at once.
        size: const Size(390, 6000),
        pixelRatio: 1,
      );
      await openScreen(tester);
      expect(list, hasLength(26));
      for (final e in list.cast<Map<String, dynamic>>()) {
        // Each language once in "All languages" (English is also in "In your language").
        final name = find.text(e['language_name'] as String);
        expect(name, e['id'] == 'en' ? findsNWidgets(2) : findsOneWidget, reason: e['id'] as String);
      }
      expect(find.text('தமிழ்'), findsOneWidget);
      expect(find.text('Devanagari · About 3.1 MB · Updated Aug 12, 2026'), findsOneWidget);
      expect(find.text('Tamil'), findsOneWidget);

      // The original copy has its own section and is not among the languages.
      expect(find.text('The original copy'), findsOneWidget);
      expect(find.text('Copy of the Original Constitution of India'), findsOneWidget);
      expect(
        find.text('Original (1950) copy'),
        findsNothing,
        reason: 'the original shows its title, not as a language',
      );
      expect(find.text('All languages'), findsOneWidget);
    });

    testWidgets('puts the language of the app first', (tester) async {
      await pumpHome(tester, constitution: FakeConstitution(), opener: FakeDocumentOpener());
      await openScreen(tester);
      expect(find.text('In your language'), findsOneWidget);
      // English app: the English edition is the one shown first.
      final yourLanguage = tester.getTopLeft(find.text('In your language')).dy;
      final allLanguages = tester.getTopLeft(find.text('All languages')).dy;
      expect(yourLanguage, lessThan(allLanguages));
      expect(find.text('No edition in English is listed, so the English edition is shown.'), findsNothing);
    });

    testWidgets('falls back to English, and says so, when there is no edition in the language of the app', (
      tester,
    ) async {
      // Hindi app with no Hindi edition listed.
      await pumpHome(
        tester,
        constitution: FakeConstitution(json: sampleConstitutionJson(without: ['hi'])),
        opener: FakeDocumentOpener(),
        language: AppLanguage.hi,
      );
      await openScreen(tester, desc: 'India Code पर आधिकारिक पाठ पढ़ें, कई भाषाओं में');
      expect(
        find.text('Hindi में कोई संस्करण सूचीबद्ध नहीं है, इसलिए अंग्रेज़ी संस्करण दिखाया गया है।'),
        findsOneWidget,
      );
      // The English edition is offered under "your language".
      expect(find.text('English'), findsWidgets);
    });

    testWidgets('puts the Tamil edition first for a Tamil app, in Tamil', (tester) async {
      await pumpHome(tester, constitution: FakeConstitution(), opener: FakeDocumentOpener(), language: AppLanguage.ta);
      await openScreen(tester, desc: 'India Code இல் அதிகாரப்பூர்வ உரையை பல மொழிகளில் படியுங்கள்');
      expect(find.text('உங்கள் மொழியில்'), findsOneWidget);
      expect(find.text('இந்திய அரசியலமைப்பு'), findsOneWidget);
      expect(find.textContaining('மொழியில் பதிப்பு பட்டியலில் இல்லை'), findsNothing);
    });

    testWidgets('says when the details may be out of date, and only then', (tester) async {
      await pumpHome(
        tester,
        constitution: FakeConstitution(json: sampleConstitutionJson(stale: true)),
        opener: FakeDocumentOpener(),
      );
      await openScreen(tester);
      expect(find.text('These details may be out of date.'), findsOneWidget);
    });

    testWidgets('has no out-of-date notice when the API says the details are fresh', (tester) async {
      await pumpHome(tester, constitution: FakeConstitution(), opener: FakeDocumentOpener());
      await openScreen(tester);
      expect(find.text('These details may be out of date.'), findsNothing);
    });

    testWidgets('a failed load says so, and Try again brings the list', (tester) async {
      final repo = FakeConstitution()..failing = true;
      await pumpHome(tester, constitution: repo, opener: FakeDocumentOpener());
      await openScreen(tester);
      expect(find.text("Couldn't load the Constitution editions."), findsOneWidget);
      expect(find.text('All languages'), findsNothing);
      // The heading and attribution are still there.
      expect(find.text('Constitution of India'), findsOneWidget);

      repo.failing = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text("Couldn't load the Constitution editions."), findsNothing);
      expect(find.text('All languages'), findsOneWidget);
      expect(repo.calls, 2);
    });

    testWidgets('says so when there are no editions, with a way to retry', (tester) async {
      await pumpHome(
        tester,
        constitution: FakeConstitution(json: {'source': {}, 'original': null, 'editions': []}),
        opener: FakeDocumentOpener(),
      );
      await openScreen(tester);
      expect(find.text('No editions are available right now.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('opens an ordinary edition straight away, on its official address', (tester) async {
      final opener = FakeDocumentOpener();
      await pumpHome(tester, constitution: FakeConstitution(), opener: opener, language: AppLanguage.en);
      await openScreen(tester);
      await scrollTo(tester, find.text('Telugu'));
      await tester.tap(find.text('Telugu'));
      await settle(tester);
      expect(find.text('Before you open this PDF'), findsNothing);
      expect(opener.opened.map((u) => u.toString()), [
        'https://indiacode.gov.in/server/api/core/bitstreams/pdf-te/content',
      ]);
    });

    testWidgets('asks first about a large scanned edition, and opens it only after yes', (tester) async {
      final opener = FakeDocumentOpener();
      await pumpHome(tester, constitution: FakeConstitution(), opener: opener);
      await openScreen(tester);
      await scrollTo(tester, find.text('Konkani'));
      // The labels are on the row.
      expect(find.text('Large file'), findsWidgets);
      expect(find.text('Scanned'), findsWidgets);

      await tester.tap(find.text('Konkani'));
      await settle(tester);
      expect(find.text('Before you open this PDF'), findsOneWidget);
      expect(
        find.text('This file is about 137 MB. It may use a lot of mobile data, so Wi-Fi is better.'),
        findsOneWidget,
      );
      expect(
        find.text("This is a scanned copy. Its text can't be searched, and screen readers may not be able to read it."),
        findsOneWidget,
      );
      expect(opener.opened, isEmpty, reason: 'nothing opens before the answer');

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(opener.opened, isEmpty);

      await tester.tap(find.text('Konkani'));
      await settle(tester);
      await tester.tap(find.text('Open PDF'));
      await settle(tester);
      expect(opener.opened.map((u) => u.toString()), [
        'https://indiacode.gov.in/server/api/core/bitstreams/pdf-kok/content',
      ]);
    });

    testWidgets('a scanned edition that is not large only warns about scanning', (tester) async {
      final opener = FakeDocumentOpener();
      await pumpHome(tester, constitution: FakeConstitution(), opener: opener);
      await openScreen(tester);
      await scrollTo(tester, find.text('Sindhi (Arabic script)'));
      await tester.tap(find.text('Sindhi (Arabic script)'));
      await settle(tester);
      expect(find.text('Before you open this PDF'), findsOneWidget);
      expect(find.textContaining('mobile data'), findsNothing);
      expect(find.textContaining('scanned copy'), findsOneWidget);
    });

    testWidgets('a large edition that is not scanned only warns about its size', (tester) async {
      final json = sampleConstitutionJson();
      (json['editions'] as List).first
        ..['flags'] = {'large': true, 'scanned': false}
        ..['file']['size_bytes'] = 25000000;
      final opener = FakeDocumentOpener();
      await pumpHome(
        tester,
        constitution: FakeConstitution(json: json),
        opener: opener,
      );
      await openScreen(tester);
      await tester.tap(find.text('English').last);
      await settle(tester);
      expect(
        find.text('This file is about 25.0 MB. It may use a lot of mobile data, so Wi-Fi is better.'),
        findsOneWidget,
      );
      expect(find.textContaining('scanned copy'), findsNothing);
    });

    testWidgets('the original copy also asks first, because it is big and scanned', (tester) async {
      final opener = FakeDocumentOpener();
      await pumpHome(tester, constitution: FakeConstitution(), opener: opener);
      await openScreen(tester);
      await scrollTo(tester, find.text('Copy of the Original Constitution of India'));
      await tester.tap(find.text('Copy of the Original Constitution of India'));
      await settle(tester);
      expect(
        find.text('This file is about 78.8 MB. It may use a lot of mobile data, so Wi-Fi is better.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open PDF'));
      await settle(tester);
      expect(opener.opened.single.toString(), endsWith('/pdf-original/content'));
    });

    testWidgets('when the PDF will not open it says so and offers the official page for it', (tester) async {
      final opener = FakeDocumentOpener()
        ..refuses.add(Uri.parse('https://indiacode.gov.in/server/api/core/bitstreams/pdf-te/content'));
      await pumpHome(tester, constitution: FakeConstitution(), opener: opener);
      await openScreen(tester);
      await scrollTo(tester, find.text('Telugu'));
      await tester.tap(find.text('Telugu'));
      await settle(tester);
      expect(find.text("Couldn't open the PDF."), findsOneWidget);
      expect(find.text('Open on India Code'), findsOneWidget);
      expect(opener.opened, isEmpty);

      await tester.tap(find.text('Open on India Code'));
      await settle(tester);
      expect(opener.opened.map((u) => u.toString()), ['https://indiacode.gov.in/handle/123456789/te']);
    });

    testWidgets('when nothing can be opened, it says so again instead of failing silently', (tester) async {
      final opener = FakeDocumentOpener()..refuseAll = true;
      await pumpHome(tester, constitution: FakeConstitution(), opener: opener);
      await openScreen(tester);
      await scrollTo(tester, find.text('Telugu'));
      await tester.tap(find.text('Telugu'));
      await settle(tester);
      await tester.tap(find.text('Open on India Code'));
      await settle(tester);
      expect(find.text("Couldn't open the PDF."), findsOneWidget);
    });

    testWidgets('the link to the whole collection opens India Code, and a failure is reported', (tester) async {
      final opener = FakeDocumentOpener();
      await pumpHome(tester, constitution: FakeConstitution(), opener: opener);
      await openScreen(tester);
      await scrollTo(tester, find.text('See the collection on India Code'));
      await tester.tap(find.text('See the collection on India Code'));
      await settle(tester);
      expect(opener.opened.single.toString(), 'https://indiacode.gov.in/handle/123456789/618379');

      opener.refuseAll = true;
      await tester.tap(find.text('See the collection on India Code'));
      await settle(tester);
      expect(find.text("Couldn't open the PDF."), findsOneWidget);
    });

    testWidgets('long names stay inside the screen at the largest text size', (tester) async {
      final json = sampleConstitutionJson();
      (json['editions'] as List).first
        ..['language_name'] = 'Manipuri (Meitei Mayek script) with a very long name that must wrap'
        ..['native_name'] = 'ꯃꯩꯇꯩꯂꯣꯟ ꯃꯩꯇꯩꯂꯣꯟ ꯃꯩꯇꯩꯂꯣꯟ ꯃꯩꯇꯩꯂꯣꯟ ꯃꯩꯇꯩꯂꯣꯟ ꯃꯩꯇꯩꯂꯣꯟ';
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpHome(
        tester,
        constitution: FakeConstitution(json: json),
        opener: FakeDocumentOpener(),
        size: const Size(960, 1704),
      );
      await openScreen(tester);
      expect(tester.takeException(), isNull);
      await scrollTo(tester, find.text('All languages'));
      expect(tester.takeException(), isNull);
    });
  });
}
