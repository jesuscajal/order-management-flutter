import 'dart:math' as math;

import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.width;
    final grosor = lado * 0.18;
    final rect = Rect.fromLTWH(
      grosor / 2,
      grosor / 2,
      lado - grosor,
      lado - grosor,
    );
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.butt;

    trazo.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi / 5, math.pi * 0.55, false, trazo);
    trazo.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.38, math.pi * 0.35, false, trazo);
    trazo.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi * 0.73, math.pi * 0.30, false, trazo);
    trazo.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, math.pi * 1.05, math.pi * 0.38, false, trazo);

    final barra = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lado * 0.46, lado * 0.41, lado * 0.46, grosor),
        Radius.circular(grosor / 4),
      ),
      barra,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
