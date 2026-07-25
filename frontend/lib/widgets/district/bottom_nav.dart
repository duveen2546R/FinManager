import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../../theme/app_colors.dart';
import 'motion.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem(this.icon, this.activeIcon, this.label);
}

// Neobank bottom bar: flat rounded white bar, thin line icons with labels,
// black active state, and a solid black circular Add action in the middle.
class DistrictBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  final AppColors colors;

  static const List<NavItem> items = [
    NavItem(Ionicons.home_outline, Ionicons.home, 'Home'),
    NavItem(Ionicons.receipt_outline, Ionicons.receipt, 'Activity'),
    NavItem(Ionicons.sparkles_outline, Ionicons.sparkles, 'AI'),
    NavItem(Ionicons.person_outline, Ionicons.person, 'Profile'),
  ];

  const DistrictBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      height: 68,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [_tab(0), _tab(1), _centerButton(), _tab(2), _tab(3)],
      ),
    );

    return SafeArea(top: false, child: bar);
  }

  Widget _tab(int index) {
    final active = currentIndex == index;
    final item = items[index];
    final color = active ? colors.text : colors.secondaryText;
    return Expanded(
      child: PressableScale(
        onTap: () => onTap(index),
        child: SizedBox(
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? item.activeIcon : item.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerButton() {
    return PressableScale(
      onTap: onAdd,
      scale: 0.9,
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(Ionicons.add, size: 26, color: colors.onPrimary),
      ),
    );
  }
}
