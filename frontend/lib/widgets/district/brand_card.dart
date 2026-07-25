import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../../theme/app_colors.dart';

/// The repeating faint "FIN." wordmark texture behind the lime surfaces.
///
/// Tiled at a fixed glyph size and clipped — deliberately never scaled to fill,
/// which would balloon the type on wide surfaces.
class WordmarkTexture extends StatelessWidget {
  final AppColors colors;
  final double fontSize;
  final double opacity;
  final int rows;
  final int repeats;

  const WordmarkTexture({
    super.key,
    required this.colors,
    this.fontSize = 13,
    this.opacity = 0.13,
    this.rows = 10,
    this.repeats = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Opacity(
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var row = 0; row < rows; row++)
                Text(
                  'FIN.' * repeats,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: colors.onAccent,
                    fontSize: fontSize,
                    height: 1.9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// The code-drawn lime "debit card" hero used on the landing screen.
// `compact` renders a shorter banner variant.
class BrandCard extends StatelessWidget {
  final AppColors colors;
  final bool compact;

  /// Fills the available height instead of holding a card aspect ratio. Used as
  /// the hero inside a wide-screen column, where the height is already bounded.
  final bool fill;

  const BrandCard({
    super.key,
    required this.colors,
    this.compact = false,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: colors.accent,
        child: Stack(
          children: [
            Positioned.fill(
              child: WordmarkTexture(
                colors: colors,
                fontSize: compact ? 12 : 13,
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
                      Text(
                        'F.',
                        style: TextStyle(
                          color: colors.onAccent,
                          fontSize: compact ? 24 : 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Icon(
                        Ionicons.wallet,
                        size: compact ? 22 : 26,
                        color: colors.onAccent,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'FinManager',
                    style: TextStyle(
                      color: colors.onAccent,
                      fontSize: compact ? 13.5 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '••••  ••••  ••••',
                    style: TextStyle(
                      color: colors.onAccent.withValues(alpha: 0.7),
                      fontSize: compact ? 11.5 : 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (compact) {
      return SizedBox(height: 148, width: double.infinity, child: card);
    }
    if (fill) return card;
    return AspectRatio(aspectRatio: 1.66, child: card);
  }
}

/// Full-bleed lime brand panel: the left column of the landing and auth screens
/// on wide viewports. Square corners and no margin, so it runs edge to edge.
class BrandPanel extends StatelessWidget {
  final AppColors colors;
  final String headline;
  final String subline;

  /// Short value props listed under the headline.
  final List<String> points;

  const BrandPanel({
    super.key,
    required this.colors,
    required this.headline,
    required this.subline,
    this.points = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.accent,
      child: Stack(
        children: [
          Positioned.fill(
            child: WordmarkTexture(
              colors: colors,
              fontSize: 15,
              opacity: 0.11,
              rows: 26,
              repeats: 16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 44, 48, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'F.',
                      style: TextStyle(
                        color: colors.onAccent,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Ionicons.wallet, size: 24, color: colors.onAccent),
                  ],
                ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: TextStyle(
                          color: colors.onAccent,
                          fontSize: 44,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        subline,
                        style: TextStyle(
                          color: colors.onAccent.withValues(alpha: 0.75),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      if (points.isNotEmpty) const SizedBox(height: 28),
                      for (final point in points)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                Ionicons.checkmark_circle,
                                size: 18,
                                color: colors.onAccent.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  point,
                                  style: TextStyle(
                                    color: colors.onAccent.withValues(
                                      alpha: 0.85,
                                    ),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '••••  ••••  ••••    FinManager',
                  style: TextStyle(
                    color: colors.onAccent.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
