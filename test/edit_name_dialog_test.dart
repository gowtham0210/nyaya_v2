import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nyaya/features/settings/presentation/edit_name_dialog.dart';
import 'package:nyaya/l10n/app_localizations.dart';

/// The name dialog used to dispose its text controller as soon as it popped,
/// while the field was still animating out, and Cancel showed a red error screen.
void main() {
  /// Opens the dialog; [onResult] gets what it pops.
  Future<void> open(WidgetTester tester, void Function(String?) onResult) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              onResult(await showDialog<String>(context: context, builder: (_) => const EditNameDialog(current: 'Asha'))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancel closes cleanly and returns nothing', (tester) async {
    String? name = 'unset';
    await open(tester, (n) => name = n);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(EditNameDialog), findsNothing);
    expect(name, isNull);
  });

  testWidgets('Done returns the typed name', (tester) async {
    String? name;
    await open(tester, (n) => name = n);
    await tester.enterText(find.byType(TextField), 'Ravi');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(name, 'Ravi');
  });
}
