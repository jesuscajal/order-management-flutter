import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo claro con las mismas manchas del ingreso.
class FondoGexi extends StatelessWidget {
  const FondoGexi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFF5FBFA))),
        const IgnorePointer(child: _Manchas()),
        child,
      ],
    );
  }
}

class _Manchas extends StatelessWidget {
  const _Manchas();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(top: -90, left: -70, child: _Mancha(color: Color(0xFFB7F6E4), tamano: 280)),
        Positioned(top: -40, right: -90, child: _Mancha(color: Color(0xFFD7F7C8), tamano: 220)),
        Positioned(bottom: -120, right: -80, child: _Mancha(color: Color(0xFFC7E7FF), tamano: 300)),
        Positioned(bottom: -40, left: -100, child: _Mancha(color: Color(0xFFD9FBE8), tamano: 240)),
      ],
    );
  }
}

class _Mancha extends StatelessWidget {
  const _Mancha({required this.color, required this.tamano});

  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 8,
      child: Container(
        width: tamano,
        height: tamano * 0.72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tamano),
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
