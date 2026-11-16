import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Small uppercase heading above a [SectionGroup], shared by Profile and Settings.
class ListHeader extends StatelessWidget {
  const ListHeader(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: context.text.labelMedium?.copyWith(
            color: color ?? context.nyaya.textSecondary,
            letterSpacing: context.tracking(1.1),
          ),
        ),
      ),
    );
  }
}

/// A rounded card holding a list of tiles separated by dividers.
class SectionGroup extends StatelessWidget {
  const SectionGroup({super.key, required this.children, this.borderColor});

  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    // Material (not a DecoratedBox) so ListTile ink and backgrounds render.
    return Material(
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: borderColor ?? context.nyaya.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One number with an icon and a label, used in the progress grid.
class StatTile extends StatelessWidget {
  const StatTile(this.icon, this.value, this.label, this.color, {super.key});

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NyayaCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(value, style: context.text.titleMedium, maxLines: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: context.nyaya.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Scrolls its child to the top of the screen once, after the first frame.
class ScrollIntoView extends StatefulWidget {
  const ScrollIntoView({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<ScrollIntoView> createState() => _ScrollIntoViewState();
}

class _ScrollIntoViewState extends State<ScrollIntoView> {
  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A bottom sheet with one radio choice; picking a value closes the sheet.
Future<void> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T) label,
  required ValueChanged<T> onSelected,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: context.text.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<T>(
            groupValue: selected,
            onChanged: (v) {
              if (v != null) onSelected(v);
              Navigator.pop(context);
            },
            child: Column(
              children: [
                for (final v in values) RadioListTile<T>(value: v, title: Text(label(v))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
