import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/server_progress.dart';

final progressApiProvider = Provider<ProgressApi>((ref) => HttpProgressApi(ref.watch(apiClientProvider)));

/// The learner's progress on the Nyaya API, which owns XP, streak, stars and chests.
abstract interface class ProgressApi {
  Future<ServerProgress> fetch();

  /// Opens a chapter chest (`constitution_chest`) once its levels are done.
  Future<ServerProgress> openChest(String chestId);
}

class HttpProgressApi implements ProgressApi {
  HttpProgressApi(this._client);

  final ApiClient _client;

  @override
  Future<ServerProgress> fetch() async =>
      ServerProgress.fromJson(await _client.get('/v1/me/progress') as Map<String, dynamic>);

  @override
  Future<ServerProgress> openChest(String chestId) async => ServerProgress.fromJson(
        await _client.post('/v1/me/chests/${Uri.encodeComponent(chestId)}/open') as Map<String, dynamic>,
      );
}
