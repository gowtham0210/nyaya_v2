import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';


enum LawArt { court, scales, people }

/// Flat, gradient-free illustrations for the Explore Law cards, painted in
/// palette tones so they sit on the sand hero card in light and dark themes.
class LawIllustration extends StatelessWidget {
  const LawIllustration({super.key, required this.art});

  final LawArt art;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: switch (art) {
          LawArt.court => _CourtPainter(),
          LawArt.scales => _ScalesPainter(),
          LawArt.people => _PeoplePainter(),
        },
        size: Size.infinite,
      );
}

const _stone = Color(0xFFF3E4D0);
const _stoneShade = Color(0xFFE2C9AA);
const _wall = Color(0xFFA2553C);
const _wallDark = Color(0xFF7E3F2B);
const _window = Color(0xFF4A2A1E);
const _leaf = Color(0xFF5E6B3A);
const _leafLight = Color(0xFF7A8A4E);

Paint _fill(Color c) => Paint()..color = c;

void _tree(Canvas canvas, Offset base, double r) {
  canvas.drawRect(Rect.fromCenter(center: base.translate(0, -r * 0.5), width: r * 0.22, height: r), _fill(_wallDark));
  canvas.drawCircle(base.translate(-r * 0.45, -r * 1.05), r * 0.6, _fill(_leaf));
  canvas.drawCircle(base.translate(r * 0.45, -r * 1.0), r * 0.62, _fill(_leaf));
  canvas.drawCircle(base.translate(0, -r * 1.55), r * 0.7, _fill(_leafLight));
}

