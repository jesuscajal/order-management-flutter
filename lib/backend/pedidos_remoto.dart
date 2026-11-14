import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ids_remotos.dart';
import 'remoto_comun.dart';
import 'stock_remoto.dart';

/// Línea ya guardada en Drift, lista para `productos_pedido`.
class LineaPedidoRemota {
  const LineaPedidoRemota({
    required this.nombre,
    required this.cantidad,
    required this.precioVenta,
    required this.precioCompra,
    this.productoLocalId,
    this.variante = '',
    this.unidad = '',
  });

  final String nombre;
  final int cantidad;
  final double precioVenta;
  final double precioCompra;
  final int? productoLocalId;
  final String variante;
  final String unidad;
}

/// Pedido local que se copia después de un alta o un cambio de estado.
///
/// [estadoAnterior] va solo en el cambio. El alta no escribe historial,
/// igual que Drift.
class DatosPedidoRemoto {
  const DatosPedidoRemoto({
    required this.pedidoLocalId,
    required this.clienteNombre,
    required this.estado,
    required this.senia,
    required this.total,
    required this.lineas,
    this.estadoAnterior,
    this.clienteLocalId,
    this.origen,
    this.medioPago,
    this.nota,
  });

  final int pedidoLocalId;
  final String clienteNombre;
  final String estado;
  final String? estadoAnterior;
  final double senia;
  final double total;
  final List<LineaPedidoRemota> lineas;
  final int? clienteLocalId;

  /// local, tienda, asistente o manual. `venta` se guarda como local.
  final String? origen;

  /// efectivo, transferencia, otro o fiado.
  final String? medioPago;
  final String? nota;
}

/// Copia pedidos a `pedidos`, `productos_pedido` e `historial_pedidos`.
///
/// Si no hay Supabase, no hay sesión o no hay negocio del usuario, no hace
/// nada y no lanza. El pedido local no se deshace.
class PedidosRemoto {
  const PedidosRemoto._();

  static Future<void> replicarAlta(DatosPedidoRemoto datos) async {
    if (!RemotoComun.activo) return;
    try {
      await _alta(datos).timeout(const Duration(seconds: 20));
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar el pedido en la nube: $error');
    }
  }

  static Future<void> replicarCambio(DatosPedidoRemoto datos) async {
    if (!RemotoComun.activo) return;
    try {
      await _cambio(datos).timeout(const Duration(seconds: 20));
    } catch (error) {
      RemotoComun.aviso('No se pudo actualizar el pedido en la nube: $error');
    }
  }

  static Future<void> borrar(int pedidoLocalId) async {
    if (!RemotoComun.activo) return;
    try {
      final supabase = RemotoComun.cliente;
      final negocioId = await RemotoComun.negocioId();
      if (supabase == null || negocioId == null) return;
      final id = await _idPedido(negocioId, pedidoLocalId);
      if (id == null) return;
      await supabase.from('pedidos').delete().eq('id', id);
      await const IdsRemotos().olvidar(IdsRemotos.pedido, '$pedidoLocalId');
    } catch (error) {
      RemotoComun.aviso('No se pudo borrar el pedido en la nube: $error');
    }
  }

  /// Medio, origen y fiado se anotan después del alta, cuando la ficha local ya existe.
  static Future<void> completarMeta({
    required int pedidoLocalId,
    required String origen,
    required String medioPago,
    required bool fiado,
  }) async {
    if (!RemotoComun.activo) return;
    try {
      final supabase = RemotoComun.cliente;
      final negocioId = await RemotoComun.negocioId();
      if (supabase == null || negocioId == null) return;
      final id = await _idPedido(negocioId, pedidoLocalId);
      if (id == null) return;
      final cambios = <String, dynamic>{};
      final origenRemoto = _origenRemoto(origen);
      final medio = _medioRemoto(medio: medioPago, fiado: fiado);
      if (origenRemoto != null) {
        cambios['origen'] = origenRemoto;
        cambios['categoria'] = _categoriaRemota(origenRemoto);
      }
      if (medio != null) cambios['medio_pago'] = medio;
      if (cambios.isEmpty) return;
      await _actualizarFila(supabase, id, cambios);
    } catch (error) {
      RemotoComun.aviso('No se pudo actualizar el medio del pedido: $error');
    }
  }
}

