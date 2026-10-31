import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/l10n.dart';
import '../core/theme/app_theme.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/progress/application/progress_sync.dart';
import '../features/reminders/application/reminder_sync.dart';
import '../features/update/application/update_check.dart';
import '../features/update/presentation/update_required_screen.dart';
import 'router.dart';

/// Largest text size the app follows from the phone's settings.
const maxTextScale = 1.5;

class NyayaApp extends ConsumerStatefulWidget {
  const NyayaApp({super.key});

  @override
  ConsumerState<NyayaApp> createState() => _NyayaAppState();
}

class _NyayaAppState extends ConsumerState<NyayaApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Energy reset and league close happen on every resume; progress comes from the server.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(profileProvider.notifier).refreshDay();
        ref.read(progressSyncProvider.notifier).refresh();
        ref.read(progressSyncProvider.notifier).noteOpen();
        // A new day, or practice done elsewhere, changes which reminders are due.
        ref.read(reminderSyncProvider.notifier).refresh();
        ref.read(updateCheckProvider.notifier).check();
      },
    );
    ref.read(progressSyncProvider.notifier).refresh();
    ref.read(progressSyncProvider.notifier).noteOpen();
    ref.read(updateCheckProvider.notifier).check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps progress in step with sign-in and sign-out.
    ref.watch(progressSyncProvider);
    // Keeps the daily reminders in step with the profile.
    ref.watch(reminderSyncProvider);
    final update = ref.watch(updateCheckProvider);
    return MaterialApp.router(
      title: 'Nyaya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      routerConfig: ref.watch(routerProvider),
      // A build the server no longer allows sees only the update screen.
      // Text follows the phone's size setting up to 1.5x, the most the game layouts can hold.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxTextScale,
        child: update != null ? UpdateRequiredScreen(updateUrl: update.updateUrl) : child!,
      ),
    );
  }
}
