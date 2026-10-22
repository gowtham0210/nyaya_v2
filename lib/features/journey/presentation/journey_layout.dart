import 'dart:math';
import 'dart:ui';

import '../domain/journey.dart';

/// Pure geometry for the winding road. Level 1 sits at the bottom (like
/// Candy Crush) and the road snakes upward chapter by chapter.
class JourneyLayout {
  JourneyLayout({required this.width, required List<JourneyNode> nodes}) {
    var d = bottomPad;
    var lastChapter = -1;
    for (final n in nodes) {
      if (n.chapterIndex != lastChapter) {
        bannerDistance[n.chapterIndex] = d + bannerHeight / 2;
        d += bannerHeight;
        lastChapter = n.chapterIndex;
      }
      d += spacing / 2;
      _distance.add(d);
      d += spacing / 2;
    }
    height = d + topPad;
    centers = [
      for (var i = 0; i < nodes.length; i++)
        Offset(width / 2 + sin(i * 0.95 + 0.3) * amplitude, height - _distance[i]),
    ];
    chapterBands = [
      for (var c = 0; c < bannerDistance.length; c++)
        (
          top: height - (c + 1 < bannerDistance.length ? bannerDistance[c + 1]! - bannerHeight / 2 : height),
          bottom: height - (bannerDistance[c]! - bannerHeight / 2) + (c == 0 ? bottomPad : 0),
        ),
    ];
  }

  static const spacing = 112.0;
  static const bannerHeight = 120.0;
  static const bottomPad = 40.0;
  static const topPad = 140.0;

  final double width;
  late final double height;
  late final List<Offset> centers;
  final Map<int, double> bannerDistance = {};
  final List<double> _distance = [];
  late final List<({double top, double bottom})> chapterBands;

  double get amplitude => min(width * 0.27, 120);

  double bannerTop(int chapter) => height - bannerDistance[chapter]! - bannerHeight / 2;

  /// Scroll offset (for a reversed scroll view) that centres node [i].
  double scrollOffsetFor(int i, double viewport) =>
      (_distance[i] - viewport / 2).clamp(0, max(0, height - viewport)).toDouble();
}
