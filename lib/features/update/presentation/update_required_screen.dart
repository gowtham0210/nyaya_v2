import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

/// Shown in place of the whole app when this build is older than the server allows.
/// Progress lives on the account, so nothing is lost by updating.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, this.updateUrl});

  final String? updateUrl;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final link = Uri.tryParse(updateUrl ?? '');
    final canOpen = link != null && link.isScheme('https') && link.host.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.system_update_rounded, size: 72, color: context.colors.primary),
              const SizedBox(height: 24),
              Text(
                l.updateRequiredTitle,
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(l.updateRequiredBody, textAlign: TextAlign.center, style: context.text.bodyLarge),
              if (canOpen) ...[
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final opened = await launchUrl(link, mode: LaunchMode.externalApplication).catchError((_) => false);
                    if (!opened) messenger.showSnackBar(SnackBar(content: Text(l.quizOpenSourceFailed)));
                  },
                  child: Text(l.updateRequiredAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
