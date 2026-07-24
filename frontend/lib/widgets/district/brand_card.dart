import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../../theme/app_colors.dart';

// The code-drawn lime "debit card" used across FirstPage / Login / Register.
// `compact` renders a shorter banner variant for the auth screens.
class BrandCard extends StatelessWidget {
  final AppColors colors;
  final bool compact;
  const BrandCard({super.key, required this.colors, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: colors.accent,
        child: Stack(
          children: [
            // Repeating faint wordmark texture.
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: Opacity(
                  opacity: 0.14,
                  child: Column(
                    children: [
                      for (var row = 0; row < 6; row++)
                        Text(
                          'FIN.FIN.FIN.FIN.FIN.FIN.',
                          style: TextStyle(
                            color: colors.onAccent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 18 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('F.',
                          style: TextStyle(
                              color: colors.onAccent,
                              fontSize: compact ? 24 : 30,
                              fontWeight: FontWeight.w800)),
                      Icon(Ionicons.wallet,
                          size: compact ? 22 : 26, color: colors.onAccent),
                    ],
                  ),
                  const Spacer(),
                  Text('FinManager',
                      style: TextStyle(
                          color: colors.onAccent,
                          fontSize: compact ? 13.5 : 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('••••  ••••  ••••',
                      style: TextStyle(
                          color: colors.onAccent.withValues(alpha: 0.7),
                          fontSize: compact ? 11.5 : 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (compact) return SizedBox(height: 148, width: double.infinity, child: card);
    return AspectRatio(aspectRatio: 1.66, child: card);
  }
}
