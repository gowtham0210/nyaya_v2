import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../application/document_opener.dart';
import '../domain/constitution_edition.dart';

/// Opens an edition's official India Code PDF in the phone's browser or PDF
/// app. Large and scanned ones ask first. If the phone cannot open it, says
/// so and offers India Code's page for that edition.
Future<void> openEdition(BuildContext context, WidgetRef ref, ConstitutionEdition edition) async {
  final l = context.l10n;
  final opener = ref.read(documentOpenerProvider);
  final messenger = ScaffoldMessenger.of(context);

  if (edition.large || edition.scanned) {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => _WarningDialog(edition: edition),
    );
    if (go != true) return;
  }

  if (await opener.open(edition.downloadUri)) return;
  final page = edition.sourcePageUri;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l.constitutionOpenFailed),
        duration: const Duration(seconds: 8),
        action: page == null
            ? null
            : SnackBarAction(
                label: l.constitutionOpenSourcePage,
                onPressed: () async {
                  if (!await opener.open(page)) {
                    messenger.showSnackBar(SnackBar(content: Text(l.constitutionOpenFailed)));
                  }
                },
              ),
      ),
    );
}

/// Opens India Code's page for the whole collection (the attribution link).
Future<void> openSourcePage(BuildContext context, WidgetRef ref, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = context.l10n.constitutionOpenFailed;
  if (!await ref.read(documentOpenerProvider).open(uri)) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

class _WarningDialog extends StatelessWidget {
  const _WarningDialog({required this.edition});

  final ConstitutionEdition edition;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppPalette.ochreText),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.text.bodyMedium?.copyWith(height: 1.4))),
        ],
      ),
    );
    return AlertDialog(
      title: Text(l.constitutionWarnTitle),
      // Scrolls, so large text never overflows the dialog.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(
            Icons.menu_book_outlined,
            edition.nativeName == null ? edition.languageName : '${edition.languageName} · ${edition.nativeName}',
          ),
          if (edition.large)
            line(Icons.data_usage_rounded, l.constitutionLargeWarning(formatFileSize(edition.sizeBytes))),
          if (edition.scanned) line(Icons.image_search_rounded, l.constitutionScannedWarning),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.commonCancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.constitutionOpenAnyway)),
      ],
    );
  }
}
