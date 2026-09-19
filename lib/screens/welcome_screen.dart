import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Pre-login welcome screen — the first thing a brand-new user sees.
///
/// Hero headline, an in-phone product preview ("Easy ways to manage your
/// finances" with a Get Started pill), and a full-width Get Started button
/// that advances to the login page.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _getStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final imageWidth = w < 480 ? w : 380.0;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 40, 24, 0),
                          child: Text(
                            'Modern Fintech for\nPersonal Finance',
                            style: TextStyle(
                              fontSize: w < 400 ? 30 : 36,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: WazyColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: _PhoneMockup(
                            width: imageWidth,
                            onTap: _getStarted,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _getStarted,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WazyColors.navyPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Poster-style phone frame on the violet field, matching the reference art:
/// a white screen with playful shapes, a blue blob with the wordmark, and a
/// "Easy ways to manage your finances" card with a Get Started pill.
class _PhoneMockup extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _PhoneMockup({required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: WazyColors.navyPrimary,
          borderRadius: BorderRadius.circular(width * 0.13),
        ),
        padding: EdgeInsets.all(width * 0.055),
        child: AspectRatio(
          aspectRatio: 9 / 18.5,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(width * 0.075),
              border: Border.all(color: const Color(0xFF111111), width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(width * 0.075 - 3),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Corner accent shapes
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _CornerShapes(),
                  ),
                  // Sparkle top-left
                  Positioned(
                    top: 26,
                    left: 30,
                    child: _Sparkle(size: 15, color: Color(0xFF111111)),
                  ),
                  // Floating rings around the blob
                  Center(
                    child: _BlobWithRings(),
                  ),
                  // Headline + pill pinned to the bottom
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Easy ways to manage your finances',
                                style: TextStyle(
                                  fontSize: 19,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: WazyColors.textPrimaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const _Sparkle(size: 10, color: Color(0xFFD9B8FF)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Get Started pill inside the phone
                        Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: WazyColors.navyPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Get Started  →',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Corner cluster of mint and pink shapes, like the reference poster.
class _CornerShapes extends StatelessWidget {
  const _CornerShapes();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 90,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 14,
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFF9AF2C6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  topRight: Radius.circular(6),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 40,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFF4D8F7),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                ),
              ),
            ),
          ),
          Positioned(
            top: 62,
            right: 84,
            child: Container(
              width: 15,
              height: 15,
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wordmark blob with concentric guilloché-style rings.
class _BlobWithRings extends StatelessWidget {
  const _BlobWithRings();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CustomPaint(size: Size.square(200), painter: _RingsPainter()),
          Container(
            width: 108,
            height: 150,
            decoration: BoxDecoration(
              color: WazyColors.navyPrimary,
              borderRadius: BorderRadius.circular(60),
            ),
            alignment: Alignment.center,
            child: const Text(
              'WAZY',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws several thin offset ellipse outlines for the thread-like ring effect.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Rotate a family of ellipses around the center.
    final colors = [
      const Color(0xFF7C7CF4),
      const Color(0xFFF1A7F5),
      const Color(0xFF7CE8C5),
    ];
    for (var i = 0; i < 14; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 14);
      paint.color = colors[i % colors.length].withOpacity(0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.9,
          height: size.height * 0.62,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) => false;
}

/// Four-point star / sparkle used in the poster art.
class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;

  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SparklePainter(color: color),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}
