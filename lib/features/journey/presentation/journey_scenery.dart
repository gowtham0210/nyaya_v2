import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/journey.dart';
import 'journey_layout.dart';

/// One painted illustration at the edge of a chapter's stretch of road.
class _Prop {
  const _Prop(
    this.asset,
    this.fallback, {
    required this.landmark,
    this.widthFactor = 0.64,
    this.atBottom = false,
    this.opacity = 0.9,
  });

  final String asset;

  /// Faint icon shown until the painting is added to `assets/images/`.
  final IconData fallback;

  /// Landmarks sit at the top of the chapter on the chapter's "home" side;
  /// props sit near the chapter card on the other side.
  final bool landmark;
  final double widthFactor;
  final bool atBottom;

  /// Light-theme opacity; watermark-like props (the scales) sit further back.
  final double opacity;
}

/// Paintings per chapter id. Images are transparent watercolours, trimmed to
/// their content; prompts are in docs/JOURNEY_ART.md.
const _props = <String, List<_Prop>>{
  'constitution': [
    _Prop('assets/images/journey_constitution_landmark.webp', Icons.account_balance_rounded, landmark: true),
    _Prop(
      'assets/images/journey_constitution_prop.webp',
      Icons.menu_book_rounded,
      landmark: false,
      widthFactor: 0.5,
      atBottom: true,
    ),
    _Prop(
      'assets/images/journey_scales.webp',
      Icons.balance_rounded,
      landmark: true,
      widthFactor: 0.36,
      atBottom: true,
      opacity: 0.5,
    ),
  ],
  'rights': [
    _Prop('assets/images/journey_rights_landmark.webp', Icons.account_balance_rounded, landmark: true),
    _Prop(
      'assets/images/journey_rights_prop.webp',
      Icons.history_edu_rounded,
      landmark: false,
      widthFactor: 0.46,
      atBottom: true,
    ),
  ],
  'criminal': [
    _Prop('assets/images/journey_criminal_landmark.webp', Icons.location_city_rounded, landmark: true),
    _Prop(
      'assets/images/journey_criminal_prop.webp',
      Icons.gavel_rounded,
      landmark: false,
      widthFactor: 0.46,
      atBottom: true,
    ),
  ],
  'procedure': [
    _Prop('assets/images/journey_procedure_landmark.webp', Icons.account_balance_rounded, landmark: true),
    _Prop(
      'assets/images/journey_procedure_prop.webp',
      Icons.folder_copy_rounded,
      landmark: false,
      widthFactor: 0.46,
      atBottom: true,
    ),
  ],
  'civil': [
    _Prop('assets/images/journey_civil_landmark.webp', Icons.cottage_rounded, landmark: true),
    _Prop(
      'assets/images/journey_civil_prop.webp',
      Icons.history_edu_rounded,
      landmark: false,
      widthFactor: 0.46,
      atBottom: true,
    ),
  ],
  'everyday': [
    _Prop('assets/images/journey_everyday_landmark.webp', Icons.storefront_rounded, landmark: true),
    _Prop(
      'assets/images/journey_scales.webp',
      Icons.balance_rounded,
      landmark: false,
      widthFactor: 0.42,
      atBottom: true,
      opacity: 0.5,
    ),
  ],
};

/// Landmarks alternate sides chapter by chapter so the map doesn't lean.
bool _landmarkOnRight(int chapter) => chapter.isEven;

/// Where each painting goes.
typedef _Placement = ({_Prop prop, bool right, double? top, double? bottom, double width});

Iterable<_Placement> _placements(JourneyLayout layout) sync* {
  final w = layout.width;
  for (final (c, chapter) in JourneyCatalog.chapters.indexed) {
    final band = layout.chapterBands[c];
    for (final prop in _props[chapter.id] ?? const <_Prop>[]) {
      final right = prop.landmark == _landmarkOnRight(c);
      final size = w * prop.widthFactor;
      // Paintings keep their own aspect ratio: landmarks hang from the top of
      // the chapter, bottom props rest on (and overlap) the chapter card.
      if (prop.atBottom) {
        final base = layout.bannerTop(c) + _Gaps.bannerOverlap;
        yield (prop: prop, right: right, top: null, bottom: layout.height - base, width: size);
      } else {
        final top = band.top + _Gaps.landmarkInset;
        yield (prop: prop, right: right, top: top, bottom: null, width: size);
      }
    }
  }
}

