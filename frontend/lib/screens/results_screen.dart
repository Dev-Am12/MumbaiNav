import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/route_card.dart';
import 'live_update_screen.dart';

class ResultsScreen extends StatefulWidget {
  final String origin;
  final String destination;

  const ResultsScreen({
    super.key,
    required this.origin,
    required this.destination,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final Future<List<RouteOption>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = RouteService.fetchRoutes(
      origin: widget.origin,
      destination: widget.destination,
    );
  }

  void _openLiveScreen(BuildContext context, RouteOption route) {
    Navigator.of(context).push(
      smoothRoute(
        LiveUpdateScreen(
          originalRoute: route,
          origin: widget.origin,
          destination: widget.destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Routes to ${widget.destination}')),
      body: FutureBuilder<List<RouteOption>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.amber),
                  SizedBox(height: 14),
                  Text(
                    'Finding best routes…',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }

          final routes = snapshot.data ?? [];

          if (routes.isEmpty) {
            return const Center(
              child: Text(
                'No routes found. Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            );
          }

          // Safety: if AI ranking somehow marks none as recommended,
          // promote the first (fastest A* result) rather than crash.
          final recommended = routes.firstWhere(
            (r) => r.isRecommended,
            orElse: () => routes.first,
          );
          final others = routes.where((r) => r.id != recommended.id).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const _SectionLabel('RECOMMENDED'),
              const SizedBox(height: 10),
              RouteCard(
                route: recommended,
                onTap: () => _openLiveScreen(context, recommended),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionLabel('OTHER OPTIONS'),
                const SizedBox(height: 10),
                for (final r in others) ...[
                  // Every alternate card is tappable — tapping opens
                  // the live-update screen for that specific route,
                  // not the recommended one. This was the bug where
                  // only the top card was interactive.
                  RouteCard(
                    route: r,
                    onTap: () => _openLiveScreen(context, r),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
      ),
    );
  }
}