Future<void> _alta(DatosPedidoRemoto datos) async {
  final supabase = RemotoComun.cliente;
  if (supabase == null) return;
  final negocioId = await RemotoComun.negocioId();
  if (negocioId == null) return;
  final conocido = await _idPedido(negocioId, datos.pedidoLocalId);
  if (conocido != null) {
    final sigue = await supabase
        .from('pedidos')
        .select('id')
        .eq('id', conocido)
        .limit(1);
    if (sigue.isNotEmpty) {
      await _actualizarPedido(
        supabase,
        conocido,
        datos,
        conHistorial: false,
      );
      return;
    }
  }
  await _insertarPedido(
    supabase,
    negocioId,
    datos,
    conHistorial: false,
  );
}

Future<void> _cambio(DatosPedidoRemoto datos) async {
  final supabase = RemotoComun.cliente;
  if (supabase == null) return;
  final negocioId = await RemotoComun.negocioId();
  if (negocioId == null) return;

  final ref = await _buscarPedido(supabase, negocioId, datos);
  if (ref.ambiguo) return;
  if (ref.id != null) {
    await _actualizarPedido(supabase, ref.id!, datos, conHistorial: true);
    return;
  }
  await _insertarPedido(
    supabase,
    negocioId,
    datos,
    conHistorial: true,
  );
}

Future<String?> _idPedido(String negocioId, int localId) async {
  final guardado = await const IdsRemotos().leer(IdsRemotos.pedido, '$localId');
  if (guardado != null) return guardado;
  final viejo = await _MapaPedidos.leer(negocioId, localId);
  if (viejo == null) return null;
  final texto = '$viejo'.trim();
  return texto.isEmpty ? null : texto;
}

class _RefPedido {
  const _RefPedido.encontrado(this.id) : ambiguo = false;
  const _RefPedido.ambiguo()
      : id = null,
        ambiguo = true;
  const _RefPedido.falta()
      : id = null,
        ambiguo = false;

  final Object? id;
  final bool ambiguo;
}

Future<_RefPedido> _buscarPedido(
  SupabaseClient supabase,
  Object negocioId,
  DatosPedidoRemoto datos,
) async {
  final guardado = await _idPedido('$negocioId', datos.pedidoLocalId);
  if (guardado != null) {
    final sigue =
        await supabase.from('pedidos').select('id').eq('id', guardado).limit(1);
    if (sigue.isNotEmpty) {
      await const IdsRemotos()
          .guardar(IdsRemotos.pedido, '${datos.pedidoLocalId}', guardado);
      return _RefPedido.encontrado(guardado);
    }
  }

  final filas = await supabase
      .from('pedidos')
      .select('id, cliente_nombre, estado, senia, total')
      .eq('negocio_id', negocioId);
  final candidatos = <Map<String, dynamic>>[];
  for (final fila in filas) {
    if (_mismoPedido(fila, datos)) candidatos.add(fila);
  }
  if (candidatos.isEmpty) return const _RefPedido.falta();

  Map<String, dynamic>? elegido;
  if (candidatos.length == 1) {
    elegido = candidatos.first;
  } else if (datos.estadoAnterior != null) {
    final anterior = datos.estadoAnterior!.trim().toLowerCase();
    final conEstado = candidatos.where((fila) {
      return '${fila['estado']}'.trim().toLowerCase() == anterior;
    }).toList();
    if (conEstado.length == 1) elegido = conEstado.first;
  }
  final id = elegido == null ? null : elegido['id'];
  if (id == null) return const _RefPedido.ambiguo();
  await _MapaPedidos.guardar(negocioId, datos.pedidoLocalId, id);
  return _RefPedido.encontrado(id);
}

bool _mismoPedido(Map<String, dynamic> fila, DatosPedidoRemoto datos) {
  final nombre = '${fila['cliente_nombre']}'.trim().toLowerCase();
  if (nombre != datos.clienteNombre.trim().toLowerCase()) return false;
  return _mismoImporte(fila['senia'], datos.senia) &&
      _mismoImporte(fila['total'], datos.total);
}

bool _mismoImporte(Object? crudo, double esperado) {
  final valor = _decimal(crudo);
  return (valor - esperado).abs() < 0.02;
}

double _decimal(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse('$valor') ?? 0;
}

