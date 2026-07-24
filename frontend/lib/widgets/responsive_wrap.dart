import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

/// Makes the mobile-first UI look right on web, tablets, and laptops by
/// constraining the whole app to a centered, phone-width column on wide
/// screens. On phones (width <= [maxWidth]) it is a transparent no-op.
///
/// It also overrides the [MediaQuery] size for descendants, so any layout that
/// measures the screen (e.g. chat-bubble max width, `MediaQuery.size`) sees the
/// constrained width rather than the full window.
class ResponsiveWrap extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveWrap({super.key, required this.child, this.maxWidth = 500});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;

    final colors = context.watch<ThemeProvider>().colors;
    // A subtly contrasting gutter frames the centered app panel.
    final gutter =
        colors.isDark ? const Color(0xFF000000) : const Color(0xFFE7E7E4);

    return ColoredBox(
      color: gutter,
      child: Center(
        child: ClipRect(
          child: SizedBox(
            width: maxWidth,
            child: MediaQuery(
              data: media.copyWith(size: Size(maxWidth, media.size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
