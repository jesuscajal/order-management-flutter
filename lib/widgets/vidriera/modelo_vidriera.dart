import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/apariencia_tienda.dart';
import '../../data/diseno_tienda.dart';
import '../../theme/app_theme.dart';

/// Un producto de la vidriera, con los datos que la pantalla ya cargó.
class ItemVidriera {
  const ItemVidriera({
    required this.clave,
    required this.nombre,
    required this.precio,
    required this.stock,
    this.descripcion = '',
    this.categorias = const [],
    this.fotos = const [],
    this.variantes = const [],
  });

  final String clave;
  final String nombre;
  final double precio;
  final int stock;
  final String descripcion;
  final List<String> categorias;
  final List<FotoItemVidriera> fotos;
  final List<VarianteItemVidriera> variantes;

  String get inicial {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return '·';
    return limpio[0].toUpperCase();
  }

  String get pieFotos {
    final vistas = <String>{};
    final lista = <String>[];
    for (final foto in fotos) {
      final nombreFoto = foto.variante.trim();
      if (nombreFoto.isEmpty || !vistas.add(nombreFoto.toLowerCase())) {
        continue;
      }
      lista.add(nombreFoto);
    }
    if (lista.isNotEmpty) return 'Fotos: ${lista.join(', ')}';
    if (fotos.length > 1) return '${fotos.length} fotos';
    return '';
  }
}

class FotoItemVidriera {
  const FotoItemVidriera({this.bytes, this.url, this.variante = ''});

  final Uint8List? bytes;
  final String? url;
  final String variante;
}

class VarianteItemVidriera {
  const VarianteItemVidriera({
    required this.etiqueta,
    required this.stock,
    required this.precio,
  });

  final String etiqueta;
  final int stock;
  final double precio;
}

class SeccionVidriera {
  const SeccionVidriera(this.titulo, this.items);

  final String titulo;
  final List<ItemVidriera> items;
}

/// Cómo se dibuja la tienda. Las banderas ausentes dejan la vidriera de hoy.
class PresentacionVidriera {
  const PresentacionVidriera({
    required this.plantillaId,
    required this.oscuro,
    required this.columnas,
    required this.mostrarBuscador,
    required this.mostrarFiltros,
    required this.mostrarHorario,
    required this.mostrarRedes,
    required this.mostrarWhatsapp,
    required this.mostrarBanner,
    required this.bannerTexto,
    required this.bannerEstilo,
    required this.acento,
    required this.radio,
    required this.etiquetaBoton,
    required this.frasePortada,
    required this.fondoGexi,
  });

  final String plantillaId;
  final bool oscuro;

  /// Null: cada plantilla elige las columnas según el ancho.
  final int? columnas;
  final bool mostrarBuscador;
  final bool mostrarFiltros;
  final bool mostrarHorario;
  final bool mostrarRedes;
  final bool mostrarWhatsapp;
  final bool mostrarBanner;
  final String bannerTexto;
  final String bannerEstilo;
  final Color acento;
  final double radio;
  final String etiquetaBoton;
  final String frasePortada;
  final bool fondoGexi;

  bool get esServicios => plantillaId == 'servicios';

  String get etiquetaProducto => esServicios ? 'Consultar' : etiquetaBoton;
}

/// Colores de una plantilla, claros u oscuros, siempre legibles sobre el fondo.
class CromoVidriera {
  const CromoVidriera({
    required this.oscuro,
    required this.acento,
    required this.sobreAcento,
    required this.fondo,
    required this.texto,
    required this.textoSuave,
    required this.tarjeta,
    required this.linea,
    required this.radio,
  });

  final bool oscuro;
  final Color acento;
  final Color sobreAcento;
  final Color fondo;
  final Color texto;
  final Color textoSuave;
  final Color tarjeta;
  final Color linea;
  final double radio;
}

const plantillasVidriera = {
  'menu',
  'tecnologia',
  'ropa',
  'cosmeticos',
  'servicios',
  'perfumes',
  'general',
};

