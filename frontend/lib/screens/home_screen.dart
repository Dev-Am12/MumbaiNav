import 'package:flutter/material.dart';
import '../data/corridor_presets.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/corridor_map_card.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _origin = 'Andheri';
  String _destination = 'BKC';

  void _setRoute(String origin, String destination) {
    setState(() {
      _origin = origin;
      _destination = destination;
    });
  }

  Future<void> _pickStation({required bool isOrigin}) async {
    final current = isOrigin ? _origin : _destination;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    isOrigin ? 'Select origin' : 'Select destination',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                for (final station in kSelectableStations)
                  ListTile(
                    leading: Icon(
                      station == current
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: station == current ? AppColors.amber : AppColors.textMuted,
                    ),
                    title: Text(
                      station,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => Navigator.of(context).pop(station),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() {
      if (isOrigin) {
        _origin = selected;
      } else {
        _destination = selected;
      }
    });
  }

  void _swap() {
    setState(() {
      final temp = _origin;
      _origin = _destination;
      _destination = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final corridor = corridorFor(_origin, _destination);

    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        title: const Text('MumbaiNav'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (corridor != null)
            CorridorMapCard(data: corridor)
          else
            _NoCorridorPlaceholder(origin: _origin, destination: _destination),
          const SizedBox(height: 10),

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
            origin: _origin,
            destination: _destination,
            onOriginTap: () => _pickStation(isOrigin: true),
            onDestinationTap: () => _pickStation(isOrigin: false),
            onSwap: _swap,
            onFindRoute: () {
              Navigator.of(context).push(
                smoothRoute(
                  ResultsScreen(origin: _origin, destination: _destination),
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

          _RecentRouteTile(
            label: 'Andheri  →  BKC (via Bandra)',
            onTap: () {
              _setRoute('Andheri', 'BKC');
              Navigator.of(context).push(
                smoothRoute(const ResultsScreen(origin: 'Andheri', destination: 'BKC')),
              );
            },
          ),
          const Divider(height: 1),
          _RecentRouteTile(
            label: 'Andheri  →  BKC (via Kurla)',
            onTap: () {
              _setRoute('Andheri', 'BKC');
              Navigator.of(context).push(
                smoothRoute(const ResultsScreen(origin: 'Andheri', destination: 'BKC')),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

class _NoCorridorPlaceholder extends StatelessWidget {
  final String origin;
  final String destination;
  const _NoCorridorPlaceholder({required this.origin, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 28, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            'No corridor illustration for $origin → $destination yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final String origin;
  final String destination;
  final VoidCallback onOriginTap;
  final VoidCallback onDestinationTap;
  final VoidCallback onSwap;
  final VoidCallback onFindRoute;

  const _SearchCard({
    required this.origin,
    required this.destination,
    required this.onOriginTap,
    required this.onDestinationTap,
    required this.onSwap,
    required this.onFindRoute,
  });

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
                  _LocationField(
                    icon: Icons.my_location_rounded,
                    label: origin,
                    onTap: onOriginTap,
                  ),
                  const SizedBox(height: 10),
                  _LocationField(
                    icon: Icons.location_on_outlined,
                    label: destination,
                    onTap: onDestinationTap,
                  ),
                ],
              ),
              Positioned(
                right: 4,
                child: GestureDetector(
                  onTap: onSwap,
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
  final VoidCallback onTap;

  const _LocationField({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textMuted),
          ],
        ),
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