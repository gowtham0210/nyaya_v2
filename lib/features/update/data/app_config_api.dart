import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

final appConfigApiProvider = Provider<AppConfigApi>((ref) => HttpAppConfigApi(ref.watch(apiClientProvider)));

/// What the server says about which app versions may still be used.
class AppSettings {
  const AppSettings({this.minVersion, this.updateUrl});

  final String? minVersion;
  final String? updateUrl;
}

abstract interface class AppConfigApi {
  Future<AppSettings> fetch();
}

class HttpAppConfigApi implements AppConfigApi {
  HttpAppConfigApi(this._client);

  final ApiClient _client;

  @override
  Future<AppSettings> fetch() async {
    final j = await _client.get('/v1/app-config', auth: false) as Map<String, dynamic>;
    return AppSettings(minVersion: j['min_app_version'] as String?, updateUrl: j['update_url'] as String?);
  }
}
