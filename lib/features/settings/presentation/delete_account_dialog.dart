import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';

/// Asks for the password, then deletes the account on the server. Pops `true`
/// once it is gone, so the caller can clear what the phone still holds.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).deleteAccount(password: _password.text);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'wrong_password' => l.settingsDeleteAccountWrong,
          // Wrong passwords here count towards the sign-in limit.
          'rate_limited' => l.authErrorRateLimited,
          _ => l.settingsDeleteAccountFailed,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.settingsDeleteAccount),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.settingsDeleteAccountBody),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(labelText: l.settingsDeleteAccountPassword, errorText: _error),
              onSubmitted: (_) => _delete(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.nyaya.error),
          onPressed: _busy ? null : _delete,
          child: Text(l.settingsDeleteAccountAction),
        ),
      ],
    );
  }
}