Future<void> _insertarPedido(
  SupabaseClient supabase,
  Object negocioId,
  DatosPedidoRemoto datos, {
  required bool conHistorial,
}) async {
  final cliente = datos.clienteNombre.trim();
  final estado = datos.estado.trim();
  if (cliente.isEmpty || estado.isEmpty) return;
  if (datos.senia.isNaN || datos.senia.isInfinite || datos.senia < 0) return;
  final total = datos.total.isNaN || datos.total.isInfinite || datos.total < 0
      ? 0.0
      : datos.total;

  final fila = <String, dynamic>{
    'negocio_id': negocioId,
    'cliente_nombre': cliente,
    'estado': estado,
    'senia': datos.senia,
    'total': total,
  };
  final origen = _origenRemoto(datos.origen);
  final medio = _medioRemoto(medio: datos.medioPago, fiado: false);
  final nota = datos.nota?.trim();
  if (origen != null) {
    fila['origen'] = origen;
    fila['categoria'] = _categoriaRemota(origen);
  }
  if (medio != null) fila['medio_pago'] = medio;
  if (nota != null && nota.isNotEmpty) fila['nota'] = nota;
  final actor = supabase.auth.currentUser?.email?.trim() ?? '';
  if (actor.isNotEmpty) fila['usuario_email'] = actor;
  final clienteUuid = await _clienteUuid(datos.clienteLocalId);
  if (clienteUuid != null) fila['cliente_id'] = clienteUuid;

  final creada = await _insertarFila(supabase, fila);
  final id = creada['id'];
  if (id == null) return;
  await _MapaPedidos.guardar(negocioId, datos.pedidoLocalId, id);
  await const IdsRemotos()
      .guardar(IdsRemotos.pedido, '${datos.pedidoLocalId}', '$id');

  for (final linea in datos.lineas) {
    await _insertarLinea(supabase, id, linea);
  }
  if (conHistorial) {
    await _insertarHistorial(supabase, id, datos);
  }
}

Future<void> _insertarLinea(
  SupabaseClient supabase,
  Object pedidoId,
  LineaPedidoRemota linea,
) async {
  final nombre = linea.nombre.trim();
  if (nombre.isEmpty || linea.cantidad <= 0) return;
  final productoId = await StockRemoto.asegurarProducto(
    DatosProductoRemoto(
      localId: linea.productoLocalId,
      nombre: nombre,
      precioCompra: linea.precioCompra,
      precioVenta: linea.precioVenta,
      pisarCompra: true,
      pisarVenta: true,
    ),
  );
  final precio = linea.precioVenta;
  final fila = <String, dynamic>{
    'pedido_id': pedidoId,
    'nombre': nombre,
    'cantidad': linea.cantidad,
    'precio_venta':
        precio.isNaN || precio.isInfinite || precio < 0 ? 0 : precio,
  };
  if (productoId != null) fila['producto_id'] = productoId;
  final variante = await _varianteUuid(linea);
  final unidad = await _unidadUuid(linea);
  if (variante != null) fila['variante_id'] = variante;
  if (unidad != null) fila['unidad_id'] = unidad;
  await supabase.from('productos_pedido').insert(fila);
}

Future<void> _actualizarPedido(
  SupabaseClient supabase,
  Object pedidoId,
  DatosPedidoRemoto datos, {
  required bool conHistorial,
}) async {
  final estado = datos.estado.trim();
  if (estado.isEmpty) return;
  final total = datos.total.isNaN || datos.total.isInfinite || datos.total < 0
      ? 0.0
      : datos.total;
  final cambios = <String, dynamic>{
    'estado': estado,
    'senia': datos.senia,
    'total': total,
    'cliente_nombre': datos.clienteNombre.trim(),
  };
  final origen = _origenRemoto(datos.origen);
  final medio = _medioRemoto(medio: datos.medioPago, fiado: false);
  final nota = datos.nota?.trim();
  if (origen != null) {
    cambios['origen'] = origen;
    cambios['categoria'] = _categoriaRemota(origen);
  }
  if (medio != null) cambios['medio_pago'] = medio;
  if (nota != null && nota.isNotEmpty) cambios['nota'] = nota;
  final clienteUuid = await _clienteUuid(datos.clienteLocalId);
  if (clienteUuid != null) cambios['cliente_id'] = clienteUuid;
  await _actualizarFila(supabase, pedidoId, cambios);
  if (!conHistorial) return;
  final anterior = datos.estadoAnterior?.trim().toLowerCase() ?? '';
  if (anterior.isEmpty || anterior == estado.toLowerCase()) return;
  await _insertarHistorial(supabase, pedidoId, datos);
}

Future<String?> _clienteUuid(int? localId) async {
  if (localId == null) return null;
  return const IdsRemotos().leer(IdsRemotos.cliente, '$localId');
}

Future<String?> _varianteUuid(LineaPedidoRemota linea) async {
  final productoId = linea.productoLocalId;
  final nombre = linea.variante.trim();
  if (productoId == null || nombre.isEmpty) return null;
  return const IdsRemotos().leer(
    IdsRemotos.variante,
    IdsRemotos.claveVariante(productoId, nombre),
  );
}

