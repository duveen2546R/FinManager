import 'package:flutter/material.dart';
import 'motion.dart';

// Neobank cards: flat, generous radius, whisper-soft shadow. No gradients.

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? border;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    required this.color,
    this.border,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(onTap: onTap, child: card);
  }
}

// Solid accent tile (lime debit-card style) for feature moments.
class AccentCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const AccentCard({
    super.key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(onTap: onTap, child: card);
  }
}
