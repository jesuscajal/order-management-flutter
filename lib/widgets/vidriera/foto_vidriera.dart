import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Foto de producto, logo chico o inicial. Nunca usa archivos del disco.
class FotoVidriera extends StatelessWidget {
  const FotoVidriera({
    super.key,
    required this.bytes,
    required this.url,
    required this.color,
    required this.inicial,
    this.alto,
    this.ancho,
    this.ajuste = BoxFit.cover,
    this.circular = false,
    this.radio = 0,
    this.fondo,
    this.tamanoInicial = 28,
    this.iconoSiFalta = false,
  });

  final Uint8List? bytes;
  final String? url;
  final Color color;
  final String inicial;
  final double? alto;
  final double? ancho;
  final BoxFit ajuste;
  final bool circular;
  final double radio;
  final Color? fondo;
  final double tamanoInicial;
  final bool iconoSiFalta;

  @override
  Widget build(BuildContext context) {
    final marca = ColoredBox(
      color: fondo ?? color.withValues(alpha: 0.12),
      child: Center(
        child: iconoSiFalta
            ? Icon(Icons.image_outlined, color: color, size: tamanoInicial)
            : Text(
                inicial,
                style: TextStyle(
                  color: color,
                  fontSize: tamanoInicial,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
    final memoria = bytes;
    final enlace = url?.trim() ?? '';
    final Widget imagen;
    if (memoria != null && memoria.isNotEmpty) {
      imagen = Image.memory(
        memoria,
        fit: ajuste,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => marca,
      );
    } else if (enlace.isNotEmpty) {
      imagen = Image.network(
        enlace,
        fit: ajuste,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progreso) {
          if (progreso == null) return child;
          return marca;
        },
        errorBuilder: (context, error, stackTrace) => marca,
      );
    } else {
      imagen = marca;
    }
    final recorte = SizedBox(
      height: alto,
      width: ancho ?? (alto != null ? double.infinity : null),
      child: imagen,
    );
    if (circular) return ClipOval(child: recorte);
    if (radio <= 0) return recorte;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: recorte,
    );
  }
}