Future<String?> _unidadUuid(LineaPedidoRemota linea) async {
  final productoId = linea.productoLocalId;
  final codigo = linea.unidad.trim();
  if (productoId == null || codigo.isEmpty) return null;
  return const IdsRemotos().leer(
    IdsRemotos.unidad,
    IdsRemotos.claveUnidad(productoId, codigo),
  );
}

String _categoriaRemota(String origen) =>
    origen == 'tienda' ? 'web' : 'manual';

Future<Map<String, dynamic>> _insertarFila(
  SupabaseClient supabase,
  Map<String, dynamic> fila,
) async {
  try {
    return await supabase.from('pedidos').insert(fila).select('id').single();
  } catch (error) {
    final texto = error.toString().toLowerCase();
    final sinOpcionales = Map<String, dynamic>.from(fila);
    var quito = false;
    if (_columnaCategoriaAusente(error)) {
      sinOpcionales.remove('categoria');
      quito = true;
    }
    if (texto.contains('usuario_email')) {
      sinOpcionales.remove('usuario_email');
      quito = true;
    }
    if (!quito) rethrow;
    return await supabase
        .from('pedidos')
        .insert(sinOpcionales)
        .select('id')
        .single();
  }
}

Future<void> _actualizarFila(
  SupabaseClient supabase,
  Object pedidoId,
  Map<String, dynamic> cambios,
) async {
  try {
    await supabase.from('pedidos').update(cambios).eq('id', pedidoId);
  } catch (error) {
    if (!_columnaCategoriaAusente(error)) rethrow;
    final sinCategoria = Map<String, dynamic>.from(cambios)..remove('categoria');
    if (sinCategoria.isEmpty) return;
    await supabase.from('pedidos').update(sinCategoria).eq('id', pedidoId);
  }
}

bool _columnaCategoriaAusente(Object error) {
  final texto = error.toString().toLowerCase();
  if (!texto.contains('categoria')) return false;
  return texto.contains('pgrst204') ||
      texto.contains('42703') ||
      texto.contains('schema cache') ||
      texto.contains('does not exist') ||
      texto.contains('no existe') ||
      texto.contains('could not find');
}

String? _origenRemoto(String? origen) {
  final clave = (origen ?? '').trim().toLowerCase();
  switch (clave) {
    case 'local':
    case 'tienda':
    case 'asistente':
    case 'manual':
      return clave;
    case 'venta':
      return 'local';
    default:
      return clave.isEmpty ? null : 'local';
  }
}

String? _medioRemoto({required String? medio, required bool fiado}) {
  if (fiado) return 'fiado';
  final clave = (medio ?? '').trim().toLowerCase();
  const validos = {'efectivo', 'transferencia', 'otro', 'fiado'};
  if (validos.contains(clave)) return clave;
  return null;
}

Future<void> _insertarHistorial(
  SupabaseClient supabase,
  Object pedidoId,
  DatosPedidoRemoto datos,
) async {
  final estado = datos.estado.trim();
  if (estado.isEmpty) return;
  final anterior = datos.estadoAnterior?.trim();
  final nota = (anterior == null || anterior.isEmpty)
      ? 'Estado $estado'
      : 'Paso de $anterior a $estado';
  await supabase.from('historial_pedidos').insert({
    'pedido_id': pedidoId,
    'estado': estado,
    'nota': nota,
  });
}

/// El id de Drift no entra en la tabla remota. Este mapa une los dos
/// para que un cambio de estado actualice la misma fila.
void olvidarMapaDePedidos() {
  _MapaPedidos._memoria.clear();
}

class _MapaPedidos {
  static final Map<String, Object> _memoria = {};

  static String _clave(Object negocioId, int localId) =>
      'gexi.pedido.$negocioId.$localId';

  static Future<void> guardar(
    Object negocioId,
    int localId,
    Object remotoId,
  ) async {
    final clave = _clave(negocioId, localId);
    _memoria[clave] = remotoId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(clave, '$remotoId');
    } catch (_) {}
    try {
      await const IdsRemotos()
          .guardar(IdsRemotos.pedido, '$localId', '$remotoId');
    } catch (_) {}
  }

  static Future<Object?> leer(Object negocioId, int localId) async {
    final clave = _clave(negocioId, localId);
    final enMemoria = _memoria[clave];
    if (enMemoria != null) return enMemoria;
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(clave);
      if (guardado == null || guardado.trim().isEmpty) return null;
      _memoria[clave] = guardado;
      return guardado;
    } catch (_) {
      return null;
    }
  }
}
