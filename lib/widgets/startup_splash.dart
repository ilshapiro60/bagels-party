import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Shown while auth session restores.
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  static const _splashBg = Color(0xFF0A0E18);
  static const _wordmarkTok = Color(0xFF4DD0E1);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _splashBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _SplashBackdropPainter()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final maxH = MediaQuery.sizeOf(context).height * 0.34;
                      return SizedBox(
                        width: constraints.maxWidth,
                        height: maxH,
                        child: Image.asset(
                          'assets/images/zumitok_logo.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.pets,
                            size: 88,
                            color: PawPartyColors.secondary.withValues(alpha: 0.85),
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(flex: 3),
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _wordmarkTok,
                    ),
                  ),
                  SizedBox(height: 20 + bottomInset),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft vignette + subtle sparkles (does not compete with the logo).
class _SplashBackdropPainter extends CustomPainter {
  const _SplashBackdropPainter();

  static final List<_Sparkle> _sparkles = [
    _Sparkle(0.07, 0.10, _gold, 5),
    _Sparkle(0.18, 0.22, _cyan, 4),
    _Sparkle(0.88, 0.14, _cyan, 5),
    _Sparkle(0.93, 0.38, _gold, 3),
    _Sparkle(0.12, 0.62, _cyan, 4),
    _Sparkle(0.78, 0.72, _gold, 5),
    _Sparkle(0.48, 0.16, _gold, 3),
    _Sparkle(0.62, 0.20, _cyan, 4),
    _Sparkle(0.36, 0.78, _cyan, 3),
    _Sparkle(0.54, 0.88, _gold, 4),
    _Sparkle(0.28, 0.44, _cyan, 2),
    _Sparkle(0.82, 0.52, _gold, 3),
  ];

  static const Color _gold = Color(0x66FFECB3);
  static const Color _cyan = Color(0x6680DEEA);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.92,
        colors: [
          Colors.transparent,
          const Color(0xFF05070C).withValues(alpha: 0.55),
        ],
        stops: const [0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);

    for (final s in _sparkles) {
      _paintSparkle(canvas, s.dx * size.width, s.dy * size.height, s.color, s.r);
    }
  }

  void _paintSparkle(Canvas canvas, double x, double y, Color color, double r) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - r, y), Offset(x + r, y), p);
    canvas.drawLine(Offset(x, y - r), Offset(x, y + r), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Sparkle {
  const _Sparkle(this.dx, this.dy, this.color, this.r);
  final double dx;
  final double dy;
  final Color color;
  final double r;
}
