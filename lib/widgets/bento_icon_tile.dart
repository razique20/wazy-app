import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A bento-style icon tile: a soft pastel rounded square carrying one icon.
///
/// The signature element of the new design language — used for category
/// grids, settings rows, insight tiles and quick actions. In dark mode the
/// pastel tint deepens automatically so icons stay vibrant without glowing.
class BentoIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? tint;
  final double size;
  final double iconSize;
  final double radius;

  const BentoIconTile({
    super.key,
    required this.icon,
    this.color = WazyColors.indigo,
    this.tint,
    this.size = 44,
    this.iconSize = 21,
    this.radius = 14,
  });

  /// Pastel container matching [color] for the given brightness.
  static Color tintFor(Color color, bool isDark) {
    if (isDark) return color.withOpacity(0.16);
    return color.withOpacity(0.11);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = tint ?? tintFor(color, isDark);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize * (size / 44),
          color: isDark ? color.withOpacity(0.95) : color,
        ),
      ),
    );
  }
}
