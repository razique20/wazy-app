import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ProgressRing extends StatefulWidget {
  final DateTime expiresAt;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.expiresAt,
    this.size = 56,
    this.strokeWidth = 5,
    this.color,
    this.child,
  });

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Duration _remaining = Duration.zero;

  void _update(Duration remaining) => setState(() => _remaining = remaining);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(() => _update(_remaining));
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );
    _controller.repeat();
    _update(_calcRemaining());
  }

  Duration _calcRemaining() {
    final now = DateTime.now();
    final diff = widget.expiresAt.difference(now);
    if (diff.isNegative) return Duration.zero;
    if (diff.inDays > 365) return Duration(days: diff.inDays);
    return diff;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _fillColor() {
    final days = _remaining.inDays;
    if (days < 0) return FinavigColors.textMuted;
    if (days <= 7) return FinavigColors.danger;
    if (days <= 30) return FinavigColors.warning;
    if (days <= 60) return FinavigColors.caution;
    return widget.color ?? FinavigColors.safe;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _remaining.inDays;
    final pct = days < 0 ? 0.0 : (days / 365.0).clamp(0.0, 1.0);

    final fillColor = _fillColor();
    final textColor = days < 0 ? Colors.grey : Colors.white;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _RingPainter(
              progress: pct,
              strokeWidth: widget.strokeWidth,
              ringColor: fillColor,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            '$days',
            style: TextStyle(
              color: textColor,
              fontSize: widget.size * 0.32,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color ringColor;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.ringColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring (arc from 12 o'clock, clockwise)
    final progressPaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.5 * math.pi,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.backgroundColor != backgroundColor;
}
