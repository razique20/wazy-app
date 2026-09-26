import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable pulsating shimmer animation widget for loading skeleton states.
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.margin,
    this.padding,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.3, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? FinavigColors.slate.withOpacity(0.4)
        : Colors.grey.shade300;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: baseColor.withOpacity(_opacity.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Ready-made skeleton loader card representing a document or transaction tile.
class TileSkeletonLoader extends StatelessWidget {
  const TileSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FinavigColors.slate.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          ShimmerSkeleton(width: 42, height: 42, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(width: 140, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerSkeleton(width: 90, height: 10, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 12),
          ShimmerSkeleton(width: 60, height: 20, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Full-page skeleton representation for HomeScreen.
class HomeSkeletonView extends StatelessWidget {
  const HomeSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card skeleton
          const ShimmerSkeleton(
            width: double.infinity,
            height: 140,
            borderRadius: 20,
          ),
          const SizedBox(height: 20),

          // Categories grid skeleton
          const ShimmerSkeleton(width: 160, height: 18, borderRadius: 4),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: ShimmerSkeleton(width: double.infinity, height: 80, borderRadius: 14)),
              SizedBox(width: 10),
              Expanded(child: ShimmerSkeleton(width: double.infinity, height: 80, borderRadius: 14)),
              SizedBox(width: 10),
              Expanded(child: ShimmerSkeleton(width: double.infinity, height: 80, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: 24),

          // Tile list skeleton
          const ShimmerSkeleton(width: 180, height: 18, borderRadius: 4),
          const SizedBox(height: 12),
          const TileSkeletonLoader(),
          const TileSkeletonLoader(),
          const TileSkeletonLoader(),
        ],
      ),
    );
  }
}

/// Full-page skeleton representation for DocumentsScreen.
class DocumentsSkeletonView extends StatelessWidget {
  const DocumentsSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter bar skeleton
          const ShimmerSkeleton(
            width: double.infinity,
            height: 48,
            borderRadius: 14,
          ),
          const SizedBox(height: 14),

          // Category Chips skeleton
          Row(
            children: const [
              ShimmerSkeleton(width: 70, height: 32, borderRadius: 20),
              SizedBox(width: 8),
              ShimmerSkeleton(width: 100, height: 32, borderRadius: 20),
              SizedBox(width: 8),
              ShimmerSkeleton(width: 80, height: 32, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 20),

          // Document cards skeleton
          const TileSkeletonLoader(),
          const TileSkeletonLoader(),
          const TileSkeletonLoader(),
          const TileSkeletonLoader(),
        ],
      ),
    );
  }
}

/// Full-page skeleton representation for MoneyScreen.
class MoneySkeletonView extends StatelessWidget {
  const MoneySkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance hero card skeleton
          const ShimmerSkeleton(
            width: double.infinity,
            height: 160,
            borderRadius: 20,
          ),
          const SizedBox(height: 20),

          // Quick Action buttons skeleton
          Row(
            children: const [
              Expanded(child: ShimmerSkeleton(width: double.infinity, height: 44, borderRadius: 12)),
              SizedBox(width: 10),
              Expanded(child: ShimmerSkeleton(width: double.infinity, height: 44, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 24),

          // Transactions list skeleton
          const ShimmerSkeleton(width: 150, height: 18, borderRadius: 4),
          const SizedBox(height: 12),
          const TileSkeletonLoader(),
          const TileSkeletonLoader(),
          const TileSkeletonLoader(),
        ],
      ),
    );
  }
}
