import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands an official address to the phone (its browser or PDF app). Behind an
/// interface so tests never reach a real phone or website. Nothing is
/// downloaded, saved or proxied by the app.
abstract interface class DocumentOpener {
  /// True when the phone took the address; false when it could not open it.
  Future<bool> open(Uri uri);
}

final documentOpenerProvider = Provider<DocumentOpener>((ref) => const UrlLauncherOpener());

class UrlLauncherOpener implements DocumentOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> open(Uri uri) async {
    // Only secure official links are ever handed on.
    if (!uri.isScheme('https') || uri.host.isEmpty) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
