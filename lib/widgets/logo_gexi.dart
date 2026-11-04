import 'package:flutter/material.dart';

/// Marca oficial de Gexi. El archivo ya incluye el nombre.
class LogoGexi extends StatelessWidget {
  const LogoGexi({super.key, this.ancho = 200});

  static const ruta = 'assets/branding/logo_gexi.png';

  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      ruta,
      width: ancho,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Gexi',
    );
  }
}
