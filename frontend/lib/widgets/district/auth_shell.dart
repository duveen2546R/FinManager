import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../responsive.dart';
import 'brand_card.dart';

/// Page frame shared by the auth screens.
///
/// On phones this is the plain scrolling column the screens have always used.
/// On laptops it becomes a full-width split: a full-bleed lime [BrandPanel]
/// filling the left half and the form centred in the right half, so the window
/// is used edge to edge with no empty gutters.
class AuthShell extends StatelessWidget {
  final AppColors colors;

  /// The form column.
  final Widget child;

  final String headline;
  final String subline;
  final List<String> points;

  const AuthShell({
    super.key,
    required this.colors,
    required this.child,
    required this.headline,
    required this.subline,
    this.points = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: child,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: BrandPanel(
            colors: colors,
            headline: headline,
            subline: subline,
            points: points,
          ),
        ),
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.screenWidth > 1400 ? 88 : 56,
                vertical: 40,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
