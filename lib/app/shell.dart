import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/l10n.dart';
import '../core/services/feedback.dart';
import '../core/theme/app_colors.dart';

/// Bottom navigation shell: Home · Journey · Ask AI · Updates.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.nyaya.cardBorder)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) {
            ref.read(feedbackProvider).play(Haptic.select);
            // Re-tapping the current tab returns it to its root.
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.route_outlined),
              selectedIcon: const Icon(Icons.route_rounded),
              label: l.navJourney,
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome),
              label: l.navAskAi,
            ),
            NavigationDestination(
              icon: const Icon(Icons.newspaper_outlined),
              selectedIcon: const Icon(Icons.newspaper_rounded),
              label: l.navUpdates,
            ),
          ],
        ),
      ),
    );
  }
}
