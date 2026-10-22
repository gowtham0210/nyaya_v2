import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../domain/journey.dart';

/// A glossy level bubble (or chest) on the map.
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

  static const box = 130.0;

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
      top: center.dy - box / 2 - 14,
      width: box,
      height: box,
      child: MapNode(
        node: node,
        status: status,
        stars: stars,
        userName: userName,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isCurrent = status == NodeStatus.current;
    final size = isCurrent ? 78.0 : 66.0;
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
          if (isCurrent)
            Container(
              width: size + 26,
              height: size + 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: node.chapter.color.withValues(alpha: 0.25),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.25, 1.25), duration: 1400.ms)
                .fadeOut(duration: 1400.ms),
          Pressable(
            onTap: onTap,
            scale: 0.9,
            child: isCurrent
                ? bubble
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: -6, duration: 900.ms, curve: Curves.easeInOut)
                : bubble,
          ),
          if (node.kind == NodeKind.level && status == NodeStatus.completed)
            Positioned(top: 4, child: StarRow(stars: stars, size: 20, spacing: 0, arc: true)),
          if (isCurrent)
            Positioned(
              top: -16,
              child: _YouMarker(name: userName, color: node.chapter.color),
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
    final locked = status == NodeStatus.locked;
    final base = locked ? context.nyaya.locked : node.chapter.color;
    final dark = Color.lerp(base, Colors.black, 0.3)!;
    final light = Color.lerp(base, Colors.white, 0.25)!;
    final landmark = node.isLandmark;

    return Container(
      width: size,
      height: size + 6,
      alignment: Alignment.topCenter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          // 3D lip.
          Positioned(
            top: 6,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dark),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                radius: 0.9,
                colors: [light, base],
              ),
              border: Border.all(
                color: landmark && !locked ? AppPalette.gold : Colors.white.withValues(alpha: locked ? 0.4 : 0.9),
                width: landmark ? 4 : 3,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gloss highlight.
                Positioned(
                  top: size * 0.12,
                  left: size * 0.2,
                  child: Container(
                    width: size * 0.38,
                    height: size * 0.18,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(size),
                    ),
                  ),
                ),
                if (locked)
                  Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.9), size: size * 0.4)
                else if (landmark)
                  Icon(Icons.gavel_rounded, color: Colors.white, size: size * 0.42)
                else
                  Text(
                    '${node.level}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.4,
                      shadows: [Shadow(color: dark, offset: const Offset(0, 2))],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    final color = status == NodeStatus.locked ? context.nyaya.locked : AppPalette.gold;
    final chest = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.3)!, color],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Color.lerp(color, Colors.black, 0.35)!, offset: const Offset(0, 6)),
          if (current) BoxShadow(color: AppPalette.gold.withValues(alpha: 0.6), blurRadius: 24),
        ],
      ),
      child: Icon(
        opened ? Icons.inventory_2_outlined : Icons.redeem_rounded,
        size: size * 0.5,
        color: Colors.white,
      ),
    );
    return current
        ? chest.animate(onPlay: (c) => c.repeat(reverse: true)).rotate(begin: -0.02, end: 0.02, duration: 300.ms)
        : chest;
  }
}

class _YouMarker extends StatelessWidget {
  const _YouMarker({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InitialsAvatar(name: name, size: 22),
          const SizedBox(width: 5),
          Text(
            context.l10n.journeyYou,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
