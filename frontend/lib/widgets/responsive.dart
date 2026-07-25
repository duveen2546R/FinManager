import 'package:flutter/material.dart';

/// Layout breakpoints. The UI is mobile-first: below [Breakpoints.wide] every
/// screen renders exactly as it always has, and at or above it screens spread
/// into the full viewport using multiple columns.
class Breakpoints {
  Breakpoints._();

  /// Laptops and desktops: multi-column layouts, full-bleed background.
  static const double wide = 900;

  /// Large tablets / small laptops: roomier padding, some two-column splits.
  static const double medium = 640;

  /// Beyond this, columns stop growing and extra width becomes side padding
  /// on the *page* (background still fills the window, so no visible gutter).
  static const double contentMax = 1600;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isWide => screenWidth >= Breakpoints.wide;
  bool get isMedium =>
      screenWidth >= Breakpoints.medium && screenWidth < Breakpoints.wide;
  bool get isCompact => screenWidth < Breakpoints.medium;

  /// Horizontal page padding, scaled to the viewport.
  double get pagePadX {
    if (isCompact) return 20;
    if (isMedium) return 28;
    // Very wide windows get generous edges so content isn't glued to the frame,
    // but the page background still runs edge to edge.
    final slack = (screenWidth - Breakpoints.contentMax).clamp(0, 400) / 2;
    return 40 + slack;
  }

  /// Vertical rhythm between major page sections.
  double get sectionGap => isWide ? 24 : 16;
}

/// Lays [children] out side by side on wide screens and stacked on narrow ones.
///
/// This is the main tool for turning a mobile column into a desktop layout:
/// pass the sections in reading order and they stack on a phone, or become
/// columns (weighted by [flex]) on a laptop.
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;

  /// Column weights on wide screens. Defaults to equal width. When shorter than
  /// [children], the missing entries default to 1.
  final List<int> flex;
  final double gap;

  /// How columns align to each other on wide screens.
  final CrossAxisAlignment crossAxisAlignment;

  /// Force the side-by-side layout on or off instead of using the breakpoint.
  final bool? wide;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.flex = const [],
    this.gap = 20,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.wide,
  });

  int _flexAt(int i) => i < flex.length ? flex[i] : 1;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    if (!(wide ?? context.isWide)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(flex: _flexAt(i), child: children[i]),
        ],
      ],
    );
  }
}

/// A responsive grid of equally sized tiles: [columns] across on wide screens,
/// [compactColumns] on phones. Rows are built manually (rather than using
/// GridView) so tiles size to their content and the grid can live inside a
/// scrolling column.
class ResponsiveTileGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final int compactColumns;
  final double gap;

  const ResponsiveTileGrid({
    super.key,
    required this.children,
    this.columns = 3,
    this.compactColumns = 1,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final perRow = context.isWide
        ? columns
        : (context.isMedium ? 2 : compactColumns);
    if (perRow <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += perRow) {
      final slice = children.sublist(
        start,
        (start + perRow).clamp(0, children.length),
      );
      rows.add(
        // IntrinsicHeight lets `stretch` give every tile in the row the height
        // of the tallest one, even though the grid sits in an unbounded column.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < perRow; i++) ...[
                if (i > 0) SizedBox(width: gap),
                // Empty slots keep the last row's tiles the same width as above.
                Expanded(
                  child: i < slice.length ? slice[i] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }
}

/// Distributes [children] over [columns] balanced columns on wide screens and
/// stacks them on narrow ones.
///
/// Unlike [ResponsiveTileGrid] the columns are independent, so cards of very
/// different heights (a day with one transaction next to a day with twelve)
/// pack tightly instead of being stretched to a common row height. Pass
/// [weights] — a rough relative height per child, e.g. the number of rows it
/// contains — to balance the columns.
class MasonryColumns extends StatelessWidget {
  final List<Widget> children;
  final List<int> weights;
  final int columns;
  final double gap;

  const MasonryColumns({
    super.key,
    required this.children,
    this.weights = const [],
    this.columns = 2,
    this.gap = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final count = context.isWide ? columns : 1;
    if (count <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }

    // Greedily drop each child into whichever column is currently shortest.
    final buckets = List.generate(count, (_) => <Widget>[]);
    final heights = List.filled(count, 0);
    for (var i = 0; i < children.length; i++) {
      var shortest = 0;
      for (var c = 1; c < count; c++) {
        if (heights[c] < heights[shortest]) shortest = c;
      }
      buckets[shortest].add(children[i]);
      heights[shortest] += i < weights.length ? weights[i] : 1;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < count; c++) ...[
          if (c > 0) SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < buckets[c].length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  buckets[c][i],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Caps the width of prose so long paragraphs stay readable on wide screens
/// without leaving a visible gutter (the page background shows through).
class ReadableWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) return child;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Keeps modal bottom sheets a sensible width on a laptop, where a sheet
/// spanning the whole window looks like a mis-render. Null on phones so the
/// sheet keeps its default full-width behaviour.
BoxConstraints? sheetConstraints(BuildContext context) =>
    context.isWide ? const BoxConstraints(maxWidth: 560) : null;
