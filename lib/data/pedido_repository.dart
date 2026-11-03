import 'package:drift/drift.dart';

import 'app_database.dart';

/// Estados de pedido persistidos en `pedidos.estado`.
class EstadosPedido {
  static const pendiente = 'pendiente';
  static const enProceso = 'en proceso';
  static const completado = 'completado';
  static const cancelado = 'cancelado';

  static const valores = <String>[
    pendiente,
    enProceso,
    completado,
    cancelado,
  ];

  static bool esValido(String estado) => valores.contains(estado);

  static String etiqueta(String estado) {
    final limpio = estado.trim();
    if (limpio.isEmpty) return 'Sin estado';
    if (limpio == 'en_proceso') return 'En proceso';
    return limpio[0].toUpperCase() + limpio.substring(1);
  }
}

/// Total de un pedido: precio de venta por cantidad.
/// La seña no se resta de este importe.
double calcularMontoTotal(Iterable<({double precioVenta, int cantidad})> lineas) {
  var total = 0.0;
  for (final linea in lineas) {
    total += linea.precioVenta * linea.cantidad;
  }
  return total;
}

class ClientePedido {
  final int id;
  final String nombre;

  const ClientePedido({required this.id, required this.nombre});
}

class ProductoPedidoOpcion {
  final int id;
  final String nombre;
  final double precioVenta;

  const ProductoPedidoOpcion({
    required this.id,
    required this.nombre,
    required this.precioVenta,
  });
}

/// Línea para crear un pedido. Si [productoId] es null, se crea el producto
/// mínimo (nombre + precio de venta) o se reutiliza uno con el mismo nombre.
class LineaPedidoBorrador {
  final int? productoId;
  final String? nombreNuevo;
  final double? precioVenta;
  final int cantidad;

  const LineaPedidoBorrador({
    this.productoId,
    this.nombreNuevo,
    this.precioVenta,
    required this.cantidad,
  });
}

class ItemPedido {
  final int productoId;
  final String nombre;
  final int cantidad;
  final double precioVenta;

  const ItemPedido({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioVenta,
  });

  double get subtotal => precioVenta * cantidad;
}

class CambioEstadoPedido {
  final int id;
  final String estadoAnterior;
  final String estadoNuevo;
  final DateTime fechaCambio;

  const CambioEstadoPedido({
    required this.id,
    required this.estadoAnterior,
    required this.estadoNuevo,
    required this.fechaCambio,
  });
}

class PedidoResumen {
  final int id;
  final int clienteId;
  final String clienteNombre;
  final DateTime fecha;
  final String estado;
  final double montoSenado;
  final List<ItemPedido> items;
  final List<CambioEstadoPedido> historial;

  const PedidoResumen({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.fecha,
    required this.estado,
    required this.montoSenado,
    required this.items,
    required this.historial,
  });

  double get montoTotal => calcularMontoTotal(
        items.map(
          (item) => (precioVenta: item.precioVenta, cantidad: item.cantidad),
        ),
      );
}

class PedidoRepository {
  final AppDatabase db;

  PedidoRepository(this.db);

  Future<List<ClientePedido>> listarClientes() async {
    final filas = await db.select(db.clientes).get();
    final clientes = filas
        .map((c) => ClientePedido(id: c.id, nombre: c.nombre))
        .toList();
    clientes.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return clientes;
  }

  Future<List<ProductoPedidoOpcion>> listarProductos() async {
    final filas = await db.select(db.productos).get();
    final productos = filas
        .map(
          (p) => ProductoPedidoOpcion(
            id: p.id,
            nombre: p.nombre,
            precioVenta: p.precioVenta,
          ),
        )
        .toList();
    productos.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return productos;
  }

  /// Crea un producto con nombre y precio de venta.
  /// Si ya hay uno con el mismo nombre, devuelve ese id.
  Future<int> crearProductoMinimo({
    required String nombre,
    required double precioVenta,
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw ArgumentError('El producto necesita un nombre');
    }
    final existente = await _buscarProductoPorNombre(limpio);
    if (existente != null) return existente;
    if (precioVenta < 0) {
      throw ArgumentError('El precio de venta no puede ser negativo');
    }
    return db.into(db.productos).insert(
          ProductosCompanion.insert(
            nombre: limpio,
            precioVenta: Value(precioVenta),
          ),
        );
  }

