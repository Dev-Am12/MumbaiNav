import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../theme/app_theme.dart';

IconData _iconFor(TransitMode mode) {
  switch (mode) {
    case TransitMode.train:
      return Icons.tram_rounded;
    case TransitMode.bus:
      return Icons.directions_bus_filled_rounded;
    case TransitMode.bike:
      return Icons.pedal_bike_rounded;
    case TransitMode.walk:
      return Icons.directions_walk_rounded;
  }
}

Color _colorFor(TransitMode mode) {
  switch (mode) {
    case TransitMode.train:
      return AppColors.navy;
    case TransitMode.bus:
      return AppColors.red;
    case TransitMode.bike:
      return AppColors.amber;
    case TransitMode.walk:
      return AppColors.textMuted;
  }
}

/// Renders the multi-modal proof point: a horizontal chain of mode icons
/// connected by lines, e.g. [train] — [bus] - - [walk].
/// This is deliberately sized as a primary element, not a small footnote —
/// it's the visual evidence that one computation spans multiple modes.
class ModeChain extends StatelessWidget {
  final List<ModeSegment> segments;
  final bool large;

  const ModeChain({super.key, required this.segments, this.large = false});

  @override
  Widget build(BuildContext context) {
    final boxSize = large ? 48.0 : 40.0;
    final iconSize = large ? 24.0 : 20.0;

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isWalk = seg.mode == TransitMode.walk;

      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: isWalk
                    ? AppColors.background
                    : _colorFor(seg.mode).withOpacity(0.12),
                border: Border.all(
                  color: isWalk ? AppColors.border : _colorFor(seg.mode),
                  width: isWalk ? 1 : 1.6,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconFor(seg.mode),
                size: iconSize,
                color: isWalk ? AppColors.textMuted : _colorFor(seg.mode),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              seg.duration,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );

      if (i != segments.length - 1) {
        final nextIsWalk = segments[i + 1].mode == TransitMode.walk;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: SizedBox(
              width: 20,
              child: nextIsWalk
                  ? CustomPaint(painter: _DashedLinePainter())
                  : const Divider(thickness: 1.4, color: AppColors.border),
            ),
          ),
        );
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.4;
    const dashWidth = 3.0;
    const dashSpace = 3.0;
    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}