import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Which scene the [EmptyStateIllustration] paints. Each maps to a fintech
/// visual so empty states reinforce what the section is about.
enum EmptyStateScene {
  /// Clipboard with document lines — "no documents tracked yet".
  document,

  /// Wallet with coin slot and banknote peeking out — "no money records".
  wallet,

  /// Magnifier over faint document lines — "no search results".
  search,

  /// Stacked coins beside an upward arrow — "no data to chart yet".
  growth,
}

/// Hand-drawn (CustomPaint) finance illustration for empty states. All
/// geometry is vector — no image assets, scales to any size, and colors
/// follow the app theme in both light and dark mode.
///
/// The scene is drawn inside a soft rounded "backdrop" tile with faint
/// decorative circles, keeping every empty state visually consistent.
class EmptyStateIllustration extends StatelessWidget {
  final EmptyStateScene scene;
  final double size;

  const EmptyStateIllustration({
    super.key,
    this.scene = EmptyStateScene.document,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight;
    final tint =
        isDark ? WazyColors.cyanAccent.withOpacity(0.85) : WazyColors.navyPrimary;
    final gold =
        isDark ? const Color(0xFFF6C453) : const Color(0xFFE0A82E);
    final backdrop = isDark ? WazyColors.slate : WazyColors.cloud;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backdrop,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        painter: _EmptyStatePainter(
          scene: scene,
          ink: ink,
          tint: tint,
          gold: gold,
        ),
      ),
    );
  }
}

class _EmptyStatePainter extends CustomPainter {
  final EmptyStateScene scene;
  final Color ink;
  final Color tint;
  final Color gold;

  _EmptyStatePainter({
    required this.scene,
    required this.ink,
    required this.tint,
    required this.gold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // The illustration canvas is a normalized 120x120 box, scaled up.
    canvas.scale(w / 120, h / 120);

    final swatch = Paint()
      ..color = ink.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = ink.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final accent = Paint()
      ..color = tint.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final accentSoft = Paint()
      ..color = tint.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = gold.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final goldSoft = Paint()
      ..color = gold.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    // Faint decorative circles (like distant data points).
    canvas.drawCircle(const Offset(18, 26), 3.5, goldSoft);
    canvas.drawCircle(const Offset(104, 88), 4.5, accentSoft);
    canvas.drawCircle(const Offset(96, 22), 2.5, swatch);

    switch (scene) {
      case EmptyStateScene.document:
        _paintDocument(canvas, swatch, fill, accent, goldPaint);
        break;
      case EmptyStateScene.wallet:
        _paintWallet(canvas, swatch, fill, accent, goldPaint, goldSoft);
        break;
      case EmptyStateScene.search:
        _paintSearch(canvas, swatch, fill, accent, accentSoft);
        break;
      case EmptyStateScene.growth:
        _paintGrowth(canvas, swatch, fill, accent, goldPaint, goldSoft);
        break;
    }
  }

  // ── Scene: clipboard / document ─────────────────────────────────────────
  void _paintDocument(
    Canvas canvas,
    Paint swatch,
    Paint fill,
    Paint accent,
    Paint gold,
  ) {
    // Board
    final board = RRect.fromRectAndRadius(
      const Rect.fromLTWH(34, 22, 52, 74),
      const Radius.circular(8),
    );
    canvas.drawRRect(board, fill);
    canvas.drawRRect(board, swatch);

    // Clip
    final clip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(50, 16, 20, 12),
      const Radius.circular(4),
    );
    canvas.drawRRect(clip, accent);

    // Text lines
    final line = Paint()
      ..color = swatch.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(44, 46), const Offset(76, 46), line);
    canvas.drawLine(const Offset(44, 58), const Offset(76, 58), line);
    canvas.drawLine(const Offset(44, 70), const Offset(66, 70), line);

    // Coin accent bottom-right
    canvas.drawCircle(const Offset(84, 86), 8, gold);
    final coinLine = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(84, 81), const Offset(84, 91), coinLine);
  }

  // ── Scene: wallet with banknote ─────────────────────────────────────────
  void _paintWallet(
    Canvas canvas,
    Paint swatch,
    Paint fill,
    Paint accent,
    Paint gold,
    Paint goldSoft,
  ) {
    // Banknote peeking out
    final note = RRect.fromRectAndRadius(
      const Rect.fromLTWH(44, 28, 34, 18),
      const Radius.circular(3),
    );
    canvas.drawRRect(note, gold);
    canvas.drawRRect(note, swatch);
    canvas.drawCircle(const Offset(61, 37), 4.5, goldSoft);
    canvas.drawCircle(const Offset(61, 37), 4.5, swatch);

    // Wallet body
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 44, 60, 46),
      const Radius.circular(9),
    );
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, swatch);

    // Clasp pocket
    final clasp = RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 58, 26, 14),
      const Radius.circular(7),
    );
    canvas.drawRRect(clasp, accent);
    canvas.drawCircle(const Offset(84, 65), 3, gold);
  }

  // ── Scene: magnifier over document ──────────────────────────────────────
  void _paintSearch(
    Canvas canvas,
    Paint swatch,
    Paint fill,
    Paint accent,
    Paint accentSoft,
  ) {
    // Faint document behind
    final doc = RRect.fromRectAndRadius(
      const Rect.fromLTWH(34, 20, 50, 66),
      const Radius.circular(7),
    );
    canvas.drawRRect(doc, fill);
    canvas.drawRRect(doc, swatch);

    final line = Paint()
      ..color = swatch.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(43, 36), const Offset(75, 36), line);
    canvas.drawLine(const Offset(43, 48), const Offset(75, 48), line);
    canvas.drawLine(const Offset(43, 60), const Offset(63, 60), line);

    // Magnifier
    canvas.drawCircle(const Offset(74, 68), 17, accentSoft);
    canvas.drawCircle(const Offset(74, 68), 17, swatch);
    final handle = Paint()
      ..color = accent.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(86, 81), const Offset(96, 92), handle);
  }

  // ── Scene: stacked coins + growth arrow ─────────────────────────────────
  void _paintGrowth(
    Canvas canvas,
    Paint swatch,
    Paint fill,
    Paint accent,
    Paint gold,
    Paint goldSoft,
  ) {
    // Coin stacks (increasing height, like a bar chart of savings).
    final stack = <Offset, int>{
      const Offset(38, 88): 1,
      const Offset(56, 88): 2,
      const Offset(74, 88): 3,
    };
    stack.forEach((base, count) {
      for (var i = 0; i < count; i++) {
        final cy = base.dy - i * 9;
        final coin = RRect.fromRectAndRadius(
          Rect.fromLTWH(base.dx - 10, cy - 5, 20, 9),
          const Radius.circular(4.5),
        );
        canvas.drawRRect(coin, i == count - 1 ? gold : goldSoft);
        canvas.drawRRect(coin, swatch);
      }
    });

    // Growth arrow
    final arrow = Path()
      ..moveTo(44, 66)
      ..lineTo(58, 52)
      ..lineTo(66, 60)
      ..lineTo(84, 40);
    final arrowPaint = Paint()
      ..color = accent.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(arrow, arrowPaint);

    // Arrow head
    final head = Path()
      ..moveTo(84, 40)
      ..lineTo(73, 40)
      ..lineTo(84, 51)
      ..close();
    canvas.drawPath(head, accent);
  }

  @override
  bool shouldRepaint(covariant _EmptyStatePainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.ink != ink ||
      oldDelegate.tint != tint ||
      oldDelegate.gold != gold;
}
