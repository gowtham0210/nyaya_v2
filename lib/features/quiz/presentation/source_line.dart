import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

/// "Reference: …" under an explanation, with a link to the official text of
/// the source when the question has one. Only https links are opened.
class SourceLine extends StatelessWidget {
  const SourceLine({super.key, required this.reference, this.url});

  final String reference;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final link = Uri.tryParse(url ?? '');
    final canOpen = link != null && link.isScheme('https') && link.host.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reference.isNotEmpty)
          Text(
            '${l.quizReference}: $reference',
            style: context.text.labelSmall?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w700),
          ),
        if (canOpen)
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final opened = await launchUrl(link, mode: LaunchMode.externalApplication).catchError((_) => false);
              if (!opened) messenger.showSnackBar(SnackBar(content: Text(l.quizOpenSourceFailed)));
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(l.quizOpenSource),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
          ),
      ],
    );
  }
}
