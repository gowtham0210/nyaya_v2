import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/journey/presentation/journey_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/legal_updates/presentation/update_detail_screen.dart';
import '../features/legal_updates/presentation/updates_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/premium/presentation/premium_screen.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/quiz/domain/quiz_models.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'shell.dart';

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const journey = '/journey';
  static const chat = '/chat';
  static const updates = '/updates';
  static const quiz = '/quiz';
  static const leaderboard = '/leaderboard';
  static const settings = '/settings';
  static const premium = '/premium';
  static const signIn = '/sign-in';
  static String update(String id) => '/updates/$id';
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    redirect: (context, state) {
      final onboarded = ref.read(profileProvider).onboarded;
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!onboarded && !atOnboarding && state.matchedLocation != Routes.premium) {
        return Routes.onboarding;
      }
      if (onboarded && atOnboarding) return Routes.home;
      return null;
    },
    // Any unknown deep link lands safely on Home instead of an error page.
    errorBuilder: (context, state) => const HomeScreen(),
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.journey, builder: (context, state) => const JourneyScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.chat,
              builder: (context, state) => ChatScreen(initialPrompt: state.uri.queryParameters['q']),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.updates, builder: (context, state) => const UpdatesScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/updates/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => UpdateDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.quiz,
        parentNavigatorKey: _rootKey,
        redirect: (context, state) => state.extra is QuizRequest ? null : Routes.home,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: QuizScreen(request: state.extra! as QuizRequest),
        ),
      ),
      GoRoute(
        path: Routes.leaderboard,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: AuthScreen()),
      ),
      GoRoute(
        path: Routes.premium,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: PremiumScreen(),
        ),
      ),
    ],
  );
});