  Future<List<PedidoResumen>> listarPedidos() async {
    final pedidos = await db.select(db.pedidos).get();
    final clientes = await db.select(db.clientes).get();
    final productos = await db.select(db.productos).get();
    final lineas = await db.select(db.productosPedido).get();
    final historial = await db.select(db.historialPedidos).get();

    final nombreCliente = {for (final c in clientes) c.id: c.nombre};
    final productoPorId = {for (final p in productos) p.id: p};

    final resumenes = pedidos.map((pedido) {
      final items = lineas.where((l) => l.pedidoId == pedido.id).map((l) {
        final producto = productoPorId[l.productoId];
        return ItemPedido(
          productoId: l.productoId,
          nombre: producto?.nombre ?? 'Producto ${l.productoId}',
          cantidad: l.cantidad,
          precioVenta: producto?.precioVenta ?? 0,
        );
      }).toList();

      final cambios = historial.where((h) => h.pedidoId == pedido.id).map((h) {
        return CambioEstadoPedido(
          id: h.id,
          estadoAnterior: h.estadoAnterior,
          estadoNuevo: h.estadoNuevo,
          fechaCambio: h.fechaCambio,
        );
      }).toList()
        ..sort((a, b) {
          final porFecha = b.fechaCambio.compareTo(a.fechaCambio);
          if (porFecha != 0) return porFecha;
          return b.id.compareTo(a.id);
        });

      return PedidoResumen(
        id: pedido.id,
        clienteId: pedido.clienteId,
        clienteNombre: nombreCliente[pedido.clienteId] ??
            'Cliente ${pedido.clienteId}',
        fecha: pedido.fecha,
        estado: pedido.estado,
        montoSenado: pedido.montoSenado,
        items: items,
        historial: cambios,
      );
    }).toList();

    resumenes.sort((a, b) {
      final porFecha = b.fecha.compareTo(a.fecha);
      if (porFecha != 0) return porFecha;
      return b.id.compareTo(a.id);
    });
    return resumenes;
  }

  Future<PedidoResumen?> obtenerPedido(int id) async {
    final pedidos = await listarPedidos();
    for (final pedido in pedidos) {
      if (pedido.id == id) return pedido;
    }
    return null;
  }

  Future<int> crearPedido({
    required int clienteId,
    required double montoSenado,
    required List<LineaPedidoBorrador> lineas,
    DateTime? fecha,
  }) {
    if (montoSenado < 0) {
      throw ArgumentError('La seña no puede ser negativa');
    }
    if (lineas.isEmpty) {
      throw ArgumentError('El pedido necesita al menos un producto');
    }
    return db.transaction(() async {
      final cliente = await (db.select(db.clientes)
            ..where((c) => c.id.equals(clienteId)))
          .getSingleOrNull();
      if (cliente == null) {
        throw StateError('El cliente no existe');
      }

      final pedidoId = await db.into(db.pedidos).insert(
            PedidosCompanion.insert(
              clienteId: clienteId,
              fecha: Value(fecha ?? DateTime.now()),
              estado: const Value(EstadosPedido.pendiente),
              montoSenado: Value(montoSenado),
            ),
          );

      final cantidades = <int, int>{};
      for (final linea in lineas) {
        if (linea.cantidad <= 0) {
          throw ArgumentError('La cantidad debe ser mayor a cero');
        }
        final productoId = await _resolverProducto(linea);
        cantidades.update(
          productoId,
          (actual) => actual + linea.cantidad,
          ifAbsent: () => linea.cantidad,
        );
      }

      for (final entry in cantidades.entries) {
        await db.into(db.productosPedido).insert(
              ProductosPedidoCompanion.insert(
                pedidoId: pedidoId,
                productoId: entry.key,
                cantidad: entry.value,
              ),
            );
      }
      return pedidoId;
    });
  }

  /// Actualiza el estado y deja una fila en `historial_pedidos`.
  Future<void> cambiarEstado(int pedidoId, String nuevoEstado) {
    if (!EstadosPedido.esValido(nuevoEstado)) {
      throw ArgumentError('Estado no válido');
    }
    return db.transaction(() async {
      final pedido = await (db.select(db.pedidos)
            ..where((p) => p.id.equals(pedidoId)))
          .getSingleOrNull();
      if (pedido == null) {
        throw StateError('El pedido no existe');
      }
      if (pedido.estado == nuevoEstado) return;

      await (db.update(db.pedidos)..where((p) => p.id.equals(pedidoId))).write(
        PedidosCompanion(estado: Value(nuevoEstado)),
      );
      await db.into(db.historialPedidos).insert(
            HistorialPedidosCompanion.insert(
              pedidoId: pedidoId,
              estadoAnterior: pedido.estado,
              estadoNuevo: nuevoEstado,
              fechaCambio: Value(DateTime.now()),
            ),
          );
    });
  }

  Future<void> eliminarPedido(int pedidoId) {
    return db.transaction(() async {
      await (db.delete(db.historialPedidos)
            ..where((h) => h.pedidoId.equals(pedidoId)))
          .go();
      await (db.delete(db.productosPedido)
            ..where((l) => l.pedidoId.equals(pedidoId)))
          .go();
      await (db.delete(db.pedidos)..where((p) => p.id.equals(pedidoId))).go();
    });
  }

  Future<int> _resolverProducto(LineaPedidoBorrador linea) async {
    final productoId = linea.productoId;
    if (productoId != null) {
      final existe = await (db.select(db.productos)
            ..where((p) => p.id.equals(productoId)))
          .getSingleOrNull();
      if (existe == null) {
        throw StateError('El producto no existe');
      }
      return existe.id;
    }
    return crearProductoMinimo(
      nombre: linea.nombreNuevo ?? '',
      precioVenta: linea.precioVenta ?? -1,
    );
  }

  Future<int?> _buscarProductoPorNombre(String nombre) async {
    final clave = nombre.trim().toLowerCase();
    final productos = await db.select(db.productos).get();
    for (final producto in productos) {
      if (producto.nombre.trim().toLowerCase() == clave) {
        return producto.id;
      }
    }
    return null;
  }
}