/// Paintings behind the road, one set per chapter.
List<Widget> sceneryLayer(BuildContext context, JourneyLayout layout) => [
  for (final p in _placements(layout))
    Positioned(
      top: p.top,
      bottom: p.bottom,
      left: p.right ? null : -p.width * 0.08,
      right: p.right ? -p.width * 0.08 : null,
      width: p.width,
      child: IgnorePointer(
        child: _Painting(asset: p.prop.asset, fallback: p.prop.fallback, fadeRight: !p.right, opacity: p.prop.opacity),
      ),
    ),
];

/// Placement offsets for paintings and the note.
abstract final class _Gaps {
  static const bannerOverlap = 70.0;
  static const landmarkInset = 6.0;
  static const noteHeight = 84.0;
}

class _Painting extends StatelessWidget {
  const _Painting({required this.asset, required this.fallback, required this.fadeRight, required this.opacity});

  final String asset;
  final IconData fallback;

  /// Fade the edge facing the road (right edge for paintings on the left).
  final bool fadeRight;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      fit: BoxFit.fitWidth,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stack) => AspectRatio(
        aspectRatio: 1,
        child: Center(child: Icon(fallback, size: 72, color: context.colors.onSurface.withValues(alpha: 0.06))),
      ),
    );
    // Soften every edge so paintings melt into the background.
    final masked = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: fadeRight ? Alignment.centerLeft : Alignment.centerRight,
        end: fadeRight ? Alignment.centerRight : Alignment.centerLeft,
        colors: const [Colors.black, Colors.black, Colors.transparent],
        stops: const [0, 0.7, 1],
      ).createShader(bounds),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.12, 0.85, 1],
        ).createShader(bounds),
        child: image,
      ),
    );
    return Opacity(opacity: context.isDark ? opacity / 4 : opacity, child: masked);
  }
}

/// A handwritten "Keep going!" pointing at the current stop, placed only
/// where it fits without touching the road.
List<Widget> marginNotes(BuildContext context, JourneyLayout layout, JourneyNode? current) {
  final out = <Widget>[];

  if (current != null) {
    final at = layout.centers[current.globalIndex];
    final top = at.dy - 150;
    final bottom = top + _Gaps.noteHeight;
    final rightRoom = layout.freeWidth(left: false, top: top, bottom: bottom, margin: 12);
    final leftRoom = layout.freeWidth(left: true, top: top, bottom: bottom, margin: 12);
    final onRight = rightRoom >= leftRoom;
    final room = max(rightRoom, leftRoom);
    if (room >= 96) {
      final w = min(room, 140.0);
      final left = onRight ? layout.width - 12 - w : 12.0;
      out.add(
        Positioned.fromRect(
          rect: Rect.fromLTWH(left, top, w, _Gaps.noteHeight),
          child: IgnorePointer(child: _KeepGoing(pointLeft: onRight)),
        ),
      );
    }
  }

  return out;
}

class _KeepGoing extends StatelessWidget {
  const _KeepGoing({required this.pointLeft});

  /// The current stop is to the left of the note.
  final bool pointLeft;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary.withValues(alpha: 0.85);
    return Column(
      crossAxisAlignment: pointLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Transform.rotate(
          angle: -0.12,
          child: Text(
            context.l10n.journeyKeepGoing,
            maxLines: 1,
            style: AppTheme.handwriting(TextStyle(fontSize: 26, height: 1, color: color)),
          ),
        ),
        Expanded(
          child: Align(
            alignment: pointLeft ? const Alignment(0.2, 0) : const Alignment(-0.2, 0),
            child: CustomPaint(
              size: const Size(44, 44),
              painter: _ArrowPainter(color: color, pointLeft: pointLeft),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hand-drawn curved arrow sweeping down towards the current stop.
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color, required this.pointLeft});

  final Color color;
  final bool pointLeft;

  @override
  void paint(Canvas canvas, Size size) {
    if (pointLeft) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final tip = Offset(size.width * 0.85, size.height * 0.9);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.3, size.height * 0.05)
        ..quadraticBezierTo(size.width * 0.05, size.height * 0.7, tip.dx, tip.dy),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - 12, tip.dy - 9)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - 13, tip.dy + 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color || old.pointLeft != pointLeft;
}
