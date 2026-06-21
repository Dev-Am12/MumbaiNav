import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../theme/app_theme.dart';

/// Teal-to-red gradient meter showing live crowd density for a route.
/// Always rendered — including on the recommended/top card, which was
/// the bug in the first mockup draft (it was missing there).
class CrowdDensityBar extends StatelessWidget {
  final double level; // 0.0 - 1.0
  final bool showLabel;

  const CrowdDensityBar({super.key, required this.level, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CROWD DENSITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  crowdLabel(level),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final markerX = (constraints.maxWidth * level).clamp(
              6.0,
              constraints.maxWidth - 6,
            );
            return SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.crowdLow,
                          AppColors.crowdMid,
                          AppColors.crowdHigh,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerX - 6,
                    top: -2,
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: AppColors.navy.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}