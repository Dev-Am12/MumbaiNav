import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

const _items = [
  _NavItem(Icons.alt_route_rounded, 'Route'),
  _NavItem(Icons.podcasts_rounded, 'Live'),
  _NavItem(Icons.bookmark_border_rounded, 'Saved'),
  _NavItem(Icons.warning_amber_rounded, 'Alerts'),
];

/// Bottom nav bar. Per PRD Section 12, Round 2 scope is the Route flow
/// only — there is no Live/Saved/Alerts screen to build. Rather than
/// leave those three silently dead on tap (which reads as a bug, not a
/// scope choice), tapping them surfaces that explicitly. "Route" is the
/// only tab that actually navigates, back to Home.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, this.currentIndex = 0});

  void _handleTap(BuildContext context, int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          '${_items[index].label} is outside this round\'s demo scope — '
          'Route is the focus.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final selected = i == currentIndex;
            final color = selected ? AppColors.red : AppColors.textMuted;
            return InkWell(
              onTap: () => _handleTap(context, i),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_items[i].icon, color: color, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      _items[i].label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}