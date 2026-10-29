import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/server_progress.dart';

final progressApiProvider = Provider<ProgressApi>((ref) => HttpProgressApi(ref.watch(apiClientProvider)));

/// The learner's progress on the Nyaya API, which owns XP, streak, stars and chests.
abstract interface class ProgressApi {
  Future<ServerProgress> fetch();

  /// Opens a chapter chest (`constitution_chest`) once its levels are done.
  Future<ServerProgress> openChest(String chestId);

  /// Spends 30 coins on 1 energy for today.
  Future<ServerProgress> refillEnergy();

  /// Spends 100 coins on a streak freeze (at most 2 held).
  Future<ServerProgress> buyStreakFreeze();

  /// Demo premium, until store purchases are checked by the server.
  Future<ServerProgress> setPremium(bool on);

  Future<void> saveSettings(ServerSettings settings);
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

  @override
  Future<ServerProgress> refillEnergy() async =>
      ServerProgress.fromJson(await _client.post('/v1/me/energy/refill') as Map<String, dynamic>);

  @override
  Future<ServerProgress> buyStreakFreeze() async =>
      ServerProgress.fromJson(await _client.post('/v1/me/streak-freezes') as Map<String, dynamic>);

  @override
  Future<ServerProgress> setPremium(bool on) async => ServerProgress.fromJson(
        (on ? await _client.post('/v1/me/premium') : await _client.delete('/v1/me/premium')) as Map<String, dynamic>,
      );

  @override
  Future<void> saveSettings(ServerSettings settings) => _client.put('/v1/me/settings', body: settings.toJson());
}
