import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'journey_layout.dart';

/// Draws the road: a wide soft track with a dashed centre line, like a
/// country lane on a painted map. Segments already travelled are tinted so
/// progress is visible at a glance.
class RoadPainter extends CustomPainter {
  RoadPainter({
    required this.layout,
    required this.completedUpTo,
    required this.roadColor,
    required this.edgeColor,
    required this.doneColor,
    required this.dashColor,
    this.shadowColor,
  });

  final JourneyLayout layout;

  /// Segments `i → i+1` with `i < completedUpTo` are done.
  final int completedUpTo;
  final Color roadColor;
  final Color edgeColor;
  final Color doneColor;
  final Color dashColor;

  /// A soft shadow under the whole road, so it sits on the scene (dark mode).
  final Color? shadowColor;

  Path _segment(int i) {
    final (a, b, c, d) = layout.segment(i);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(b.dx, b.dy, c.dx, c.dy, d.dx, d.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centers = layout.centers;
    if (centers.length < 2) return;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 52
      ..color = edgeColor;
    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 40;
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = dashColor;

    final segments = [for (var i = 0; i < centers.length - 1; i++) _segment(i)];
    if (shadowColor != null) {
      final shadow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 64
        ..color = shadowColor!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (final s in segments) {
        canvas.drawPath(s, shadow);
      }
    }
    for (final s in segments) {
      canvas.drawPath(s, edge);
    }
    for (var i = 0; i < segments.length; i++) {
      canvas.drawPath(segments[i], road..color = i < completedUpTo ? doneColor : roadColor);
    }
    for (final s in segments) {
      _drawDashed(canvas, s, dash);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 12.0;
      while (d < metric.length - 12) {
        canvas.drawPath(metric.extractPath(d, min(d + 10, metric.length)), paint);
        d += 22;
      }
    }
  }

  @override
  bool shouldRepaint(RoadPainter old) =>
      old.completedUpTo != completedUpTo ||
      old.roadColor != roadColor ||
      old.doneColor != doneColor ||
      old.shadowColor != shadowColor ||
      old.layout != layout;
}
