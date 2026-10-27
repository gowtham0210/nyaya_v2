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
      for (var i = 0; i < nodes.length; i++) Offset(width / 2 + sin(i * 0.95 + 0.3) * amplitude, height - _distance[i]),
    ];
    chapterBands = [
      for (var c = 0; c < bannerDistance.length; c++)
        (
          top: height - (c + 1 < bannerDistance.length ? bannerDistance[c + 1]! - bannerHeight / 2 : height),
          bottom: height - (bannerDistance[c]! - bannerHeight / 2) + (c == 0 ? bottomPad : 0),
        ),
    ];
    roadSamples = [
      for (var i = 0; i < centers.length - 1; i++)
        for (var t = 0.0; t < 1; t += 0.1) _segmentPoint(i, t),
      if (centers.isNotEmpty) centers.last,
    ];
  }

  static const spacing = 96.0;
  static const bannerHeight = 128.0;
  static const bottomPad = 84.0;
  static const topPad = 150.0;

  /// Distance from the road's centre line that decorations must keep clear
  /// of (half the road plus a level bubble).
  static const roadClearance = 52.0;

  final double width;
  late final double height;
  late final List<Offset> centers;
  final Map<int, double> bannerDistance = {};
  final List<double> _distance = [];
  late final List<({double top, double bottom})> chapterBands;

  /// Points along the road's centre line, used to find free space beside it.
  late final List<Offset> roadSamples;

  double get amplitude => min(width * 0.27, 120);

  double bannerTop(int chapter) => height - bannerDistance[chapter]! - bannerHeight / 2;

  /// Catmull-Rom control points for the segment `i → i+1`, shared with the
  /// road painter so decorations and the drawn road agree.
  (Offset, Offset, Offset, Offset) segment(int i) {
    final p0 = centers[max(0, i - 1)];
    final p1 = centers[i];
    final p2 = centers[i + 1];
    final p3 = centers[min(centers.length - 1, i + 2)];
    return (p1, p1 + (p2 - p0) / 6, p2 - (p3 - p1) / 6, p2);
  }

  Offset _segmentPoint(int i, double t) {
    final (a, b, c, d) = segment(i);
    final u = 1 - t;
    return a * (u * u * u) + b * (3 * u * u * t) + c * (3 * u * t * t) + d * (t * t * t);
  }

  /// Horizontal room between the road and the screen edge on one side for
  /// the vertical span `top..bottom`, keeping [roadClearance] and [margin].
  double freeWidth({required bool left, required double top, required double bottom, double margin = 20}) {
    var edge = left ? width : 0.0;
    for (final p in roadSamples) {
      if (p.dy < top - roadClearance || p.dy > bottom + roadClearance) continue;
      edge = left ? min(edge, p.dx) : max(edge, p.dx);
    }
    final room = left ? edge - roadClearance - margin : width - edge - roadClearance - margin;
    return max(0, room);
  }

  /// Scroll offset (for a reversed scroll view) that centres node [i].
  double scrollOffsetFor(int i, double viewport) =>
      (_distance[i] - viewport / 2).clamp(0, max(0, height - viewport)).toDouble();
}
