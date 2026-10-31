import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/application/profile_controller.dart';

/// The app's sound effects (`assets/sounds/`, from Envato Elements; trimmed
/// and levelled so a wrong answer is never louder than a right one).
enum Sfx {
  correct('correct'),
  wrong('wrong'),
  levelComplete('level_complete'),
  chest('chest'),
  streak('streak'),
  duelWon('duel_won'),
  duelLost('duel_lost'),
  tick('tick');

  const Sfx(this.file);

  final String file;

  /// Path under `assets/`, as audioplayers expects.
  String get asset => 'sounds/$file.mp3';
}

/// Plays sound effects. Tests override it with a fake.
final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final player = AudioSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Sound effects that respect the user's setting.
final soundsProvider = Provider<SoundService>((ref) => SoundService(ref));

class SoundService {
  SoundService(this._ref);

  final Ref _ref;

  void play(Sfx sound) {
    if (!_ref.read(profileProvider).soundOn) return;
    _ref.read(soundPlayerProvider).play(sound);
  }

  /// Loads the sounds ahead of time so the first one plays without delay.
  void warmUp() {
    if (!_ref.read(profileProvider).soundOn) return;
    _ref.read(soundPlayerProvider).warmUp();
  }
}

abstract interface class SoundPlayer {
  void play(Sfx sound);
  void warmUp();
}

class AudioSoundPlayer implements SoundPlayer {
  /// Ambient on iPhone: quiet with the silent switch, and other apps' music
  /// keeps playing. On Android: game sounds that don't take audio focus.
  static final _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  final _pools = <Sfx, Future<AudioPool>>{};

  @override
  void play(Sfx sound) => unawaited(_play(sound));

  @override
  void warmUp() {
    for (final s in Sfx.values) {
      unawaited(_pool(s).then((_) {}, onError: (_) {}));
    }
  }

  Future<void> _play(Sfx sound) async {
    try {
      await (await _pool(sound)).start();
    } catch (_) {
      // A sound that can't play is not worth interrupting the quiz for.
    }
  }

  Future<AudioPool> _pool(Sfx sound) => _pools[sound] ??= AudioPool.create(
        source: AssetSource(sound.asset),
        audioContext: _context,
        // Two at once, e.g. the last tick and the time's-up sound.
        maxPlayers: 2,
      )..then((_) {}, onError: (_) {
          // A failed load isn't kept: the next play tries again.
          _pools.remove(sound);
        });

  void dispose() {
    for (final pool in _pools.values) {
      unawaited(pool.then((p) => p.dispose(), onError: (_) {}));
    }
  }
}
