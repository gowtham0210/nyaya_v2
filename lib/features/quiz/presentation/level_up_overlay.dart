import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../../core/widgets/common.dart';
import '../../journey/domain/journey.dart';

/// The moment a Learning Path level opens the next step: a big "Level up!"
/// badge, the stars won, the XP earned, a league climb when there was one,
/// and what is now open. Continue shows the usual result underneath.
class LevelUpOverlay extends StatelessWidget {
  const LevelUpOverlay({
    super.key,
    required this.cleared,
    required this.next,
    required this.stars,
    required this.xp,
    required this.rankBefore,
    required this.rankAfter,
    required this.onContinue,
  });

  /// The level just cleared.
  final JourneyNode cleared;

  /// The stop that is now open: the next level, the chapter chest, or the
  /// first level of a new chapter. Null at the end of the path.
  final JourneyNode? next;
  final int stars;
  final int xp;
  final int rankBefore;
  final int rankAfter;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = cleared.chapter.color;
    final n = next;
    final unlocked = n == null
        ? null
        : n.kind == NodeKind.chest
            ? l.levelUpChest
            : n.chapter.id != cleared.chapter.id
                ? l.levelUpNewChapter(l.chapterTitle(n.chapter.id))
                : l.levelUpNextLevel(n.level);
    final climbed = rankAfter < rankBefore;

    return Material(
      color: context.colors.surface.withValues(alpha: 0.97),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.lg),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  // Scrolls only when very large text makes it taller than the screen.
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
              // Badge: a ringed disc with the chapter's icon, popping in.
              ExcludeSemantics(
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: AppPalette.ochre, width: 6),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: Icon(cleared.chapter.icon, size: 68, color: Colors.white),
                )
                    .animate()
                    .scale(begin: const Offset(0.3, 0.3), duration: 500.ms, curve: Curves.elasticOut)
                    .then()
                    .shimmer(duration: 900.ms, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  l.levelUpTitle,
                  textAlign: TextAlign.center,
                  style: AppTheme.serif(TextStyle(fontSize: 40, height: 1.1, color: context.colors.primary)),
                ),
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${l.levelUpCleared(cleared.level)} · ${l.chapterTitle(cleared.chapter.id)}',
                textAlign: TextAlign.center,
                style: context.text.titleMedium?.copyWith(color: context.nyaya.textSecondary),
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: AppSpacing.md),
              StarRow(stars: stars, size: 36, spacing: 6, arc: true).animate().fadeIn(delay: 450.ms).scale(),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pill(icon: Icons.diamond_rounded, text: '+$xp XP', color: context.colors.primary),
                  if (climbed)
                    _Pill(
                      icon: Icons.trending_up_rounded,
                      text: l.levelUpRank(rankBefore, rankAfter),
                      color: context.nyaya.success,
                    ),
                ],
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
              if (unlocked != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open_rounded, color: color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        unlocked,
                        textAlign: TextAlign.center,
                        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 750.ms),
              ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ChunkyButton(label: l.commonContinue, onPressed: onContinue, color: color)
                  .animate()
                  .fadeIn(delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: context.text.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
