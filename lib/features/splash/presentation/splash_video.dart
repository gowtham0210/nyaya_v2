import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// Whether the opening video plays. Off by default so tests never touch the
/// video plugin; `main.dart` turns it on for the real app.
final splashEnabledProvider = Provider<bool>((ref) => false);

/// The cream of the video's background. The native launch screens use the same
/// colour, so the handoff from the OS splash to the video has no visible seam.
const splashBackground = Color(0xFFF9F0E2);

const _asset = 'assets/video/splash.mp4';

/// Plays the Nyaya Kural opening animation once, over the app, then fades out.
///
/// It never blocks the app: a tap skips it, a video that fails or is slow to
/// load is skipped, and phones set to reduce motion skip it entirely.
class SplashVideo extends StatefulWidget {
  const SplashVideo({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashVideo> createState() => _SplashVideoState();
}

class _SplashVideoState extends State<SplashVideo> {
  static const _loadLimit = Duration(seconds: 4);
  static const _totalLimit = Duration(seconds: 8);
  static const _holdLastFrame = Duration(milliseconds: 350);
  static const _fade = Duration(milliseconds: 300);

  VideoPlayerController? _video;
  Timer? _limit;
  bool _ready = false;
  bool _leaving = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_video != null || _leaving) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _finish();
      return;
    }
    _start();
  }

  Future<void> _start() async {
    final video = VideoPlayerController.asset(
      _asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = video;
    _limit = Timer(_loadLimit, () {
      if (!_ready) _leave();
    });
    try {
      await video.initialize();
      if (!mounted || _leaving) return;
      await video.setVolume(0);
      video.addListener(_onTick);
      await video.play();
      if (!mounted || _leaving) return;
      _limit?.cancel();
      _limit = Timer(_totalLimit, _leave);
      setState(() => _ready = true);
    } catch (_) {
      _leave();
    }
  }

  void _onTick() {
    final value = _video?.value;
    if (value == null || _leaving) return;
    if (value.hasError) {
      _leave();
    } else if (value.isCompleted ||
        (value.duration > Duration.zero && value.position >= value.duration)) {
      Future.delayed(_holdLastFrame, _leave);
    }
  }

  /// Fades the splash out, then tells the app it is gone.
  void _leave() {
    if (_leaving || !mounted) return;
    setState(() => _leaving = true);
    Future.delayed(_fade, _finish);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _leaving = true;
    _limit?.cancel();
    // Called during didChangeDependencies too, so wait for the frame to end.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
  }

  @override
  void dispose() {
    _limit?.cancel();
    _video?.removeListener(_onTick);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Semantics(
      label: 'Nyaya Kural',
      button: true,
      hint: 'Tap to skip',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: AnimatedOpacity(
          opacity: _leaving ? 0 : 1,
          duration: _fade,
          child: ColoredBox(
            color: splashBackground,
            child: SizedBox.expand(
              child: _ready && video != null
                  // Fills the screen so the player's slightly different cream never
                  // meets the background at a visible edge. Phones taller than 9:16
                  // lose a little from the sides; the logo sits well inside that.
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: video.value.size.width,
                        height: video.value.size.height,
                        child: VideoPlayer(video),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
