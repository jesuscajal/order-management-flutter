import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Mapa id local de Drift ↔ uuid de Supabase.
///
/// Vive en un solo JSON de SharedPreferences para no tocar el esquema de Drift.
/// Las variantes, unidades y categorías no tienen id entero: la clave es un texto.
class IdsRemotos {
  const IdsRemotos();

  static const _clave = 'gexi_ids_remotos_v1';

  static const cliente = 'cliente';
  static const producto = 'producto';
  static const pedido = 'pedido';
  static const capital = 'capital';
  static const movimientoStock = 'movimiento_stock';
  static const categoria = 'categoria';
  static const variante = 'variante';
  static const unidad = 'unidad';
  static const historialPedido = 'historial_pedido';
  static const historialCliente = 'historial_cliente';

  static String claveVariante(int productoLocalId, String etiqueta) =>
      '$productoLocalId|${etiqueta.trim().toLowerCase()}';

  static String claveUnidad(int productoLocalId, String codigo) =>
      '$productoLocalId|${codigo.trim().toLowerCase()}';

  static String claveCategoria(String nombre) => nombre.trim().toLowerCase();

  static Future<void> _cola = Future<void>.value();

  Future<T> _enOrden<T>(Future<T> Function() accion) {
    final resultado = _cola.then((_) => accion());
    _cola = resultado.then<void>((_) {}, onError: (_, __) {});
    return resultado;
  }

  Future<String?> leer(String tabla, String claveLocal) {
    return _enOrden(() async {
      final doc = await _doc();
      final id = doc.ida[tabla]?[claveLocal];
      if (id == null || id.isEmpty) return null;
      return id;
    });
  }

  Future<int?> localDe(String tabla, String remotoId) async {
    final clave = await claveDe(tabla, remotoId);
    if (clave == null) return null;
    return int.tryParse(clave);
  }

  Future<String?> claveDe(String tabla, String remotoId) {
    return _enOrden(() async {
      final doc = await _doc();
      final clave = doc.vuelta[tabla]?[remotoId.trim()];
      if (clave == null || clave.isEmpty) return null;
      return clave;
    });
  }

  Future<Map<String, String>> de(String tabla) {
    return _enOrden(() async {
      final doc = await _doc();
      return Map<String, String>.from(doc.ida[tabla] ?? const {});
    });
  }

  Future<void> guardar(String tabla, String claveLocal, String remotoId) {
    return _enOrden(() async {
      final local = claveLocal.trim();
      final remoto = remotoId.trim();
      if (local.isEmpty || remoto.isEmpty) return;
      final doc = await _doc();
      final ida = doc.ida.putIfAbsent(tabla, () => {});
      final vuelta = doc.vuelta.putIfAbsent(tabla, () => {});
      final anterior = ida[local];
      if (anterior != null && anterior != remoto) {
        vuelta.remove(anterior);
      }
      final localAnterior = vuelta[remoto];
      if (localAnterior != null && localAnterior != local) {
        ida.remove(localAnterior);
      }
      ida[local] = remoto;
      vuelta[remoto] = local;
      await _escribir(doc);
    });
  }

  Future<void> olvidar(String tabla, String claveLocal) {
    return _enOrden(() async {
      final doc = await _doc();
      final ida = doc.ida[tabla];
      if (ida == null) return;
      final remoto = ida.remove(claveLocal);
      if (remoto != null) {
        doc.vuelta[tabla]?.remove(remoto);
      }
      await _escribir(doc);
    });
  }

  Future<_DocIds> _doc() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave);
      if (crudo == null || crudo.isEmpty) return _DocIds();
      final decoded = jsonDecode(crudo);
      if (decoded is! Map) return _DocIds();
      return _DocIds.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return _DocIds();
    }
  }

  Future<void> _escribir(_DocIds doc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(doc.toJson()));
  }
}

class _DocIds {
  _DocIds({
    Map<String, Map<String, String>>? ida,
    Map<String, Map<String, String>>? vuelta,
  })  : ida = ida ?? {},
        vuelta = vuelta ?? {};

  final Map<String, Map<String, String>> ida;
  final Map<String, Map<String, String>> vuelta;

  factory _DocIds.fromJson(Map<String, dynamic> json) {
    return _DocIds(
      ida: _capa(json['ida']),
      vuelta: _capa(json['vuelta']),
    );
  }

  Map<String, dynamic> toJson() => {'ida': ida, 'vuelta': vuelta};

  static Map<String, Map<String, String>> _capa(Object? crudo) {
    final salida = <String, Map<String, String>>{};
    if (crudo is! Map) return salida;
    crudo.forEach((tabla, valor) {
      if (valor is! Map) return;
      final filas = <String, String>{};
      valor.forEach((clave, id) {
        final texto = id?.toString().trim() ?? '';
        if (texto.isEmpty) return;
        filas[clave.toString()] = texto;
      });
      salida[tabla.toString()] = filas;
    });
    return salida;
  }
}
