import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../gamification/domain/league.dart';
import '../../profile/application/profile_controller.dart';
import '../../progress/application/progress_sync.dart';
import '../../profile/domain/user_profile.dart';
import 'widgets/explore_sections.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowLeagueOutcome());
  }

  void _maybeShowLeagueOutcome() {
    final outcome = ref.read(profileProvider).pendingLeagueOutcome;
    if (outcome == null || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => LeagueOutcomeDialog(outcome: outcome),
    ).then((_) => ref.read(profileProvider.notifier).acknowledgeLeagueOutcome());
  }

  @override
  Widget build(BuildContext context) {
    const page = EdgeInsets.symmetric(horizontal: AppSpacing.page);
    const sections = <Widget>[
      Padding(padding: page, child: FeaturedLawsCarousel()),
      Padding(padding: page, child: ContinueLearningCard()),
      SizedBox(height: AppSpacing.xl),
      // Scrolls edge to edge, so it pads itself.
      LatestUpdatesSection(),
      Padding(padding: page, child: CoreLawsSection()),
    ];

    return Scaffold(
      // Keeps scrolled content out from under the status bar.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.colors.primary,
          onRefresh: () async {
            ref.read(profileProvider.notifier).refreshDay();
            await ref.read(progressSyncProvider.notifier).refresh();
          },
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: ExploreHeader()),
              SliverPadding(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
                sliver: SliverList.list(
                  children: [
                    for (final (i, s) in sections.indexed)
                      s is SizedBox ? s : s.animate().fadeIn(delay: (40 * i).ms, duration: 350.ms).slideY(begin: 0.06),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown once after a week closes.
class LeagueOutcomeDialog extends StatelessWidget {
  const LeagueOutcomeDialog({super.key, required this.outcome});

  final LeagueOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final to = Leagues.tier(outcome.toTier);
    final name = l.tierName(to);
    final title = outcome.promoted
        ? l.leagueOutcomePromoted(name)
        : (outcome.demoted ? l.leagueOutcomeDemoted(name) : l.leagueOutcomeStayed(name));
    return AlertDialog(
      icon: Text(to.emblem, style: const TextStyle(fontSize: 48)),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(l.leagueOutcomeRank(outcome.rank), textAlign: TextAlign.center),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push(Routes.leaderboard);
          },
          child: Text(l.leaderboardTitle),
        ),
      ],
    );
  }
}
