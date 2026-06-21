import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/route_card.dart';

/// Shows the SAME route the user picked on the Results screen, updating
/// live. This intentionally takes the original RouteOption as a required
/// argument (not a fresh fetch) so the train line, bus number, and
/// destination can never drift into something unrelated — that drift
/// (e.g. "Central Station", "Bus 402", a Ride Share option) was the bug
/// in the original Stitch mockup for this screen.
class LiveUpdateScreen extends StatefulWidget {
  final RouteOption originalRoute;

  const LiveUpdateScreen({super.key, required this.originalRoute});

  @override
  State<LiveUpdateScreen> createState() => _LiveUpdateScreenState();
}

class _LiveUpdateScreenState extends State<LiveUpdateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late Future<RouteOption> _updateFuture;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _updateFuture = RouteService.fetchLiveUpdate(widget.originalRoute);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MumbaiNav')),
      body: FutureBuilder<RouteOption>(
        future: _updateFuture,
        builder: (context, snapshot) {
          final isLive = snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData;
          final displayRoute = snapshot.data ?? widget.originalRoute;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Center(child: _RecalculatingPill(controller: _pulseController, isLive: isLive)),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: RouteCard(
                  key: ValueKey(isLive),
                  route: displayRoute,
                  showLiveBadge: isLive,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLive ? () {} : null,
                  icon: const Icon(Icons.directions_walk_rounded, size: 18),
                  label: const Text('Go'),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

class _RecalculatingPill extends StatelessWidget {
  final AnimationController controller;
  final bool isLive;

  const _RecalculatingPill({required this.controller, required this.isLive});

  @override
  Widget build(BuildContext context) {
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
            isLive ? 'Conditions updated' : 'Conditions updated — recalculating',
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