import 'dart:async';

import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/route_card.dart';

/// Shows the SAME route the user picked on the Results screen, updating
/// live. This intentionally takes the original RouteOption as a required
/// argument (not a fresh fetch) so the train line, bus number, and
/// destination can never drift into something unrelated - that drift
/// (e.g. "Central Station", "Bus 402", a Ride Share option) was the bug
/// in the original Stitch mockup for this screen.
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
  StreamSubscription<LiveConditionsUpdate>? _liveConditionsSubscription;
  late RouteOption _displayRoute;
  bool _isLive = false;
  bool _isRecalculating = true;

  @override
  void initState() {
    super.initState();
    _displayRoute = widget.originalRoute;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _liveConditionsSubscription =
        RouteService.liveConditionsStream().listen(_handleLiveConditionsUpdate);
  }

  @override
  void dispose() {
    _liveConditionsSubscription?.cancel();
    RouteService.disconnectLiveConditions();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleLiveConditionsUpdate(LiveConditionsUpdate update) async {
    if (!mounted) return;

    setState(() {
      _isRecalculating = true;
      _isLive = false;
    });

    final updatedRoutes = await RouteService.fetchRoutes(
      origin: widget.origin,
      destination: widget.destination,
    );
    if (!mounted) return;

    if (updatedRoutes.isNotEmpty) {
      final freshRoute = updatedRoutes.firstWhere(
        (r) => r.id == widget.originalRoute.id,
        orElse: () => updatedRoutes.first,
      );

      setState(() {
        _displayRoute = freshRoute;
        _isLive = true;
        _isRecalculating = false;
      });
    } else {
      setState(() {
        _isLive = true;
        _isRecalculating = false;
      });
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conditions changed, recalculating...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
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
            child: _RecalculatingPill(
              controller: _pulseController,
              isLive: _isLive,
              isRecalculating: _isRecalculating,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: RouteCard(
              key: ValueKey(_isLive),
              route: _displayRoute,
              showLiveBadge: _isLive,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLive ? () {} : null,
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

class _RecalculatingPill extends StatelessWidget {
  final AnimationController controller;
  final bool isLive;
  final bool isRecalculating;

  const _RecalculatingPill({
    required this.controller,
    required this.isLive,
    required this.isRecalculating,
  });

  @override
  Widget build(BuildContext context) {
    final label = isLive
        ? 'Conditions updated'
        : (isRecalculating
            ? 'Listening for live conditions'
            : 'Conditions updated - recalculating');

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
