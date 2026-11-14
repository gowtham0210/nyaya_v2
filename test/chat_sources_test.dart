import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/core/api/token_store.dart';
import 'package:nyaya/core/storage/local_store.dart';
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

  testWidgets('shows one grey pill per website; tapping it lists the pages with their titles', (tester) async {
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

    final box = tester.widget<Container>(find.ancestor(of: pill, matching: find.byType(Container)).first);
    final deco = box.decoration! as BoxDecoration;
    final fill = deco.color!;
    expect((fill.r - fill.g).abs() + (fill.g - fill.b).abs(), lessThan(0.02), reason: 'neutral grey');
    expect(deco.borderRadius, BorderRadius.circular(999), reason: 'oval pill');
    final text = tester.widget<Text>(pill);
    expect(text.style!.fontSize, lessThan(12));
    // Under the answer text.
    expect(tester.getTopLeft(pill).dy, greaterThan(tester.getTopLeft(find.textContaining('Murder is punishable')).dy));
    // Nothing is shown until a pill is tapped.
    expect(find.text('Punishment for murder.'), findsNothing);

    await tester.tap(pill);
    await tester.pumpAndSettle();
    expect(find.text('Punishment for murder.'), findsOneWidget);
    expect(find.text('The Bharatiya Nyaya Sanhita, 2023'), findsOneWidget);
    expect(find.text('indiacode.gov.in'), findsNWidgets(2));
    expect(find.text('Capital punishment in India'), findsNothing, reason: 'that page belongs to the other pill');
  });

  testWidgets('shows no citation when the answer used no source', (tester) async {
    await pump(tester, [answer()]);
    expect(find.textContaining('Murder is punishable'), findsOneWidget);
    expect(find.textContaining('indiacode', findRichText: true), findsNothing);
    expect(find.textContaining('sci.gov.in', findRichText: true), findsNothing);
    expect(find.byType(PopupMenuButton<dynamic>), findsNothing);
  });
}
