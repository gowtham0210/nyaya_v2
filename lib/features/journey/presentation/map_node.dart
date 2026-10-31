import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../domain/journey.dart';

/// A raised level bubble (or chest) on the map: terracotta once reached,
/// cream with a lock while ahead.
class MapNode extends StatelessWidget {
  const MapNode({
    super.key,
    required this.node,
    required this.status,
    required this.stars,
    required this.userName,
    required this.onTap,
  });

  final JourneyNode node;
  final NodeStatus status;
  final int stars;
  final String userName;
  final VoidCallback onTap;

  static const box = 140.0;

  static Widget positioned({
    required Offset center,
    required JourneyNode node,
    required NodeStatus status,
    required int stars,
    required String userName,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: center.dx - box / 2,
      top: center.dy - box / 2 - 4,
      width: box,
      height: box,
      child: MapNode(node: node, status: status, stars: stars, userName: userName, onTap: onTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isCurrent = status == NodeStatus.current;
    final size = isCurrent && node.kind == NodeKind.level ? 84.0 : 64.0;
    final label = node.kind == NodeKind.chest
        ? l.journeyChest
        : '${l.journeyLevel(node.level)}${status == NodeStatus.locked ? ', ${l.journeyLocked}' : ''}';

    final bubble = node.kind == NodeKind.chest
        ? _Chest(status: status, size: size)
        : _LevelBubble(node: node, status: status, size: size);

    return Semantics(
      button: true,
      label: label,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (isCurrent) ...[
            // Soft disc the current stop sits on, plus a slow pulse.
            Container(
              width: size + 44,
              height: size + 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.primary.withValues(alpha: context.isDark ? 0.18 : 0.07),
              ),
            ),
            Container(
                  width: size + 18,
                  height: size + 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.primary.withValues(alpha: 0.22),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.3, 1.3), duration: 1600.ms)
                .fadeOut(duration: 1600.ms),
          ],
          Pressable(
            onTap: onTap,
            scale: 0.9,
            child: isCurrent
                ? bubble
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: 0, end: -4, duration: 1100.ms, curve: Curves.easeInOut)
                : bubble,
          ),
          if (node.kind == NodeKind.level && status == NodeStatus.completed)
            Positioned(top: 18, child: StarRow(stars: stars, size: 20, spacing: 0, arc: true)),
          if (isCurrent)
            Positioned(
              top: node.kind == NodeKind.level ? -8 : 6,
              child: _YouMarker(name: userName),
            ),
        ],
      ),
    );
  }
}

/// Circle on a darker "lip" so it reads as a raised button.
class _RaisedDisc extends StatelessWidget {
  const _RaisedDisc({
    required this.size,
    required this.fill,
    required this.lip,
    required this.border,
    required this.child,
    this.glow,
  });

  final double size;
  final Color fill;
  final Color lip;
  final Color border;
  final Widget child;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 6,
      child: Stack(
        children: [
          Positioned(
            top: 6,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lip,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 6)),
                  if (glow != null) BoxShadow(color: glow!, blurRadius: 22),
                ],
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: border, width: size > 70 ? 5 : 4),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _LevelBubble extends StatelessWidget {
  const _LevelBubble({required this.node, required this.status, required this.size});

  final JourneyNode node;
  final NodeStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (status == NodeStatus.locked) return _LockedDisc(size: size);

    final landmark = node.isLandmark;
    return _RaisedDisc(
      size: size,
      fill: context.colors.primary,
      lip: AppPalette.terracottaDeep,
      border: landmark ? AppPalette.ochre : AppPalette.creamLight,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Soft highlight near the top edge (relative to the inner circle).
          Positioned(
            top: size * 0.05,
            child: Container(
              width: size * 0.36,
              height: size * 0.1,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          Center(
            child: landmark
                ? Icon(Icons.gavel_rounded, color: Colors.white, size: size * 0.42)
                : Text(
                    '${node.level}',
                    style: AppTheme.serif(TextStyle(color: Colors.white, fontSize: size * 0.5, height: 1.1)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LockedDisc extends StatelessWidget {
  const _LockedDisc({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _RaisedDisc(
      size: size,
      fill: context.isDark ? AppPalette.darkSurfaceHigh : AppPalette.sandLight,
      lip: context.isDark ? AppPalette.darkSurface : AppPalette.sand,
      // A faint warm rim so locked stops stand out from the dark map.
      border: context.isDark ? AppPalette.darkRoadRim : AppPalette.creamLight,
      child: Icon(Icons.lock_rounded, color: context.nyaya.textSecondary.withValues(alpha: 0.85), size: size * 0.36),
    );
  }
}

class _Chest extends StatelessWidget {
  const _Chest({required this.status, required this.size});

  final NodeStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final opened = status == NodeStatus.completed;
    final current = status == NodeStatus.current;
    final chest = _RaisedDisc(
      size: size,
      fill: context.colors.surface,
      lip: current ? AppPalette.burntClay : (context.isDark ? AppPalette.darkSurface : AppPalette.sand),
      border: context.isDark ? AppPalette.terracotta : Colors.white,
      glow: current ? AppPalette.ochre.withValues(alpha: 0.5) : null,
      child: Icon(
        opened ? Icons.inventory_2_outlined : Icons.redeem_rounded,
        size: size * 0.46,
        color: context.colors.primary,
      ),
    );
    return current
        ? chest.animate(onPlay: (c) => c.repeat(reverse: true)).rotate(begin: -0.02, end: 0.02, duration: 300.ms)
        : chest;
  }
}

class _YouMarker extends StatelessWidget {
  const _YouMarker({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seed 6 picks the terracotta fill so the marker matches the road.
          InitialsAvatar(name: name, seed: 6, size: 24),
          const SizedBox(width: 6),
          Text(
            context.l10n.journeyYou,
            style: context.text.labelLarge?.copyWith(color: context.colors.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
