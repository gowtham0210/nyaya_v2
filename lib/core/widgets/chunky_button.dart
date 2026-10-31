import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Primary game button with a solid "3D" lip that presses down on tap.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.foreground,
    this.icon,
    this.height = 56,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? foreground;
  final IconData? icon;
  final double height;
  final bool expand;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;
  static const _lip = 5.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final base = enabled ? (widget.color ?? scheme.primary) : scheme.outlineVariant;
    // On the theme's own primary use its matching text colour (dark text in dark mode).
    final fg = enabled
        ? (widget.foreground ?? (widget.color == null ? scheme.onPrimary : Colors.white))
        : scheme.onSurfaceVariant;
    final lipColor = Color.lerp(base, Colors.black, 0.28)!;
    final offset = _down ? _lip : 0.0;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: fg, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontSize: 15,
                  letterSpacing: context.tracking(0.8),
                ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: SizedBox(
          height: widget.height + _lip,
          width: widget.expand ? double.infinity : null,
          child: Stack(
            children: [
              Positioned.fill(
                top: _lip,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: enabled ? lipColor : scheme.outline,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: offset,
                height: widget.height,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
