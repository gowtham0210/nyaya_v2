import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/app_config_api.dart';
import '../domain/app_version.dart';

/// The version this build was released as (from the app bundle). Null when
/// unknown, as in tests; the check then does nothing.
final appVersionProvider = Provider<String?>((ref) => null);

/// Set when the server says this build is too old to keep using.
class UpdateRequired {
  const UpdateRequired({this.updateUrl});

  final String? updateUrl;
}

final updateCheckProvider = NotifierProvider<UpdateCheck, UpdateRequired?>(UpdateCheck.new);

/// Asks the server which versions are still allowed, at start and on resume.
/// Offline or any error leaves things as they were: a bad connection never
/// locks anyone out.
class UpdateCheck extends Notifier<UpdateRequired?> {
  @override
  UpdateRequired? build() => null;

  Future<void> check() async {
    final installed = ref.read(appVersionProvider);
    if (installed == null) return;
    try {
      final settings = await ref.read(appConfigApiProvider).fetch();
      if (!ref.mounted) return;
      final min = settings.minVersion;
      state = min != null && isOlderThan(installed, min) ? UpdateRequired(updateUrl: settings.updateUrl) : null;
    } on ApiException {
      // Keep the last answer.
    } on TypeError {
      // A reply this build can't read.
    }
  }
}
