import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Scales down slightly while pressed — the tactile "squish" that makes
/// game UIs feel alive. Also works from a keyboard: it takes focus, shows a
/// ring while focused and presses on Enter or Space.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // Without onTap there is nothing to press, so screen readers don't call it a button.
    final enabled = widget.onTap != null;
    return FocusableActionDetector(
      enabled: enabled,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call()),
      },
      // Only for keyboard focus: a tap never shows the ring.
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Container(
            foregroundDecoration: _focused
                ? BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  )
                : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
