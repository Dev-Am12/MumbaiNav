import 'dart:async';

import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/route_card.dart';

class LiveUpdateScreen extends StatefulWidget {
  final RouteOption originalRoute;
  final String origin;
  final String destination;

  const LiveUpdateScreen({
    super.key,
    required this.originalRoute,
    required this.origin,
    required this.destination,
  });

  @override
  State<LiveUpdateScreen> createState() => _LiveUpdateScreenState();
}

class _LiveUpdateScreenState extends State<LiveUpdateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  StreamSubscription<LiveConditionsUpdate>? _liveSub;

  late RouteOption _displayRoute;
  bool _isLive          = false;
  bool _isRecalculating = false;

  @override
  void initState() {
    super.initState();
    _displayRoute = widget.originalRoute;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _liveSub = RouteService.liveConditionsStream().listen(_onLiveUpdate);
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    RouteService.disconnectLiveConditions();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onLiveUpdate(LiveConditionsUpdate _) async {
    if (!mounted) return;
    setState(() => _isRecalculating = true);

    final fresh = await RouteService.fetchRoutes(
      origin: widget.origin,
      destination: widget.destination,
    );
    if (!mounted) return;

    if (fresh.isNotEmpty) {
      final updated = fresh.firstWhere(
        (r) => r.id == widget.originalRoute.id,
        orElse: () => fresh.first,
      );
      setState(() {
        _displayRoute    = updated;
        _isLive          = true;
        _isRecalculating = false;
      });
    } else {
      setState(() => _isRecalculating = false);
    }
  }

  void _showStepByStep(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _StepByStepSheet(route: _displayRoute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MumbaiNav')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: _LivePill(
              controller: _pulseController,
              isLive: _isLive,
              isRecalculating: _isRecalculating,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: RouteCard(
              key: ValueKey(_displayRoute.etaMinutes),
              route: _displayRoute,
              showLiveBadge: _isLive,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showStepByStep(context),
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('View Step-by-Step'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.navy),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Go is always enabled — user has a valid route, they can start now.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showStepByStep(context),
              icon: const Icon(Icons.directions_walk_rounded, size: 18),
              label: const Text('Go'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

// ── Live pill ─────────────────────────────────────────────────────────────────

class _LivePill extends StatelessWidget {
  final AnimationController controller;
  final bool isLive;
  final bool isRecalculating;

  const _LivePill({
    required this.controller,
    required this.isLive,
    required this.isRecalculating,
  });

  @override
  Widget build(BuildContext context) {
    final label = isRecalculating
        ? 'Recalculating conditions…'
        : isLive
            ? 'Conditions updated'
            : 'Listening for live conditions';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.3, end: 1).animate(controller),
            child: Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.teal),
          ),
        ],
      ),
    );
  }
}

// ── Step-by-step sheet ────────────────────────────────────────────────────────

class _StepByStepSheet extends StatelessWidget {
  final RouteOption route;
  const _StepByStepSheet({required this.route});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize:     0.4,
      maxChildSize:     0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'Your Journey',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${route.etaMinutes} min  ·  ${route.fare}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller:   scrollController,
                padding:      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount:    route.segments.length,
                separatorBuilder: (_, __) => const _Connector(),
                itemBuilder:  (_, i) => _StepTile(
                  segment:    route.segments[i],
                  isLast:     i == route.segments.length - 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Step tile ─────────────────────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final ModeSegment segment;
  final bool isLast;

  const _StepTile({required this.segment, required this.isLast});

  Color get _color {
    switch (segment.mode) {
      case TransitMode.train: return AppColors.navy;
      case TransitMode.bus:   return AppColors.red;
      case TransitMode.bike:  return AppColors.amber;
      case TransitMode.walk:  return AppColors.textMuted;
    }
  }

  IconData get _icon {
    switch (segment.mode) {
      case TransitMode.train: return Icons.tram_rounded;
      case TransitMode.bus:   return Icons.directions_bus_filled_rounded;
      case TransitMode.bike:  return Icons.pedal_bike_rounded;
      case TransitMode.walk:  return Icons.directions_walk_rounded;
    }
  }

  // Fix #5: Walk steps say "Walk to [destination]" not "Walk  TO BUS".
  // All other steps say "Board/Rent [service] at [station]".
  String get _title {
    final from = cleanStation(segment.fromStation);
    switch (segment.mode) {
      case TransitMode.walk:
        final dest = cleanStation(segment.toStation);
        return dest.isNotEmpty ? 'Walk to $dest' : 'Walk';
      case TransitMode.train:
        return 'Board ${segment.label}${from.isNotEmpty ? " at $from" : ""}';
      case TransitMode.bus:
        return 'Board ${segment.label}${from.isNotEmpty ? " at $from" : ""}';
      case TransitMode.bike:
        return 'Rent YULU${from.isNotEmpty ? " at $from" : ""}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWalk = segment.mode == TransitMode.walk;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color:  _color.withOpacity(0.12),
            border: Border.all(color: _color, width: 1.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_icon, size: 18, color: _color),
        ),
        const SizedBox(width: 14),
        // Text block
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title — action + service name
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              // "towards [destination]" — only for non-walk steps
              if (!isWalk && segment.toStation.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'towards ${cleanStation(segment.toStation)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              // Fix #3: Departure time — show when available
              if (segment.departAt != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Depart ${segment.departAt}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 4),

              // Fix #4: Wait time + travel time on separate chips
              Wrap(
                spacing: 6,
                children: [
                  // Fix #4: Wait time chip — only shown when > 0
                  if (segment.waitMinutes > 0)
                    _InfoChip(
                      label: 'Wait ~${segment.waitMinutes}m',
                      color: AppColors.amber,
                    ),
                  _InfoChip(
                    label: '${segment.travelMinutes}m journey',
                    color: _color,
                  ),
                ],
              ),

              // Fix #6: Platform note for train — honest acknowledgment
              // that live platform data isn't available in the current data
              // model. Trains typically announce platform on display boards.
              if (segment.mode == TransitMode.train) ...[
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textMuted),
                    SizedBox(width: 4),
                    Text(
                      'Check platform display board at station',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color == AppColors.textMuted ? AppColors.textMuted : AppColors.navy,
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: SizedBox(
        height: 20,
        child: VerticalDivider(
          width: 2,
          color: AppColors.border,
        ),
      ),
    );
  }
}