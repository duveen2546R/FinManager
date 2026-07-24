import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Lightweight shimmer (no external package): sweeps a highlight band across
// its child via a moving ShaderMask. Used for skeleton loading placeholders.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color base;
  final Color highlight;
  const Shimmer({
    super.key,
    required this.child,
    required this.base,
    required this.highlight,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.base, widget.highlight, widget.base],
              stops: const [0.30, 0.50, 0.70],
              transform: _SweepTransform(_c.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SweepTransform extends GradientTransform {
  final double t; // 0..1
  const _SweepTransform(this.t);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = (t * 2 - 1) * bounds.width * 1.5;
    return Matrix4.translationValues(dx, 0, 0);
  }
}

// A single rounded skeleton block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final AppColors colors;
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// Wraps a skeleton tree in a shimmer tuned to the current surface colors.
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  final AppColors colors;
  const SkeletonShimmer({super.key, required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      base: colors.elevated,
      highlight: Color.alphaBlend(
        colors.primary.withValues(alpha: 0.18),
        colors.elevated,
      ),
      child: child,
    );
  }
}
