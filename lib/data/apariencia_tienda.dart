import 'package:flutter/material.dart';

/// Diseño de la vidriera. Cada valor sale de una lista cerrada.
class AparienciaTienda {
  const AparienciaTienda({
    this.paleta = 'verde',
    this.forma = 'suave',
    this.boton = 'Pedir',
    this.portada = 'clasica',
    this.acentoHex = '',
  });

  final String paleta;
  final String forma;
  final String boton;
  final String portada;

  /// Color de marca elegido a mano, `#RRGGBB`. Vacío si usa [paleta].
  final String acentoHex;

  static const paletas = ['verde', 'azul', 'negro', 'calido', 'rosa', 'tierra'];
  static const formas = ['redonda', 'suave', 'recta'];
  static const botones = ['Pedir', 'Encargar', 'Consultar'];
  static const portadas = ['clasica', 'menu', 'grilla'];

  static const _nombresPaleta = {
    'verde': 'Verde',
    'azul': 'Azul',
    'negro': 'Negro',
    'calido': 'Cálido',
    'rosa': 'Rosa',
    'tierra': 'Tierra',
  };

  static const _nombresForma = {
    'redonda': 'Redonda',
    'suave': 'Suave',
    'recta': 'Recta',
  };

  static const _nombresPortada = {
    'clasica': 'Clásica',
    'menu': 'Menú',
    'grilla': 'Grilla',
  };

  static String nombrePaleta(String id) => _nombresPaleta[id] ?? 'Verde';
  static String nombreForma(String id) => _nombresForma[id] ?? 'Suave';
  static String nombrePortada(String id) => _nombresPortada[id] ?? 'Clásica';

  /// Punto de partida según los rubros, antes de que la persona lo cambie.
  static AparienciaTienda paraRubros({
    required bool gastronomiaSola,
    required bool indumentaria,
    required bool tecnologia,
  }) {
    if (gastronomiaSola) {
      return const AparienciaTienda(
        paleta: 'calido',
        forma: 'suave',
        boton: 'Pedir',
        portada: 'menu',
      );
    }
    if (indumentaria) {
      return const AparienciaTienda(
        paleta: 'negro',
        forma: 'recta',
        boton: 'Consultar',
        portada: 'grilla',
      );
    }
    if (tecnologia) {
      return const AparienciaTienda(
        paleta: 'azul',
        forma: 'suave',
        boton: 'Pedir',
        portada: 'clasica',
      );
    }
    return const AparienciaTienda();
  }

  factory AparienciaTienda.desde(Object? crudo) {
    if (crudo is! Map) return const AparienciaTienda();
    final mapa = Map<String, dynamic>.from(crudo);
    return const AparienciaTienda().copiar(
      paleta: mapa['paleta']?.toString(),
      forma: mapa['forma']?.toString(),
      boton: mapa['boton']?.toString(),
      portada: mapa['portada']?.toString(),
      acentoHex: mapa['acento']?.toString(),
    );
  }

  AparienciaTienda copiar({
    String? paleta,
    String? forma,
    String? boton,
    String? portada,
    String? acentoHex,
  }) {
    final paletaOk = paletas.contains(paleta);
    final hex = acentoHex == null ? null : normalizarHex(acentoHex);
    return AparienciaTienda(
      paleta: paletaOk ? paleta! : this.paleta,
      forma: formas.contains(forma) ? forma! : this.forma,
      boton: botones.contains(boton) ? boton! : this.boton,
      portada: portadas.contains(portada) ? portada! : this.portada,
      // Si eligen una paleta y no mandan hex, el color de la paleta manda.
      acentoHex: hex ?? (paletaOk ? '' : this.acentoHex),
    );
  }

  /// `#RRGGBB` en mayúsculas, o vacío si no es un color.
  static String normalizarHex(String? valor) {
    final limpio = (valor ?? '').trim();
    final match = RegExp(r'^#?([0-9A-Fa-f]{6})$').firstMatch(limpio);
    if (match == null) return '';
    return '#${match.group(1)!.toUpperCase()}';
  }

  /// El mismo `#RRGGBB` que guarda [acentoHex].
  static String hexDeColor(Color color) {
    int canal(double valor) => (valor * 255).round().clamp(0, 255);
    final r = canal(color.r).toRadixString(16).padLeft(2, '0');
    final g = canal(color.g).toRadixString(16).padLeft(2, '0');
    final b = canal(color.b).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  static Color? colorDeHex(String? valor) {
    final hex = normalizarHex(valor);
    if (hex.isEmpty) return null;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  /// Color de una paleta, sin mirar un acento personalizado.
  static Color colorDePaleta(String id) => AparienciaTienda(paleta: id).acento;

  /// Aplica una función conocida. Si el nombre o el valor no existen, no cambia nada.
  AparienciaTienda aplicarFuncion(String nombre, String valor) {
    switch (nombre.trim()) {
      case 'poner_paleta':
        return copiar(paleta: valor);
      case 'poner_forma':
        return copiar(forma: valor);
      case 'poner_boton':
        return copiar(boton: valor);
      case 'poner_portada':
        return copiar(portada: valor);
      default:
        return this;
    }
  }

  Color get acento {
    final personalizado = colorDeHex(acentoHex);
    if (personalizado != null) return personalizado;
    switch (paleta) {
      case 'azul':
        return const Color(0xFF1A56F0);
      case 'negro':
        return const Color(0xFF111827);
      case 'calido':
        return const Color(0xFFC2410C);
      case 'rosa':
        return const Color(0xFFDB2777);
      case 'tierra':
        return const Color(0xFF92400E);
      default:
        return const Color(0xFF16A34A);
    }
  }

  double get radio {
    switch (forma) {
      case 'redonda':
        return 28;
      case 'recta':
        return 6;
      default:
        return 16;
    }
  }

  String get frasePortada {
    switch (portada) {
      case 'menu':
        return 'Elegí del menú';
      case 'grilla':
        return 'Mirá el catálogo';
      default:
        return 'Elegí tus productos';
    }
  }

  String get etiquetaPedido => '$boton por WhatsApp';

  Map<String, String> toJson() => {
        'paleta': paleta,
        'forma': forma,
        'boton': boton,
        'portada': portada,
        if (acentoHex.isNotEmpty) 'acento': acentoHex,
      };

  @override
  bool operator ==(Object other) {
    return other is AparienciaTienda &&
        other.paleta == paleta &&
        other.forma == forma &&
        other.boton == boton &&
        other.portada == portada &&
        other.acentoHex == acentoHex;
  }

  @override
  int get hashCode => Object.hash(paleta, forma, boton, portada, acentoHex);
}
