import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';

/// Asks for a new display name and pops it, or `null` on cancel. The dialog
/// owns its controller so the field still has it during the closing animation.
class EditNameDialog extends StatefulWidget {
  const EditNameDialog({super.key, required this.current});

  final String current;

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late final _name = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.settingsEditName),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: l.onbNameHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _name.text), child: Text(l.commonDone)),
      ],
    );
  }
}
