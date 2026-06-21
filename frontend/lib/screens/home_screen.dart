import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/corridor_map_card.dart';
import 'results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        title: const Text('MumbaiNav'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const CorridorMapCard(),
          const SizedBox(height: 10),

          // Live data freshness indicator — replaces the cut
          // "Network Status / AQI" cards, which had no real data source.
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live corridor data updated 12s ago',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _SearchCard(
            onFindRoute: () {
              Navigator.of(context).push(
                smoothRoute(
                  const ResultsScreen(origin: 'Andheri', destination: 'BKC'),
                ),
              );
            },
          ),

          const SizedBox(height: 28),
          const Text(
            'Recent Routes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Corridor-locked recent routes only — no unrelated city pairs.
          _RecentRouteTile(
            label: 'Andheri  →  BKC (via Bandra)',
            onTap: () => Navigator.of(context).push(
              smoothRoute(
                const ResultsScreen(origin: 'Andheri', destination: 'BKC'),
              ),
            ),
          ),
          const Divider(height: 1),
          _RecentRouteTile(
            label: 'Andheri  →  BKC (via Kurla)',
            onTap: () => Navigator.of(context).push(
              smoothRoute(
                const ResultsScreen(origin: 'Andheri', destination: 'BKC'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final VoidCallback onFindRoute;
  const _SearchCard({required this.onFindRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Column(
                children: [
                  _LocationField(icon: Icons.my_location_rounded, label: 'Andheri'),
                  const SizedBox(height: 10),
                  _LocationField(icon: Icons.location_on_outlined, label: 'BKC'),
                ],
              ),
              Positioned(
                right: 4,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onFindRoute,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Find Route'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final IconData icon;
  final String label;
  const _LocationField({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RecentRouteTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RecentRouteTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}