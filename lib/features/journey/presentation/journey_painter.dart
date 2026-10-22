import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// Draws the road: a thick rounded track with a dashed centre line. Segments
/// already travelled are painted gold so progress is visible at a glance.
class RoadPainter extends CustomPainter {
  RoadPainter({
    required this.centers,
    required this.completedUpTo,
    required this.roadColor,
    required this.edgeColor,
    required this.doneColor,
  });

  final List<Offset> centers;

  /// Segments `i → i+1` with `i < completedUpTo` are done.
  final int completedUpTo;
  final Color roadColor;
  final Color edgeColor;
  final Color doneColor;

  Path _segment(int i) {
    final p0 = centers[max(0, i - 1)];
    final p1 = centers[i];
    final p2 = centers[i + 1];
    final p3 = centers[min(centers.length - 1, i + 2)];
    // Catmull-Rom → cubic Bézier for a smooth snake.
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 34
      ..color = edgeColor;
    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 24;
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final segments = [for (var i = 0; i < centers.length - 1; i++) _segment(i)];
    for (final s in segments) {
      canvas.drawPath(s, edge);
    }
    for (var i = 0; i < segments.length; i++) {
      final done = i < completedUpTo;
      canvas.drawPath(segments[i], road..color = done ? doneColor : roadColor);
      dash.color = done ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.55);
      _drawDashed(canvas, segments[i], dash);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 10.0;
      while (d < metric.length - 10) {
        canvas.drawPath(metric.extractPath(d, min(d + 8, metric.length)), paint);
        d += 18;
      }
    }
  }

  @override
  bool shouldRepaint(RoadPainter old) =>
      old.completedUpTo != completedUpTo || old.roadColor != roadColor || old.centers != centers;
}

/// Faint themed doodles scattered on the map background.
class MapDecorations extends StatelessWidget {
  const MapDecorations({super.key, required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  static const _icons = [
    Icons.balance_rounded,
    Icons.menu_book_rounded,
    Icons.gavel_rounded,
    Icons.account_balance_rounded,
    Icons.history_edu_rounded,
    Icons.verified_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final rng = Random(7);
    final count = (height / 90).round();
    return Stack(
      children: [
        for (var i = 0; i < count; i++)
          () {
            final left = rng.nextBool();
            final x = left ? rng.nextDouble() * width * 0.16 : width * 0.82 + rng.nextDouble() * width * 0.12;
            return Positioned(
              left: x,
              top: rng.nextDouble() * height,
              child: Transform.rotate(
                angle: (rng.nextDouble() - 0.5) * 0.8,
                child: Icon(_icons[rng.nextInt(_icons.length)], size: 22 + rng.nextDouble() * 16, color: color),
              ),
            );
          }(),
      ],
    );
  }
}
