import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/api/token_store.dart';
import 'core/monitoring/monitoring.dart';
import 'core/storage/local_store.dart';
import 'features/update/application/update_check.dart';

Future<void> main() => Monitoring.run(_start);

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final tokens = await SecureTokenStore.load();
  final version = (await PackageInfo.fromPlatform()).version;
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        appVersionProvider.overrideWithValue(version),
      ],
      child: const NyayaApp(),
    ),
  );
}
