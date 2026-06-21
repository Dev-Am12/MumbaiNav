import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../theme/app_theme.dart';
import 'crowd_density_bar.dart';
import 'mode_chain.dart';

/// The route result card. Used both on the Results screen and (in its
/// "live" variant) on the Live Update screen — same visual language,
/// so the route reads as continuous between the two screens.
class RouteCard extends StatelessWidget {
  final RouteOption route;
  final VoidCallback? onTap;
  final bool showLiveBadge;

  const RouteCard({
    super.key,
    required this.route,
    this.onTap,
    this.showLiveBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isRecommended = route.isRecommended;
    final borderColor = showLiveBadge
        ? AppColors.teal
        : (isRecommended ? AppColors.amber : AppColors.border);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isRecommended || showLiveBadge ? 2 : 1,
          ),
          boxShadow: isRecommended || showLiveBadge
              ? [
                  BoxShadow(
                    color: borderColor.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRecommended) _badge(),
            if (isRecommended) const SizedBox(height: 10),

            // ETA row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${route.etaMinutes}',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 3, bottom: 5),
                  child: Text(
                    'min',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Arrival ${route.arrivalTime}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (route.etaChangeNote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              (route.etaDeltaMinutes ?? 0) < 0
                                  ? Icons.trending_down_rounded
                                  : Icons.trending_up_rounded,
                              size: 14,
                              color: AppColors.teal,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              route.etaChangeNote!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.teal,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        route.fare,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            ModeChain(segments: route.segments, large: isRecommended),
            const SizedBox(height: 16),

            CrowdDensityBar(level: route.crowdLevel),

            if (route.aiReasoning != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 16, color: AppColors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        route.aiReasoning!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.navy),
          SizedBox(width: 5),
          Text(
            'AI RECOMMENDED',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}