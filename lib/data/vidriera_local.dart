import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../backend/catalogo_remoto.dart';
import '../backend/stock_remoto.dart';

/// Tope de la foto, igual que el comprobante, para que entre en preferencias.
const int topeFotoVidriera = 140000;

/// Galería de un producto: fotos generales y fotos de cada variante.
const int topeCantidadFotos = 8;

const String mensajeGaleriaLlena =
    'Un producto acepta hasta 8 fotos, contando las de las variantes.';

const String mensajeFotoPesada =
    'La imagen es muy pesada. Probá con una foto más chica.';

/// Null si la foto entra. Si no, el mensaje en español para mostrar.
String? motivoRechazoFoto(String base64) {
  if (base64.length > topeFotoVidriera) return mensajeFotoPesada;
  return null;
}

class VidrieraRechazada implements Exception {
  const VidrieraRechazada(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Una foto de la galería. [variante] vacía es una foto del producto.
class FotoVidriera {
  const FotoVidriera({required this.base64, this.variante = ''});

  final String base64;
  final String variante;

  Map<String, dynamic> toJson() => {
        'base64': base64,
        'variante': variante.trim(),
      };

  factory FotoVidriera.fromJson(Map<String, dynamic> json) {
    final foto = json['base64'] as String? ?? '';
    if (motivoRechazoFoto(foto) != null || foto.isEmpty) {
      return const FotoVidriera(base64: '');
    }
    return FotoVidriera(
      base64: foto,
      variante: (json['variante'] as String? ?? '').trim(),
    );
  }
}

/// Descripción y fotos elegidas a mano para un producto de la vidriera.
class DatoVidriera {
  const DatoVidriera({
    this.descripcion = '',
    this.fotoBase64 = '',
    this.fotos = const [],
  });

  final String descripcion;

  /// Primera foto general. La conservamos para las pantallas que muestran una sola.
  final String fotoBase64;
  final List<FotoVidriera> fotos;

  bool get vacio =>
      descripcion.trim().isEmpty && fotoBase64.isEmpty && fotos.isEmpty;

  /// Fotos guardadas. Si el dato es viejo y solo tiene [fotoBase64], esa cuenta.
  List<FotoVidriera> get galeria {
    final lista = [
      for (final foto in fotos)
        if (foto.base64.isNotEmpty) foto,
    ];
    if (lista.isNotEmpty) return lista;
    if (fotoBase64.isEmpty) return const [];
    return [FotoVidriera(base64: fotoBase64)];
  }

  Map<String, dynamic> toJson() => {
        'descripcion': descripcion.trim(),
        'fotoBase64': fotoBase64,
        'fotos': [for (final foto in galeria) foto.toJson()],
      };

  factory DatoVidriera.fromJson(Map<String, dynamic> json) {
    var foto = json['fotoBase64'] as String? ?? '';
    if (motivoRechazoFoto(foto) != null) foto = '';
    final fotos = [
      for (final item in (json['fotos'] as List<dynamic>? ?? const []))
        if (item is Map)
          FotoVidriera.fromJson(Map<String, dynamic>.from(item)),
    ].where((fotoItem) => fotoItem.base64.isNotEmpty).toList();
    return DatoVidriera(
      descripcion: (json['descripcion'] as String? ?? '').trim(),
      fotoBase64: foto,
      fotos: fotos,
    );
  }
}

/// Bytes de la foto, o null si no hay, no entra o no se puede leer.
Uint8List? bytesDeFotoVidriera(String base64) {
  if (base64.isEmpty || motivoRechazoFoto(base64) != null) return null;
  try {
    final bytes = base64Decode(base64);
    if (bytes.isEmpty) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}

class VidrieraLocal {
  const VidrieraLocal();

  static const _clave = 'gexi_vidriera_v1';

  Future<Map<int, DatoVidriera>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return {};
    try {
      final decoded = jsonDecode(crudo);
      if (decoded is! Map) return {};
      final mapa = <int, DatoVidriera>{};
      decoded.forEach((clave, valor) {
        final id = int.tryParse(clave.toString());
        if (id == null || valor is! Map) return;
        final dato = DatoVidriera.fromJson(Map<String, dynamic>.from(valor));
        if (!dato.vacio) mapa[id] = dato;
      });
      return mapa;
    } catch (_) {
      return {};
    }
  }

  Future<DatoVidriera> de(int productoId) async {
    final mapa = await cargar();
    return mapa[productoId] ?? const DatoVidriera();
  }

  /// Si la foto supera el tope, no guarda nada y avisa en español.
  ///
  /// [fotos] en null conserva el comportamiento de una sola foto.
  /// Con la lista, esa galería reemplaza a la anterior y se sube a la nube.
  Future<void> guardar({
    required int productoId,
    required String descripcion,
    required String fotoBase64,
    List<FotoVidriera>? fotos,
    bool subir = true,
  }) async {
    final limpia = descripcion.trim();
    if (fotos == null) {
      final rechazo = motivoRechazoFoto(fotoBase64);
      if (rechazo != null) throw VidrieraRechazada(rechazo);
      final mapa = await cargar();
      if (limpia.isEmpty && fotoBase64.isEmpty) {
        mapa.remove(productoId);
      } else {
        mapa[productoId] = DatoVidriera(
          descripcion: limpia,
          fotoBase64: fotoBase64,
        );
      }
      try {
        await _escribir(mapa);
      } catch (_) {
        throw const VidrieraRechazada(
          'No se pudo guardar la foto y la descripción.',
        );
      }
      if (subir) {
        ReplicaScope.diferir(
          () => CatalogoRemoto.publicarDescripcion(
            productoLocalId: productoId,
            descripcion: limpia,
          ),
        );
      }
      return;
    }

    if (fotos.length > topeCantidadFotos) {
      throw const VidrieraRechazada(mensajeGaleriaLlena);
    }
    for (final foto in fotos) {
      final rechazo = motivoRechazoFoto(foto.base64);
      if (rechazo != null) throw VidrieraRechazada(rechazo);
    }
    final generales = [
      for (final foto in fotos)
        if (foto.variante.trim().isEmpty) foto.base64,
    ];
    final mapa = await cargar();
    if (limpia.isEmpty && fotos.isEmpty) {
      mapa.remove(productoId);
    } else {
      mapa[productoId] = DatoVidriera(
        descripcion: limpia,
        fotoBase64: generales.isEmpty ? '' : generales.first,
        fotos: fotos,
      );
    }
    try {
      await _escribir(mapa);
    } catch (_) {
      throw const VidrieraRechazada(
        'No se pudo guardar la foto y la descripción.',
      );
    }
    if (!subir) return;
    ReplicaScope.diferir(
      () => CatalogoRemoto.publicarVidriera(
        productoLocalId: productoId,
        descripcion: limpia,
        fotos: [
          for (final foto in fotos)
            FotoParaNube(base64: foto.base64, variante: foto.variante),
        ],
      ),
    );
  }

  Future<void> _escribir(Map<int, DatoVidriera> mapa) async {
    final prefs = await SharedPreferences.getInstance();
    if (mapa.isEmpty) {
      await prefs.remove(_clave);
      return;
    }
    await prefs.setString(
      _clave,
      jsonEncode({
        for (final entrada in mapa.entries)
          '${entrada.key}': entrada.value.toJson(),
      }),
    );
  }
}
