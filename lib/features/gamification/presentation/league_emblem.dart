import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/league.dart';

/// A league tier's picture. Icons, not emoji: Flutter on iOS draws emoji as
/// "?" boxes with the app's fonts.
class LeagueEmblem extends StatelessWidget {
  const LeagueEmblem(this.tier, {super.key, required this.size});

  final LeagueTier tier;
  final double size;

  static IconData iconFor(LeagueTier tier) => switch (tier.key) {
    'nyayaPanchayat' => Icons.eco_rounded,
    'gramNyayalaya' => Icons.cottage_rounded,
    'munsiffCourt' => Icons.history_edu_rounded,
    'magistrateCourt' => Icons.gavel_rounded,
    'districtCourt' => Icons.account_balance_rounded,
    'sessionsCourt' => Icons.balance_rounded,
    'highCourt' => Icons.shield_rounded,
    _ => Icons.workspace_premium_rounded,
  };

  @override
  Widget build(BuildContext context) => Icon(iconFor(tier), size: size, color: AppPalette.ochre);
}

/// Gold, silver and bronze for the top three on a leaderboard.
class RankMedal extends StatelessWidget {
  const RankMedal(this.rank, {super.key, this.size = 24});

  final int rank;
  final double size;

  static const _colors = {1: AppPalette.ochre, 2: Color(0xFF9AA3A6), 3: AppPalette.burntClay};

  @override
  Widget build(BuildContext context) => Icon(Icons.emoji_events_rounded, size: size, color: _colors[rank]);
}