/// Arma la presentación desde el diseño ya resuelto, o desde el rubro.
///
/// [diseno] manda: la apariencia sola no conserva `layout` y, sin esto, toda
/// tienda pública caía en la plantilla general.
PresentacionVidriera presentacionDeTienda({
  required AparienciaTienda apariencia,
  List<String> rubros = const [],
  String tipoTienda = '',
  DisenoTienda? diseno,
}) {
  if (diseno != null) {
    return _desdeDiseno(diseno, apariencia);
  }
  final layout = layoutDesdeApariencia(apariencia);
  final pedida = _texto(layout?['plantillaId']).toLowerCase();
  final plantilla = plantillasVidriera.contains(pedida)
      ? pedida
      : plantillaDeRubros(rubros, tipoTienda);
  final fondo = _texto(layout?['fondo']).toLowerCase();
  final oscuro = layout != null &&
      layout.containsKey('fondo') &&
      fondo == 'oscuro';
  final estilo = _texto(layout?['bannerEstilo']).toLowerCase();
  return PresentacionVidriera(
    plantillaId: plantilla,
    oscuro: oscuro,
    columnas: layout == null ? null : _columnas(layout['columnas']),
    mostrarBuscador: _bandera(layout, 'mostrarBuscador', true),
    mostrarFiltros: _bandera(layout, 'mostrarFiltros', true),
    mostrarHorario: _bandera(layout, 'mostrarHorario', true),
    mostrarRedes: _bandera(layout, 'mostrarRedes', true),
    mostrarWhatsapp: _bandera(layout, 'mostrarWhatsapp', true),
    mostrarBanner: _bandera(layout, 'mostrarBanner', false),
    bannerTexto: _texto(layout?['bannerTexto']),
    bannerEstilo: estilo == 'oferta' || estilo == 'novedad' ? estilo : 'simple',
    acento: apariencia.acento,
    radio: apariencia.radio,
    etiquetaBoton: apariencia.boton,
    frasePortada: apariencia.frasePortada,
    fondoGexi: plantilla == 'general' && !oscuro,
  );
}

PresentacionVidriera _desdeDiseno(
  DisenoTienda diseno,
  AparienciaTienda apariencia,
) {
  final pedida = diseno.plantillaId.toLowerCase();
  final plantilla = plantillasVidriera.contains(pedida) ? pedida : 'general';
  final oscuro = diseno.fondo == 'oscuro';
  final estilo = diseno.bannerEstilo.toLowerCase();
  return PresentacionVidriera(
    plantillaId: plantilla,
    oscuro: oscuro,
    columnas: diseno.columnas,
    mostrarBuscador: diseno.mostrarBuscador,
    mostrarFiltros: diseno.mostrarFiltros,
    mostrarHorario: diseno.mostrarHorario,
    mostrarRedes: diseno.mostrarRedes,
    mostrarWhatsapp: diseno.mostrarWhatsapp,
    mostrarBanner: diseno.mostrarBanner && diseno.bannerTexto.trim().isNotEmpty,
    bannerTexto: diseno.bannerTexto,
    bannerEstilo: estilo == 'oferta' || estilo == 'novedad' ? estilo : 'simple',
    acento: apariencia.acento,
    radio: apariencia.radio,
    etiquetaBoton: apariencia.boton,
    frasePortada: apariencia.frasePortada,
    fondoGexi: plantilla == 'general' && !oscuro,
  );
}

CromoVidriera cromoDePresentacion(PresentacionVidriera presentacion) {
  final acento = _acentoLegible(presentacion.acento, presentacion.oscuro);
  if (presentacion.oscuro) {
    final noche = presentacion.plantillaId == 'perfumes';
    return CromoVidriera(
      oscuro: true,
      acento: acento,
      sobreAcento: _textoSobre(acento),
      fondo: noche ? const Color(0xFF0B0A0E) : const Color(0xFF101418),
      texto: noche ? const Color(0xFFF4EDE2) : const Color(0xFFF3F6F8),
      textoSuave: noche ? const Color(0xFFC8BBA8) : const Color(0xFFA8B3BD),
      tarjeta: noche ? const Color(0xFF17151C) : const Color(0xFF1A2128),
      linea: noche ? const Color(0xFF3A342C) : const Color(0xFF2C3842),
      radio: presentacion.radio,
    );
  }
  return CromoVidriera(
    oscuro: false,
    acento: acento,
    sobreAcento: _textoSobre(acento),
    fondo: _fondoClaro(presentacion),
    texto: AppColors.texto,
    textoSuave: AppColors.textoSuave,
    tarjeta: Colors.white,
    linea: const Color(0xFFE5E7EB),
    radio: presentacion.radio,
  );
}

/// Lee la clave `layout` si otro módulo ya la guardó dentro de la apariencia.
///
/// Si la clave no existe, devuelve null y la tienda se deduce por rubro.
Map<String, dynamic>? layoutDesdeApariencia(AparienciaTienda apariencia) {
  final publicado = _mapa(apariencia.toJson()['layout']);
  if (publicado != null) return publicado;
  try {
    final extra = (apariencia as dynamic).layout;
    if (extra == null) return null;
    if (extra is Map) return _mapa(extra);
    return _mapa((extra as dynamic).toJson());
  } catch (_) {
    return null;
  }
}

/// Sin `layout`, la plantilla sale del rubro. Varios rubros usan el mismo
/// desempate que [DisenoTienda.desdeRubros]. Menú sigue si el tipo es Menú.
String plantillaDeRubros(List<String> rubros, String tipoTienda) {
  final deducida = DisenoTienda.desdeRubros(rubros).plantillaId;
  if (deducida != 'general') return deducida;
  if (_normalizarRubro(tipoTienda) == 'menu') return 'menu';
  return 'general';
}

