import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../theme/app_colors.dart';
import '../responsive.dart';
import 'bottom_nav.dart';
import 'motion.dart';

/// Desktop navigation: a full-width header with the wordmark, the same four
/// destinations as [DistrictBottomNav], and the add action on the right.
///
/// Used in place of the bottom bar on wide viewports, where a floating pill
/// reads as something hovering over the page rather than app navigation.
class DistrictTopNav extends StatelessWidget implements PreferredSizeWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  final AppColors colors;

  /// Initial shown in the avatar button, which opens the Profile destination.
  final String initial;

  static const double height = 76;

  const DistrictTopNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
    required this.colors,
    this.initial = 'U',
  });

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      // Matches the page padding so the nav lines up with the content grid.
      padding: EdgeInsets.symmetric(horizontal: context.pagePadX),
      child: Row(
        children: [
          _wordmark(),
          const SizedBox(width: 36),
          for (var i = 0; i < DistrictBottomNav.items.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _tab(i),
          ],
          const Spacer(),
          _addButton(),
          const SizedBox(width: 14),
          _avatar(context),
        ],
      ),
    );
  }

  Widget _wordmark() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            'F.',
            style: TextStyle(
              color: colors.onAccent,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'FinManager',
          style: TextStyle(
            color: colors.text,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _tab(int index) {
    final active = currentIndex == index;
    final item = DistrictBottomNav.items[index];
    return PressableScale(
      onTap: () => onTap(index),
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            Icon(
              active ? item.activeIcon : item.icon,
              size: 18,
              color: active ? colors.onPrimary : colors.secondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? colors.onPrimary : colors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton() {
    return PressableScale(
      onTap: onAdd,
      scale: 0.95,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            Icon(Ionicons.add, size: 20, color: colors.onAccent),
            const SizedBox(width: 6),
            Text(
              'Add',
              style: TextStyle(
                color: colors.onAccent,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    return PressableScale(
      // Index 3 is Profile.
      onTap: () => onTap(3),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.card,
          shape: BoxShape.circle,
          border: Border.all(color: colors.accent, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: colors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
