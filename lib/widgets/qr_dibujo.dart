import 'package:flutter/material.dart';

/// Pinta una matriz de QR. El margen blanco de cuatro módulos va incluido.
class QrDibujo extends StatelessWidget {
  const QrDibujo({
    super.key,
    required this.modulos,
    this.lado = 260,
  });

  final List<List<bool>> modulos;
  final double lado;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: lado,
      height: lado,
      child: CustomPaint(
        painter: _PintorQr(modulos),
        size: Size.square(lado),
      ),
    );
  }
}

class _PintorQr extends CustomPainter {
  _PintorQr(this.modulos);

  final List<List<bool>> modulos;

  @override
  void paint(Canvas canvas, Size size) {
    final n = modulos.length;
    const quieto = 4;
    final total = n + quieto * 2;
    final escala = size.shortestSide / total;
    final origen = Offset(
      (size.width - escala * total) / 2,
      (size.height - escala * total) / 2,
    );
    final blanco = Paint()..color = Colors.white;
    final negro = Paint()..color = const Color(0xFF111111);
    canvas.drawRect(Offset.zero & size, blanco);
    for (var fila = 0; fila < n; fila++) {
      for (var columna = 0; columna < n; columna++) {
        if (!modulos[fila][columna]) continue;
        final izquierda = origen.dx + (columna + quieto) * escala;
        final arriba = origen.dy + (fila + quieto) * escala;
        canvas.drawRect(
          Rect.fromLTWH(izquierda, arriba, escala + 0.5, escala + 0.5),
          negro,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PintorQr oldDelegate) {
    return oldDelegate.modulos != modulos;
  }
}
