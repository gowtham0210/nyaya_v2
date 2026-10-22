import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/l10n.dart';
import '../core/theme/app_theme.dart';
import '../features/profile/application/profile_controller.dart';
import 'router.dart';

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
    // Energy reset, streak check and league close happen on every resume.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(profileProvider.notifier).refreshDay(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    );
  }
}
