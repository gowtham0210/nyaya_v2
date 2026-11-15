import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/storage/local_store.dart';
import 'package:nyaya/core/theme/app_colors.dart';
import 'package:nyaya/core/theme/app_theme.dart';
import 'package:nyaya/features/chat/presentation/chat_screen.dart';
import 'package:nyaya/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

/// Ask AI shows the official pages an answer relied on as small grey links
/// under the answer, and nothing when the answer used none.
void main() {
  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> messages) async {
    SharedPreferences.setMockInitialValues({'chat_v1': jsonEncode(messages)});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), tokenStoreProvider.overrideWithValue(signedInTokens())],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChatScreen(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  Map<String, dynamic> answer({List<Map<String, String>>? sources}) => {
        'role': 'assistant',
        'text': 'Murder is punishable under the BNS.',
        'at': '2026-11-14T10:00:00.000',
        'sources': ?sources,
      };

  testWidgets('shows one chip per website; tapping it raises a sheet with a button per page', (tester) async {
    await pump(tester, [
      answer(sources: [
        {'site': 'India Code', 'title': 'Punishment for murder.', 'url': 'https://indiacode.gov.in/handle/123456789/545600'},
        {'site': 'India Code', 'title': 'The Bharatiya Nyaya Sanhita, 2023', 'url': 'https://indiacode.gov.in/handle/123456789/496548'},
        {'site': 'Wikipedia', 'title': 'Capital punishment in India', 'url': 'https://en.wikipedia.org/wiki/Capital_punishment_in_India'},
      ]),
    ]);
    expect(tester.takeException(), isNull);
    // Two websites, two pills; the first has two pages.
    final pill = find.text('India Code +1');
    expect(find.text('Wikipedia'), findsOneWidget);
    expect(pill, findsOneWidget);

    // A small rounded chip in the theme's muted tone, under the answer text.
    final material = tester.widget<Material>(find.ancestor(of: pill, matching: find.byType(Material)).first);
    expect(material.shape, isA<StadiumBorder>());
    expect(tester.widget<Text>(pill).style!.fontSize, lessThan(14));
    expect(tester.getTopLeft(pill).dy, greaterThan(tester.getTopLeft(find.textContaining('Murder is punishable')).dy));
    // Nothing is shown until a chip is tapped.
    expect(find.text('Punishment for murder.'), findsNothing);

    await tester.tap(pill);
    await tester.pumpAndSettle();
    // A bottom sheet lists the pages, each with a button in the brand colour.
    expect(find.text('Punishment for murder.'), findsOneWidget);
    expect(find.text('The Bharatiya Nyaya Sanhita, 2023'), findsOneWidget);
    expect(find.text('indiacode.gov.in'), findsNWidgets(2));
    expect(find.text('Read the law on India Code'), findsNWidgets(2));
    expect(find.text('Capital punishment in India'), findsNothing, reason: 'that page belongs to the other chip');
    final sheetTop = tester.getTopLeft(find.text('Punishment for murder.')).dy;
    expect(sheetTop, greaterThan(tester.view.physicalSize.height / tester.view.devicePixelRatio / 3), reason: 'it rises from the bottom');
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    final bg = button.style!.backgroundColor!.resolve({})!;
    expect(bg, tester.element(find.byType(FilledButton).first).colors.primary);
    await tester.tapAt(const Offset(5, 5)); // tap outside closes the sheet
    await tester.pumpAndSettle();
    expect(find.text('Read the law on India Code'), findsNothing);

    await tester.tap(find.text('Wikipedia'));
    await tester.pumpAndSettle();
    expect(find.text('Read the article'), findsOneWidget);
  });

  testWidgets('shows no citation when the answer used no source', (tester) async {
    await pump(tester, [answer()]);
    expect(find.textContaining('Murder is punishable'), findsOneWidget);
    expect(find.textContaining('indiacode', findRichText: true), findsNothing);
    expect(find.textContaining('sci.gov.in', findRichText: true), findsNothing);
    expect(find.byType(PopupMenuButton<dynamic>), findsNothing);
  });
}
