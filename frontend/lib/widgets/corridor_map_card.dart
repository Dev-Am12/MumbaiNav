import 'package:flutter/material.dart';
import '../data/corridor_data_model.dart';
import '../theme/app_theme.dart';

const double _marginX = 34;
const double _marginTop = 40;
const double _marginBottom = 34;

Offset _pt(Offset frac, Size size) {
  final w = size.width - _marginX * 2;
  final h = size.height - _marginTop - _marginBottom;
  return Offset(_marginX + frac.dx * w, _marginTop + frac.dy * h);
}

/// Draws a smooth curve through an arbitrary list of points (Catmull-Rom
/// converted to cubic beziers). This is what makes the corridor card
/// data-driven: it has no idea how many stations there are or what
/// they're called — feed it 3 points or 6, it produces a smooth route
/// line either way. Adding a new corridor never requires touching this.
Path _smoothPath(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 1) return path;

  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = i == 0 ? pts[i] : pts[i - 1];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = (i + 2 < pts.length) ? pts[i + 2] : p2;

    final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
    final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);

    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// Decorative corridor illustration, driven entirely by a [CorridorData]
/// value — see lib/data/corridor_presets.dart. To support a new corridor,
/// add a new CorridorData constant there; this widget/painter never
/// changes.
class CorridorMapCard extends StatelessWidget {
  final CorridorData data;

  const CorridorMapCard({super.key, required this.data});

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
                    child: CustomPaint(painter: _CorridorPainter(data: data, size: size)),
                  ),
                  Positioned(
                    top: 12,
                    right: 14,
                    child: Row(
                      children: [
                        const Icon(Icons.explore_outlined, size: 16, color: AppColors.navy),
                        const SizedBox(width: 4),
                        Text(
                          data.label,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...data.stations.map((s) {
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
  final CorridorData data;
  final Size size;
  const _CorridorPainter({required this.data, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    canvas.drawRect(Offset.zero & canvasSize, Paint()..color = AppColors.background);

    for (final routePath in data.paths) {
      final points = routePath.stationOrder
          .map((name) => _pt(data.positionOf(name), canvasSize))
          .toList();

      final paint = Paint()
        ..color = routePath.color
        ..strokeWidth = routePath.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(_smoothPath(points), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CorridorPainter oldDelegate) =>
      oldDelegate.data.id != data.id || oldDelegate.size != size;
}