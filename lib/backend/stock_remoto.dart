import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'ids_remotos.dart';
import 'remoto_comun.dart';

/// Precios locales que se copian a `productos`.
///
/// [pisarCompra] y [pisarVenta] en false no pisan un producto que ya existe:
/// solo sirven de valor inicial si hay que crearlo.
class DatosProductoRemoto {
  const DatosProductoRemoto({
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    required this.pisarCompra,
    required this.pisarVenta,
    this.localId,
    this.pisarNombre = false,
    this.descripcion,
    this.visibleEnTienda,
    this.activo,
    this.sku,
    this.umbral,
    this.controlaSerie,
  });

  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final bool pisarCompra;
  final bool pisarVenta;

  /// Id de Drift. Si está, el uuid queda en [IdsRemotos] y no se duplica.
  final int? localId;
  final bool pisarNombre;

  /// Null: no se toca esa columna. La foto base64 no se manda nunca.
  final String? descripcion;
  final bool? visibleEnTienda;
  final bool? activo;
  final String? sku;
  final int? umbral;
  final bool? controlaSerie;
}

/// Movimiento ya aceptado en Drift. [saldo] es el balance local de ese
/// propietario después del movimiento y tiene que ser >= 0.
class DatosMovimientoRemoto {
  const DatosMovimientoRemoto({
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    required this.pisarCompra,
    required this.pisarVenta,
    required this.propietario,
    required this.cantidad,
    required this.saldo,
    required this.tipo,
    required this.descripcion,
    this.productoLocalId,
    this.movimientoLocalId,
  });

  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final bool pisarCompra;
  final bool pisarVenta;
  final String propietario;
  final int cantidad;
  final int saldo;
  final String tipo;
  final String descripcion;
  final int? productoLocalId;
  final int? movimientoLocalId;
}

/// Junta las copias que nacen dentro de una transacción de Drift y las
/// manda recién cuando esa transacción confirmó. Si revierte, se descartan:
/// la nube no se entera de un stock que el dispositivo no guardó.
class _PendientesReplica {
  final items = <Future<void> Function()>[];
}