/// Supreme Court of India: dome, drum, colonnaded facade, wings and trees.
class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.56;
    final ground = h * 0.94;

    // Side wings.
    final wingTop = h * 0.62;
    canvas.drawRect(Rect.fromLTRB(w * 0.06, wingTop, w * 0.98, ground), _fill(_wall));
    canvas.drawRect(Rect.fromLTRB(w * 0.06, wingTop - h * 0.025, w * 0.98, wingTop), _fill(_stone));
    for (var i = 0; i < 9; i++) {
      final x = w * 0.1 + i * w * 0.1;
      if ((x - cx).abs() < w * 0.24) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, wingTop + h * 0.05, w * 0.035, h * 0.09), const Radius.circular(3)),
        _fill(_window),
      );
    }

    // Central block with colonnade.
    final blockTop = h * 0.46;
    final blockL = cx - w * 0.24;
    final blockR = cx + w * 0.24;
    canvas.drawRect(Rect.fromLTRB(blockL, blockTop, blockR, ground), _fill(_wall));
    canvas.drawRect(Rect.fromLTRB(blockL - w * 0.02, blockTop - h * 0.03, blockR + w * 0.02, blockTop), _fill(_stone));
    canvas.drawRect(Rect.fromLTRB(blockL, blockTop + h * 0.03, blockR, blockTop + h * 0.05), _fill(_stoneShade));
    const cols = 7;
    final colW = (blockR - blockL) / (cols * 2 - 1);
    for (var i = 0; i < cols; i++) {
      final x = blockL + i * colW * 2;
      canvas.drawRect(Rect.fromLTWH(x, blockTop + h * 0.07, colW, ground - blockTop - h * 0.1), _fill(_stone));
    }
    for (var i = 0; i < cols - 1; i++) {
      final x = blockL + colW + i * colW * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + colW * 0.15, blockTop + h * 0.1, colW * 0.7, h * 0.14),
          Radius.circular(colW),
        ),
        _fill(_window),
      );
    }

    // Steps.
    canvas.drawRect(Rect.fromLTRB(blockL - w * 0.04, ground - h * 0.035, blockR + w * 0.04, ground), _fill(_stone));

    // Drum.
    final drumTop = h * 0.33;
    final drumW = w * 0.34;
    canvas.drawRect(Rect.fromLTWH(cx - drumW / 2, drumTop, drumW, blockTop - drumTop - h * 0.03), _fill(_stone));
    for (var i = 0; i < 5; i++) {
      final x = cx - drumW / 2 + drumW * (0.1 + i * 0.18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, drumTop + h * 0.025, drumW * 0.08, h * 0.06), const Radius.circular(2)),
        _fill(_wallDark),
      );
    }

    // Dome with ribs.
    final domeR = drumW * 0.48;
    final dome = Rect.fromCircle(center: Offset(cx, drumTop), radius: domeR);
    canvas.drawArc(dome, math.pi, math.pi, true, _fill(_stone));
    final rib = Paint()
      ..color = _stoneShade
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final t in [-0.55, 0.0, 0.55]) {
      canvas.drawLine(Offset(cx + t * domeR, drumTop - math.sqrt(1 - t * t) * domeR * 0.98), Offset(cx + t * domeR * 1.1, drumTop), rib);
    }
    canvas.drawRect(Rect.fromLTWH(cx - domeR * 1.05, drumTop - h * 0.012, domeR * 2.1, h * 0.02), _fill(_stoneShade));

    // Lantern and finial.
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, drumTop - domeR - h * 0.02), width: w * 0.05, height: h * 0.05), _fill(_stone));
    canvas.drawCircle(Offset(cx, drumTop - domeR - h * 0.055), w * 0.018, _fill(_wallDark));

    // Trees framing the building.
    _tree(canvas, Offset(w * 0.08, ground), w * 0.11);
    _tree(canvas, Offset(w * 0.2, ground), w * 0.08);
    _tree(canvas, Offset(w * 0.95, ground), w * 0.1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Scales of justice on a stack of law books.
class _ScalesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.55;
    final stroke = Paint()
      ..color = _wallDark
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Books stacked as the plinth.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.18, h * 0.82, w * 0.92, h * 0.94), const Radius.circular(4)), _fill(_wall));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.24, h * 0.72, w * 0.86, h * 0.82), const Radius.circular(4)), _fill(_stoneShade));
    canvas.drawRect(Rect.fromLTRB(w * 0.24, h * 0.765, w * 0.86, h * 0.775), _fill(_wallDark));

    // Pillar and beam.
    canvas.drawLine(Offset(cx, h * 0.72), Offset(cx, h * 0.18), stroke);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, h * 0.7), width: w * 0.2, height: h * 0.03), _fill(_wallDark));
    canvas.drawLine(Offset(cx - w * 0.3, h * 0.26), Offset(cx + w * 0.3, h * 0.22), stroke);
    canvas.drawCircle(Offset(cx, h * 0.17), w * 0.03, _fill(_wallDark));

    // Pans hanging on cords.
    final cord = Paint()
      ..color = _wallDark
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final (x, top, drop) in [(cx - w * 0.3, h * 0.26, h * 0.3), (cx + w * 0.3, h * 0.22, h * 0.26)]) {
      final panY = top + drop;
      canvas.drawLine(Offset(x, top), Offset(x - w * 0.1, panY), cord);
      canvas.drawLine(Offset(x, top), Offset(x + w * 0.1, panY), cord);
      canvas.drawArc(Rect.fromCenter(center: Offset(x, panY), width: w * 0.24, height: h * 0.12), 0, math.pi, true, _fill(_wall));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A street of people for "Everyday Law".
class _PeoplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.94;

    // Buildings.
    for (final (l, t, r, c) in [
      (0.05, 0.3, 0.32, _stoneShade),
      (0.34, 0.18, 0.62, _wall),
      (0.64, 0.36, 0.95, _stoneShade),
    ]) {
      canvas.drawRect(Rect.fromLTRB(w * l, h * t, w * r, ground), _fill(c));
      for (var y = h * t + h * 0.06; y < ground - h * 0.12; y += h * 0.12) {
        for (var x = w * l + w * 0.04; x < w * r - w * 0.05; x += w * 0.08) {
          canvas.drawRect(Rect.fromLTWH(x, y, w * 0.035, h * 0.06), _fill(c == _wall ? _stone : _wallDark.withValues(alpha: 0.5)));
        }
      }
    }

    // People.
    void person(double x, double s, Color c) {
      canvas.drawCircle(Offset(x, ground - s * 1.05), s * 0.16, _fill(c));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, ground - s * 0.55), width: s * 0.38, height: s * 0.62), Radius.circular(s * 0.12)),
        _fill(c),
      );
      canvas.drawRect(Rect.fromLTWH(x - s * 0.15, ground - s * 0.28, s * 0.1, s * 0.28), _fill(c));
      canvas.drawRect(Rect.fromLTWH(x + s * 0.05, ground - s * 0.28, s * 0.1, s * 0.28), _fill(c));
    }

    person(w * 0.36, h * 0.3, _window);
    person(w * 0.5, h * 0.34, _wallDark);
    person(w * 0.63, h * 0.28, _window);
    _tree(canvas, Offset(w * 0.9, ground), w * 0.09);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
