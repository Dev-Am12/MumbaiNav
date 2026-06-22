import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../theme/app_theme.dart';

IconData _iconFor(TransitMode mode) {
  switch (mode) {
    case TransitMode.train: return Icons.tram_rounded;
    case TransitMode.bus:   return Icons.directions_bus_filled_rounded;
    case TransitMode.bike:  return Icons.pedal_bike_rounded;
    case TransitMode.walk:  return Icons.directions_walk_rounded;
  }
}

Color _colorFor(TransitMode mode) {
  switch (mode) {
    case TransitMode.train: return AppColors.navy;
    case TransitMode.bus:   return AppColors.red;
    case TransitMode.bike:  return AppColors.amber;
    case TransitMode.walk:  return AppColors.textMuted;
  }
}

/// Multi-modal proof point: horizontal chain of mode chips connected
/// by lines showing exactly which service to take on each leg.
/// Every chip shows:
///   [route label]   ← e.g. "WR LOCAL", "BEST 318", "YULU"
///   [icon box]
///   [duration]      ← e.g. "17m"
class ModeChain extends StatelessWidget {
  final List<ModeSegment> segments;
  final bool large;

  const ModeChain({super.key, required this.segments, this.large = false});

  @override
  Widget build(BuildContext context) {
    final boxSize  = large ? 48.0 : 42.0;
    final iconSize = large ? 22.0 : 18.0;

    final children = <Widget>[];

    for (var i = 0; i < segments.length; i++) {
      final seg    = segments[i];
      final isWalk = seg.mode == TransitMode.walk;
      final color  = _colorFor(seg.mode);

      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Route label — always shown, gives commuter the key info
            SizedBox(
              width: boxSize + 8,
              child: Text(
                seg.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: isWalk ? AppColors.textMuted : color,
                ),
              ),
            ),
            const SizedBox(height: 3),

            // Icon box
            Container(
              width:  boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: isWalk
                    ? AppColors.background
                    : color.withOpacity(0.12),
                border: Border.all(
                  color: isWalk ? AppColors.border : color,
                  width: isWalk ? 1 : 1.8,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconFor(seg.mode), size: iconSize, color: isWalk ? AppColors.textMuted : color),
            ),
            const SizedBox(height: 4),

            // Duration
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

      // Connector line between chips
      if (i != segments.length - 1) {
        final nextIsWalk = segments[i + 1].mode == TransitMode.walk;
        children.add(
          Padding(
            // Offset downward to sit at icon-box mid-height (label + half box)
            padding: const EdgeInsets.only(bottom: 22, left: 2, right: 2),
            child: SizedBox(
              width: 18,
              child: nextIsWalk
                  ? CustomPaint(painter: _DashedLinePainter())
                  : const Divider(thickness: 1.4, color: AppColors.border),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
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
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}