class ReplicaScope {
  static _PendientesReplica? get _pendientes {
    final valor = Zone.current[#gexiReplicaPendiente];
    if (valor is _PendientesReplica) return valor;
    return null;
  }

  static bool get anidado => _pendientes != null;

  static Future<T> agrupar<T>(Future<T> Function() accion) {
    final pendientes = _PendientesReplica();
    return runZoned(() async {
      try {
        final resultado = await accion();
        final copia = List<Future<void> Function()>.of(pendientes.items);
        pendientes.items.clear();
        for (final item in copia) {
          RemotoComun.enSegundoPlano(item);
        }
        return resultado;
      } catch (_) {
        pendientes.items.clear();
        rethrow;
      }
    }, zoneValues: {#gexiReplicaPendiente: pendientes});
  }

  /// Fuera de [agrupar] sale enseguida (el local ya confirmó).
  /// Adentro espera a que confirme la transacción que envuelve la llamada.
  static void diferir(Future<void> Function() accion) {
    final pendientes = _pendientes;
    if (pendientes == null) {
      RemotoComun.enSegundoPlano(accion);
      return;
    }
    pendientes.items.add(accion);
  }
}

/// Copia productos, saldos y movimientos a Supabase.
///
/// No lanza: si no hay remoto o la red falla, Drift queda como está.
class StockRemoto {
  const StockRemoto._();

  static Future<void> replicarProducto(DatosProductoRemoto datos) async {
    if (!RemotoComun.activo) return;
    try {
      await _guardarProductoSolo(datos).timeout(const Duration(seconds: 15));
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar el producto en la nube: $error');
    }
  }

  static Future<Object?> asegurarProducto(DatosProductoRemoto datos) async {
    if (!RemotoComun.activo) return null;
    try {
      return await _guardarProductoSolo(datos);
    } catch (error) {
      RemotoComun.aviso('No se pudo asegurar el producto en la nube: $error');
      return null;
    }
  }

  /// Deja el saldo del propietario sin anotar otro movimiento.
  /// Lo usa la bajada: el local gana y se vuelve a empujar.
  static Future<void> publicarSaldo({
    required int productoLocalId,
    required String nombre,
    required double precioCompra,
    required double precioVenta,
    required String propietario,
    required int saldo,
  }) async {
    if (!RemotoComun.activo || saldo < 0) return;
    final dueno = propietario.trim();
    if (dueno.isEmpty) return;
    try {
      final supabase = RemotoComun.cliente;
      if (supabase == null) return;
      final negocioId = await RemotoComun.negocioId();
      if (negocioId == null) return;
      final productoId = await _guardarProducto(
        supabase,
        negocioId,
        DatosProductoRemoto(
          localId: productoLocalId,
          nombre: nombre,
          precioCompra: precioCompra,
          precioVenta: precioVenta,
          pisarCompra: true,
          pisarVenta: true,
          pisarNombre: true,
          activo: true,
        ),
      );
      if (productoId == null) return;
      await _guardarSaldo(
        supabase: supabase,
        negocioId: negocioId,
        productoId: productoId,
        propietario: dueno,
        saldo: saldo,
      );
    } catch (error) {
      RemotoComun.aviso('No se pudo actualizar el stock en la nube: $error');
    }
  }

  static Future<void> replicarMovimiento(DatosMovimientoRemoto datos) async {
    if (!RemotoComun.activo) return;
    try {
      await _movimiento(datos).timeout(const Duration(seconds: 15));
    } catch (error) {
      RemotoComun.aviso('No se pudo registrar el movimiento de stock: $error');
    }
  }
}

Future<Object?> _guardarProductoSolo(DatosProductoRemoto datos) async {
  final supabase = RemotoComun.cliente;
  if (supabase == null) return null;
  final negocioId = await RemotoComun.negocioId();
  if (negocioId == null) return null;
  return _guardarProducto(supabase, negocioId, datos);
}

Future<Object?> _guardarProducto(
  SupabaseClient supabase,
  Object negocioId,
  DatosProductoRemoto datos,
) async {
  final nombre = datos.nombre.trim();
  if (nombre.isEmpty) return null;
  final compra = _precioSeguro(datos.precioCompra);
  final venta = _precioSeguro(datos.precioVenta);
  const ids = IdsRemotos();

  Object? id;
  final localId = datos.localId;
  if (localId != null) {
    id = await ids.leer(IdsRemotos.producto, '$localId');
  }
  id ??= await _buscarProductoId(supabase, negocioId, nombre);
  if (id != null) {
    final cambios = _cambiosProducto(datos, compra, venta);
    if (cambios.isNotEmpty) {
      await supabase.from('productos').update(cambios).eq('id', id);
    }
    if (localId != null) {
      await ids.guardar(IdsRemotos.producto, '$localId', '$id');
    }
    return id;
  }

  final fila = <String, dynamic>{
    'negocio_id': negocioId,
    'nombre': nombre,
    'precio_compra': compra,
    'precio_venta': venta,
    'activo': datos.activo ?? true,
  };
  final descripcion = datos.descripcion;
  if (descripcion != null) fila['descripcion'] = descripcion.trim();
  if (datos.visibleEnTienda != null) {
    fila['visible_en_tienda'] = datos.visibleEnTienda;
  }
  final sku = datos.sku?.trim();
  if (sku != null && sku.isNotEmpty) fila['sku'] = sku;
  if (datos.umbral != null && datos.umbral! >= 0) {
    fila['umbral_stock_bajo'] = datos.umbral;
  }
  if (datos.controlaSerie != null) fila['controla_serie'] = datos.controlaSerie;

  final creada = await supabase
      .from('productos')
      .insert(fila)
      .select('id')
      .single();
  final nuevo = creada['id'];
  if (nuevo == null) return null;
  if (nuevo is String && nuevo.trim().isEmpty) return null;
  if (localId != null) {
    await ids.guardar(IdsRemotos.producto, '$localId', '$nuevo');
  }
  return nuevo;
}

Map<String, dynamic> _cambiosProducto(
  DatosProductoRemoto datos,
  double compra,
  double venta,
) {
  final cambios = <String, dynamic>{};
  if (datos.pisarNombre) cambios['nombre'] = datos.nombre.trim();
  if (datos.pisarCompra) cambios['precio_compra'] = compra;
  if (datos.pisarVenta) cambios['precio_venta'] = venta;
  if (datos.descripcion != null) {
    cambios['descripcion'] = datos.descripcion!.trim();
  }
  if (datos.visibleEnTienda != null) {
    cambios['visible_en_tienda'] = datos.visibleEnTienda;
  }
  if (datos.activo != null) cambios['activo'] = datos.activo;
  final sku = datos.sku?.trim();
  if (sku != null && sku.isNotEmpty) cambios['sku'] = sku;
  if (datos.umbral != null && datos.umbral! >= 0) {
    cambios['umbral_stock_bajo'] = datos.umbral;
  }
  if (datos.controlaSerie != null) {
    cambios['controla_serie'] = datos.controlaSerie;
  }
  return cambios;
}

Future<Object?> _buscarProductoId(
  SupabaseClient supabase,
  Object negocioId,
  String nombre,
) async {
  final exactas = await supabase
      .from('productos')
      .select('id, nombre')
      .eq('negocio_id', negocioId)
      .eq('nombre', nombre);
  final exacto = _menorId(exactas, nombre);
  if (exacto != null) return exacto;

  final parecidas = await supabase
      .from('productos')
      .select('id, nombre')
      .eq('negocio_id', negocioId)
      .ilike('nombre', nombre);
  return _menorId(parecidas, nombre);
}

Object? _menorId(List<dynamic> filas, String nombre) {
  final clave = nombre.trim().toLowerCase();
  Object? elegido;
  String? texto;
  for (final raw in filas) {
    if (raw is! Map) continue;
    final actual = '${raw['nombre']}'.trim().toLowerCase();
    if (actual != clave) continue;
    final id = raw['id'];
    if (id == null) continue;
    if (id is String && id.trim().isEmpty) continue;
    final candidato = '$id';
    if (elegido == null || candidato.compareTo(texto!) < 0) {
      elegido = id;
      texto = candidato;
    }
  }
  return elegido;
}

Future<void> _movimiento(DatosMovimientoRemoto datos) async {
  if (datos.saldo < 0 || datos.cantidad <= 0) return;
  final tipo = datos.tipo.trim().toLowerCase();
  if (tipo != 'entrada' && tipo != 'salida') return;
  final propietario = datos.propietario.trim();
  if (propietario.isEmpty) return;

  const ids = IdsRemotos();
  final movimientoLocalId = datos.movimientoLocalId;
  if (movimientoLocalId != null) {
    final ya = await ids.leer(IdsRemotos.movimientoStock, '$movimientoLocalId');
    if (ya != null) return;
  }

  final supabase = RemotoComun.cliente;
  if (supabase == null) return;
  final negocioId = await RemotoComun.negocioId();
  if (negocioId == null) return;

  final productoId = await _guardarProducto(
    supabase,
    negocioId,
    DatosProductoRemoto(
      nombre: datos.nombre,
      precioCompra: datos.precioCompra,
      precioVenta: datos.precioVenta,
      pisarCompra: datos.pisarCompra,
      pisarVenta: datos.pisarVenta,
      localId: datos.productoLocalId,
    ),
  );
  if (productoId == null) return;

  // El saldo sale de Drift, que ya rechazó el negativo. No se manda otro.
  await _guardarSaldo(
    supabase: supabase,
    negocioId: negocioId,
    productoId: productoId,
    propietario: propietario,
    saldo: datos.saldo,
  );

  final movimiento = <String, dynamic>{
    'negocio_id': negocioId,
    'producto_id': productoId,
    'propietario': propietario,
    'cantidad': datos.cantidad,
    'tipo': tipo,
  };
  final nota = datos.descripcion.trim();
  if (nota.isNotEmpty) movimiento['descripcion'] = nota;
  final creada = await supabase
      .from('movimientos_stock')
      .insert(movimiento)
      .select('id')
      .single();
  final nuevo = creada['id'];
  if (movimientoLocalId != null && nuevo != null && '$nuevo'.trim().isNotEmpty) {
    await ids.guardar(IdsRemotos.movimientoStock, '$movimientoLocalId', '$nuevo');
  }
}

Future<void> _guardarSaldo({
  required SupabaseClient supabase,
  required Object negocioId,
  required Object productoId,
  required String propietario,
  required int saldo,
}) async {
  if (saldo < 0) return;
  final filas = await supabase
      .from('stock')
      .select('id')
      .eq('negocio_id', negocioId)
      .eq('producto_id', productoId)
      .eq('propietario', propietario)
      .limit(1);
  if (filas.isEmpty) {
    await supabase.from('stock').insert({
      'negocio_id': negocioId,
      'producto_id': productoId,
      'propietario': propietario,
      'cantidad': saldo,
    });
    return;
  }
  final id = filas.first['id'];
  if (id == null) return;
  await supabase.from('stock').update({'cantidad': saldo}).eq('id', id);
}

double _precioSeguro(double valor) {
  if (valor.isNaN || valor.isInfinite || valor < 0) return 0;
  return valor;
}
