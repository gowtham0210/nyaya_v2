import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

/// Compact stat chip used in headers (🔥 streak, ⚡ energy, 🪙 coins).
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
    this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Pressable(
        onTap: onTap,
        // A tappable pill gets a full-size tap area around the same look.
        child: ConstrainedBox(
          constraints: onTap == null ? const BoxConstraints() : const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(widthFactor: 1, heightFactor: 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: context.isDark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: context.text.labelLarge?.copyWith(
                  color: context.isDark ? Colors.white : AppPalette.deepEarth,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )),
        ),
      ),
    );
  }
}

/// Solid initials avatar — deterministic color from [seed].
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.seed = 0, this.size = 40, this.ring});

  final String name;
  final int seed;
  final double size;
  final Color? ring;

  static const _fills = [
    AppPalette.terracotta,
    AppPalette.moss,
    AppPalette.burntClay,
    AppPalette.umber,
    AppPalette.slate,
    AppPalette.ochreDeep,
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.first.characters.first + (parts.length > 1 ? parts.last.characters.first : ''))
            .toUpperCase();
    final fill = _fills[(seed == 0 ? name.hashCode : seed).abs() % _fills.length];
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring == null ? 0 : 2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}

/// Rounded animated progress bar with a flat fill.
class GlossyProgressBar extends StatelessWidget {
  const GlossyProgressBar({super.key, required this.value, this.color, this.height = 14, this.track});

  final double value;
  final Color? color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.nyaya.success;
    return Semantics(
      value: '${(value * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: track ?? context.colors.outlineVariant,
          borderRadius: BorderRadius.circular(height),
        ),
        child: LayoutBuilder(
          builder: (context, box) => Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              width: box.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 18, this.spacing = 2, this.arc = false});

  final int stars;
  final double size;
  final double spacing;
  final bool arc;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars of 3 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing),
              child: Transform.translate(
                offset: Offset(0, arc && i != 1 ? size * 0.25 : 0),
                child: Icon(
                  Icons.star_rounded,
                  size: arc && i == 1 ? size * 1.2 : size,
                  color: i < stars ? context.nyaya.gold : context.nyaya.locked,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Bordered surface card with optional tap. Pass [bordered] false for solid
/// brand fills (e.g. [NyayaColors.hero]).
class NyayaCard extends StatelessWidget {
  const NyayaCard({super.key, required this.child, this.onTap, this.padding, this.color, this.bordered = true});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color ?? context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: bordered ? Border.all(color: context.nyaya.cardBorder) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.98, child: card);
  }
}

/// Circular progress ring with a child in the middle (daily goal).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.child,
    this.size = 64,
    this.stroke = 7,
    this.color,
  });

  final double value;
  final Widget child;
  final double size;
  final double stroke;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(
            value: v,
            stroke: stroke,
            color: color ?? context.nyaya.success,
            track: context.colors.outlineVariant,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.stroke, required this.color, required this.track});

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * pi, false, p..color = track);
    if (value > 0) canvas.drawArc(r, -pi / 2, 2 * pi * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}
