import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Header for the auth screens: a black rounded icon badge with a lime dot,
// then a bold headline whose key word sits on a lime highlight marker.
// Deliberately distinct from the landing screen's lime BrandCard.
class AuthHeader extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String titlePlain; // e.g. "Welcome"
  final String titleHighlight; // e.g. "back" — rendered on the lime marker
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.colors,
    required this.icon,
    required this.titlePlain,
    required this.titleHighlight,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: colors.text,
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge with a lime status dot.
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 26, color: colors.onPrimary),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.background, width: 2.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        // Headline with the key word on a lime marker.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(titlePlain, style: titleStyle),
            if (titleHighlight.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  titleHighlight,
                  style: titleStyle.copyWith(color: colors.onAccent),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(color: colors.secondaryText, fontSize: 15.5),
        ),
      ],
    );
  }
}
