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
  bool _isLive = false;
  bool _isRecalculating = false;

  @override
  void initState() {
    super.initState();
    _displayRoute = widget.originalRoute;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    // Subscribe to Socket.io live-conditions events (now 15s tick).
    // The Go button is NOT gated on this — the user already has a valid
    // route and should be able to start immediately. Live updates
    // improve the displayed data but don't block the user.
    _liveSub = RouteService.liveConditionsStream().listen(_onLiveUpdate);
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    RouteService.disconnectLiveConditions();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onLiveUpdate(LiveConditionsUpdate update) async {
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

  // Shows the step-by-step journey breakdown — the key differentiator
  // from generic maps. Tells the user exactly which service to board,
  // where, and for how long.
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

          // Step-by-step button — always enabled. User picked this route,
          // they should be able to see the breakdown and start immediately.
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
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Go — always enabled. Selecting this route is the user's
          // decision; conditions may be updating but they can start now.
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

// ─── Live pill ──────────────────────────────────────────────────────────────

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
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step-by-step bottom sheet ──────────────────────────────────────────────

class _StepByStepSheet extends StatelessWidget {
  final RouteOption route;
  const _StepByStepSheet({required this.route});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'Your Journey',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${route.etaMinutes} min  ·  ${route.fare}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Steps
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: route.segments.length,
                separatorBuilder: (_, __) => const _StepConnector(),
                itemBuilder: (_, i) => _StepTile(
                  segment: route.segments[i],
                  stepNumber: i + 1,
                  isLast: i == route.segments.length - 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  final ModeSegment segment;
  final int stepNumber;
  final bool isLast;

  const _StepTile({
    required this.segment,
    required this.stepNumber,
    required this.isLast,
  });

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

  String get _action {
    switch (segment.mode) {
      case TransitMode.train: return 'Board train';
      case TransitMode.bus:   return 'Board bus';
      case TransitMode.bike:  return 'Rent bike';
      case TransitMode.walk:  return 'Walk';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.12),
            border: Border.all(color: _color, width: 1.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_icon, size: 18, color: _color),
        ),
        const SizedBox(width: 14),
        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Action + route name
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: '$_action  ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: segment.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // Towards + duration
              Text(
                segment.sublabel.isNotEmpty
                    ? 'towards ${segment.sublabel}  ·  ${segment.duration}'
                    : segment.duration,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 19),
      child: Column(
        children: List.generate(4, (_) => const SizedBox(
          height: 5,
          child: VerticalDivider(
            width: 2,
            color: AppColors.border,
          ),
        )),
      ),
    );
  }
}