int columnasDePlantilla({
  required String plantillaId,
  required int? pedidas,
  required double ancho,
}) {
  if (!ancho.isFinite || ancho <= 0) return 1;
  if (plantillaId == 'menu') {
    final pedidasMenu = (pedidas ?? 1).clamp(1, 2);
    return ancho < 760 ? 1 : pedidasMenu;
  }
  if (plantillaId == 'ropa' || plantillaId == 'cosmeticos') {
    if (ancho < 300) return 1;
    return (pedidas ?? 2).clamp(1, 3);
  }
  if (plantillaId == 'perfumes') {
    if (ancho < 980) return 1;
    return (pedidas ?? 2).clamp(1, 2);
  }
  final automaticas = switch (plantillaId) {
    'tecnologia' => ancho >= 980 ? 3 : 2,
    'servicios' => ancho >= 840 ? 2 : 1,
    _ => ancho >= 860 ? 3 : (ancho >= 560 ? 2 : 1),
  };
  var columnas = (pedidas ?? automaticas).clamp(1, 3);
  if (ancho < 420) return 1;
  if (ancho < 680 && columnas > 2) columnas = 2;
  return columnas;
}

class BannerVidriera extends StatelessWidget {
  const BannerVidriera({
    super.key,
    required this.presentacion,
    required this.cromo,
  });

  final PresentacionVidriera presentacion;
  final CromoVidriera cromo;

  @override
  Widget build(BuildContext context) {
    final texto = presentacion.bannerTexto.trim();
    if (!presentacion.mostrarBanner || texto.isEmpty) {
      return const SizedBox.shrink();
    }
    final estilo = presentacion.bannerEstilo;
    final oferta = estilo == 'oferta';
    final novedad = estilo == 'novedad';
    final fondo = oferta
        ? cromo.acento
        : novedad
            ? cromo.acento.withValues(alpha: 0.12)
            : cromo.tarjeta;
    final colorTexto = oferta ? cromo.sobreAcento : cromo.texto;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(cromo.radio),
          border: oferta
              ? null
              : Border.all(
                  color: novedad
                      ? cromo.acento.withValues(alpha: 0.45)
                      : cromo.linea,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (oferta || novedad)
              Text(
                oferta ? 'Oferta' : 'Novedad',
                style: TextStyle(
                  color: oferta ? cromo.sobreAcento : cromo.acento,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            Text(
              texto,
              style: TextStyle(
                color: colorTexto,
                fontSize: 16,
                height: 1.35,
                fontWeight: oferta ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _fondoClaro(PresentacionVidriera presentacion) {
  switch (presentacion.plantillaId) {
    case 'menu':
      return const Color(0xFFFFF8F1);
    case 'tecnologia':
      return const Color(0xFFEEF2F6);
    case 'ropa':
      return const Color(0xFFF3F3F3);
    case 'cosmeticos':
      return Color.alphaBlend(
        presentacion.acento.withValues(alpha: 0.08),
        const Color(0xFFFFF7FB),
      );
    case 'servicios':
      return const Color(0xFFF4F7F8);
    case 'perfumes':
      return const Color(0xFFF6F3EE);
    default:
      return AppColors.fondoClaro;
  }
}

Color _acentoLegible(Color acento, bool oscuro) {
  if (!oscuro || acento.computeLuminance() >= 0.45) return acento;
  return Color.lerp(acento, const Color(0xFFFFF6EA), 0.72) ?? acento;
}

Color _textoSobre(Color fondo) {
  if (fondo.computeLuminance() > 0.62) return const Color(0xFF1A1A1A);
  return Colors.white;
}

bool _bandera(Map<String, dynamic>? layout, String clave, bool siFalta) {
  if (layout == null || !layout.containsKey(clave)) return siFalta;
  final valor = layout[clave];
  if (valor is bool) return valor;
  return siFalta;
}

int? _columnas(Object? valor) {
  int? numero;
  if (valor is int) {
    numero = valor;
  } else if (valor is num) {
    numero = valor.round();
  } else if (valor is String) {
    numero = int.tryParse(valor.trim());
  }
  if (numero == null || numero < 1 || numero > 3) return null;
  return numero;
}

String _texto(Object? valor) => valor?.toString().trim() ?? '';

Map<String, dynamic>? _mapa(Object? valor) {
  if (valor is! Map || valor.isEmpty) return null;
  return Map<String, dynamic>.from(valor);
}

String _normalizarRubro(String valor) {
  const cambios = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final unidad in valor.trim().toLowerCase().split('')) {
    buffer.write(cambios[unidad] ?? unidad);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
