import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Stylized pizza slice: triangular wedge, curved crust, yellow cheese, red pepperoni.
class PawPartyPizzaIcon extends StatelessWidget {
  const PawPartyPizzaIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PizzaSlicePainter(size: size),
      ),
    );
  }
}

class _PizzaSlicePainter extends CustomPainter {
  _PizzaSlicePainter({required this.size});

  final double size;

  static const _crust = Color(0xFFE65100);
  static const _crustLight = Color(0xFFFFB74D);
  static const _cheese = Color(0xFFFFEB3B);
  static const _pepperoni = Color(0xFFC62828);
  static const _outline = Color(0xFF5D2E00);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final m = math.min(w, h);
    final inset = m * 0.06;

    // Tip at bottom center; wide crust curve at top (reads clearly at ~16–34px).
    final tip = Offset(w * 0.5, h - inset);
    final left = Offset(w * 0.14, h * 0.22);
    final right = Offset(w * 0.86, h * 0.22);
    final crustCrown = Offset(w * 0.5, h * 0.06);

    final slice = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..quadraticBezierTo(crustCrown.dx, crustCrown.dy, right.dx, right.dy)
      ..close();

    // Outline border drawn first so it sits under the fill
    canvas.drawPath(
      slice,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, m * 0.06)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(slice, Paint()..color = _cheese);

    // Pepperoni on cheese (clipped), then crust on top so the wedge reads clearly.
    final pepR = m * 0.075;
    final pep = Paint()..color = _pepperoni;
    final pepperoniCenters = <Offset>[
      Offset(w * 0.28, h * 0.34),
      Offset(w * 0.63, h * 0.34),
      Offset(w * 0.46, h * 0.57),
    ];
    canvas.save();
    canvas.clipPath(slice);
    for (final c in pepperoniCenters) {
      canvas.drawCircle(c, pepR, pep);
    }
    canvas.restore();

    final crustPath = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(crustCrown.dx, crustCrown.dy, right.dx, right.dy);
    canvas.drawPath(
      crustPath,
      Paint()
        ..color = _crust
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.0, m * 0.14)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      crustPath,
      Paint()
        ..color = _crustLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, m * 0.05)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PizzaSlicePainter oldDelegate) =>
      oldDelegate.size != size;
}
