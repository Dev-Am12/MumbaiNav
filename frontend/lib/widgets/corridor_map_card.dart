import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _Station {
  final String name;
  final Offset pos; // fractional 0-1, mapped into a margined drawable area
  const _Station(this.name, this.pos);
}

const _stations = [
  _Station('ANDHERI', Offset(0.04, 0.38)),
  _Station('BANDRA', Offset(0.34, 0.92)),
  _Station('KURLA', Offset(0.66, 0.30)),
  _Station('BKC', Offset(0.97, 0.04)),
];

// Margins keep every line/label safely inside the card — nothing should
// ever touch or clip past the rounded border.
const double _marginX = 34;
const double _marginTop = 40;
const double _marginBottom = 34;

Offset _pt(Offset frac, Size size) {
  final w = size.width - _marginX * 2;
  final h = size.height - _marginTop - _marginBottom;
  return Offset(_marginX + frac.dx * w, _marginTop + frac.dy * h);
}

/// Decorative corridor illustration for the Home screen — the two
/// real paths (Andheri-Bandra-BKC and Andheri-Kurla-BKC) only.
/// No other stations, no city-wide map — intentionally scoped to the
/// locked demo corridor.
class CorridorMapCard extends StatelessWidget {
  const CorridorMapCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 11,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _CorridorPainter(size: size)),
                  ),
                  Positioned(
                    top: 12,
                    right: 14,
                    child: Row(
                      children: const [
                        Icon(Icons.explore_outlined, size: 16, color: AppColors.navy),
                        SizedBox(width: 4),
                        Text(
                          'MUMBAI TRANSIT CORRIDOR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Labels are drawn last, on an opaque pill, so a line
                  // crossing behind them never cuts through the text.
                  ..._stations.map((s) {
                    final pos = _pt(s.pos, size);
                    return Positioned(
                      left: pos.dx - 30,
                      top: pos.dy - 9,
                      child: Column(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.amber, width: 2.5),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CorridorPainter extends CustomPainter {
  final Size size;
  const _CorridorPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    canvas.drawRect(Offset.zero & canvasSize, Paint()..color = AppColors.background);

    final andheri = _pt(_stations[0].pos, canvasSize);
    final bandra = _pt(_stations[1].pos, canvasSize);
    final kurla = _pt(_stations[2].pos, canvasSize);
    final bkc = _pt(_stations[3].pos, canvasSize);

    final railPaint = Paint()
      ..color = AppColors.navy
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final roadPaint = Paint()
      ..color = AppColors.amber
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Fan the two lines slightly apart right at Andheri so they don't
    // sit exactly on top of each other / the label.
    final railStart = andheri.translate(2, 6);
    final roadStart = andheri.translate(2, -6);

    // via Bandra — smooth wide cubic, no sharp V. Control points pulled
    // far out horizontally so the dip reads as a gentle curve.
    final viaBandra = Path()..moveTo(railStart.dx, railStart.dy);
    viaBandra.cubicTo(
      railStart.dx + (bandra.dx - railStart.dx) * 0.25,
      railStart.dy + (bandra.dy - railStart.dy) * 0.85,
      bandra.dx - (bandra.dx - railStart.dx) * 0.55,
      bandra.dy,
      bandra.dx,
      bandra.dy,
    );
    viaBandra.cubicTo(
      bandra.dx + (bkc.dx - bandra.dx) * 0.3,
      bandra.dy - (bandra.dy - kurla.dy) * 0.5,
      bkc.dx - (bkc.dx - bandra.dx) * 0.25,
      bkc.dy + (bkc.dy - kurla.dy).abs() * 0.4 + 30,
      bkc.dx,
      bkc.dy,
    );
    canvas.drawPath(viaBandra, railPaint);

    // via Kurla — gentle arc above the via-Bandra line, well clear of
    // the Kurla label.
    final viaKurla = Path()..moveTo(roadStart.dx, roadStart.dy);
    viaKurla.cubicTo(
      roadStart.dx + (kurla.dx - roadStart.dx) * 0.4,
      roadStart.dy - 4,
      kurla.dx - (kurla.dx - roadStart.dx) * 0.3,
      kurla.dy + 14,
      kurla.dx,
      kurla.dy,
    );
    viaKurla.cubicTo(
      kurla.dx + (bkc.dx - kurla.dx) * 0.35,
      kurla.dy - 6,
      bkc.dx - (bkc.dx - kurla.dx) * 0.25,
      bkc.dy + 20,
      bkc.dx,
      bkc.dy,
    );
    canvas.drawPath(viaKurla, roadPaint);
  }

  @override
  bool shouldRepaint(covariant _CorridorPainter oldDelegate) => oldDelegate.size != size;
}