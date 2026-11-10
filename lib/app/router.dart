import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/config/features.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/journey/presentation/journey_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/legal_updates/presentation/update_detail_screen.dart';
import '../features/legal_updates/presentation/updates_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/premium/presentation/premium_screen.dart';
import '../features/review/presentation/review_screen.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/quiz/domain/quiz_models.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/search/presentation/search_screen.dart';
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
  static const review = '/review';
  static const settings = '/settings';
  static const store = '/settings?section=store';
  static const search = '/search';
  static const premium = '/premium';
  static const signIn = '/sign-in';

  /// Sign-in with no way to skip it: every learner needs an account.
  static const signInRequired = '/sign-in?required=1';
  static const resetPassword = '/reset-password';
  static String update(String id) => '/updates/$id';
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    redirect: (context, state) {
      final onboarded = ref.read(profileProvider).onboarded;
      final signedIn = ref.read(authProvider) != null;
      final location = state.matchedLocation;
      final atOnboarding = location == Routes.onboarding;
      final atAuth = location == Routes.signIn || location == Routes.resetPassword;
      if (!Features.premium && location == Routes.premium) return Routes.home;
      if (!onboarded && !atOnboarding && !atAuth && location != Routes.premium) {
        return Routes.onboarding;
      }
      if (onboarded && atOnboarding) return Routes.home;
      // Language first (onboarding), then an account: nothing else works signed out.
      if (onboarded && !signedIn && !atAuth) return Routes.signInRequired;
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
        path: Routes.review,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: Routes.search,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => SettingsScreen(openStore: state.uri.queryParameters['section'] == 'store'),
      ),
      GoRoute(
        path: Routes.signIn,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: AuthScreen(required: state.uri.queryParameters['required'] == '1'),
        ),
      ),
      GoRoute(
        path: Routes.resetPassword,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => ResetPasswordScreen(email: state.extra as String? ?? ''),
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
  // Signing out (or a session the server ended) leads straight to sign-in.
  // Signing in needs no refresh: the sign-in screen moves on by itself, and a
  // refresh would rebuild it mid-way.
  ref.listen(authProvider, (before, after) {
    if (before != null && after == null) router.refresh();
  });
  return router;
});
