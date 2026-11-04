import 'package:drift/drift.dart';

import '../backend/stock_remoto.dart';
import 'app_database.dart';

/// Producto con las cantidades de los dos propietarios que muestra la pantalla.
class ProductoStock {
  const ProductoStock({
    this.id,
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    required this.stockYo,
    required this.stockNildo,
  });

  final int? id;
  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final int stockYo;
  final int stockNildo;

  int get stockTotal => stockYo + stockNildo;

  ProductoStock copyWith({
    int? id,
    String? nombre,
    double? precioCompra,
    double? precioVenta,
    int? stockYo,
    int? stockNildo,
  }) {
    return ProductoStock(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precioCompra: precioCompra ?? this.precioCompra,
      precioVenta: precioVenta ?? this.precioVenta,
      stockYo: stockYo ?? this.stockYo,
      stockNildo: stockNildo ?? this.stockNildo,
    );
  }
}

/// Movimiento tal como se muestra en el detalle de un producto.
class MovimientoStockVista {
  const MovimientoStockVista({
    required this.id,
    required this.productoId,
    required this.tipo,
    required this.cantidad,
    required this.propietario,
    required this.fechaCarga,
    this.descripcion,
    this.fechaSalida,
  });

  final int id;
  final int productoId;
  final String tipo;
  final int cantidad;
  final String propietario;
  final String? descripcion;
  final DateTime fechaCarga;
  final DateTime? fechaSalida;
}

class StockException implements Exception {
  StockException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class _Propietarios {
  const _Propietarios({required this.yo, required this.nildo});

  final int yo;
  final int nildo;
}

/// Lectura y escritura de productos, stock y movimientos sobre [AppDatabase].
///
/// No modifica el esquema. Crea los usuarios Yo y Nildo si todavía no existen.
/// Después de cada alta, ajuste o cambio de precio confirmado en Drift,
/// copia a Supabase si hay negocio. Si no hay remoto, el guardado local sigue.
class StockRepository {
  StockRepository(this.db);

  final AppDatabase db;

  static const propietarioYo = 'Yo';
  static const propietarioNildo = 'Nildo';
  static const tipoEntrada = 'entrada';
  static const tipoSalida = 'salida';

  Future<void> _cola = Future<void>.value();

  Future<T> _enOrden<T>(Future<T> Function() accion) {
    final resultado = _cola.then((_) => accion());
    _cola = resultado.then<void>((_) {}, onError: _seguirCola);
    return resultado;
  }

  /// La operación fallida ya se informa a quien la pidió. La cola sigue.
  static void _seguirCola(Object error, StackTrace stackTrace) {
    // [error] y [stackTrace] quedan en el Future que recibe la pantalla.
  }

  Future<List<ProductoStock>> obtenerProductos() {
    return _enOrden(_leerProductos);
  }

  Future<ProductoStock?> obtenerPorId(int id) async {
    final productos = await obtenerProductos();
    for (final producto in productos) {
      if (producto.id == id) return producto;
    }
    return null;
  }

  Future<List<MovimientoStockVista>> movimientosDe(int productoId) {
    return _enOrden(() => _leerMovimientos(productoId));
  }

  /// Alta: crea el producto si no existe, suma cantidad y registra una entrada.
  Future<void> registrarEntrada({
    required String nombre,
    required int cantidad,
    required double precioCompra,
    double? precioVenta,
    required String propietario,
  }) {
    return _enOrden(
      () => _aplicar(
        nombre: nombre.trim(),
        crearSiNoExiste: true,
        actualizarPrecios: true,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
        propietario: propietario,
        cantidad: cantidad,
        esEntrada: true,
        descripcion: 'Alta de stock',
      ),
    );
  }

  /// Ajuste de una cantidad ya cargada. No crea productos ni cambia precios.
  Future<void> registrarAjuste({
    int? productoId,
    required String nombre,
    required int cantidad,
    required String propietario,
    required String tipo,
    String? descripcion,
  }) {
    if (tipo != tipoEntrada && tipo != tipoSalida) {
      throw StockException('El tipo de movimiento debe ser entrada o salida.');
    }
    final esEntrada = tipo == tipoEntrada;
    final texto = descripcion?.trim();
    return _enOrden(
      () => _aplicar(
        productoId: productoId,
        nombre: nombre.trim(),
        crearSiNoExiste: false,
        actualizarPrecios: false,
        propietario: propietario,
        cantidad: cantidad,
        esEntrada: esEntrada,
        descripcion: (texto == null || texto.isEmpty)
            ? (esEntrada ? 'Ajuste de entrada' : 'Ajuste de salida')
            : texto,
      ),
    );
  }

  Future<void> renombrar({
    required int productoId,
    required String nombre,
  }) {
    return _enOrden(() async {
      final limpio = nombre.trim();
      if (limpio.isEmpty) {
        throw StockException('El nombre no puede quedar vacío.');
      }
      final otro = await _buscarPorNombre(limpio);
      if (otro != null && otro.id != productoId) {
        throw StockException('Ya hay un producto con ese nombre.');
      }
      final filas = await (db.update(db.productos)
            ..where((producto) => producto.id.equals(productoId)))
          .write(ProductosCompanion(nombre: Value(limpio)));
      if (filas == 0) {
        throw StockException('No se encontró el producto.');
      }
      final producto = await (db.select(db.productos)
            ..where((fila) => fila.id.equals(productoId)))
          .getSingleOrNull();
      if (producto == null) return;
      ReplicaScope.diferir(
        () => StockRemoto.replicarProducto(
          DatosProductoRemoto(
            localId: producto.id,
            nombre: producto.nombre,
            precioCompra: producto.precioCompra,
            precioVenta: producto.precioVenta,
            pisarCompra: true,
            pisarVenta: true,
            pisarNombre: true,
            activo: true,
          ),
        ),
      );
    });
  }

  Future<void> actualizarPrecios({
    required int productoId,
    required double precioCompra,
    required double precioVenta,
  }) {
    return _enOrden(() async {
      if (precioCompra < 0 || precioVenta < 0) {
        throw StockException('Los precios no pueden ser negativos.');
      }
      final filas = await (db.update(db.productos)
            ..where((producto) => producto.id.equals(productoId)))
          .write(
        ProductosCompanion(
          precioCompra: Value(precioCompra),
          precioVenta: Value(precioVenta),
        ),
      );
      if (filas == 0) {
        throw StockException(
          'No se encontró el producto para actualizar los precios.',
        );
      }
      final producto = await (db.select(db.productos)
            ..where((fila) => fila.id.equals(productoId)))
          .getSingleOrNull();
      if (producto == null) return;
      ReplicaScope.diferir(
        () => StockRemoto.replicarProducto(
          DatosProductoRemoto(
            localId: producto.id,
            nombre: producto.nombre,
            precioCompra: precioCompra,
            precioVenta: precioVenta,
            pisarCompra: true,
            pisarVenta: true,
            activo: true,
          ),
        ),
      );
    });
  }

  Future<List<ProductoStock>> _leerProductos() async {
    final propietarios = await _usuarios();
    final productos = await db.select(db.productos).get();
    final filasStock = await db.select(db.stock).get();
    final cantidades = <int, Map<int, int>>{};

    for (final fila in filasStock) {
      final porUsuario = cantidades.putIfAbsent(fila.productoId, () => {});
      porUsuario.update(
        fila.usuarioId,
        (actual) => actual + fila.cantidadActual,
        ifAbsent: () => fila.cantidadActual,
      );
    }

    final vistas = <ProductoStock>[
      for (final producto in productos)
        ProductoStock(
          id: producto.id,
          nombre: producto.nombre,
          precioCompra: producto.precioCompra,
          precioVenta: producto.precioVenta,
          stockYo: cantidades[producto.id]?[propietarios.yo] ?? 0,
          stockNildo: cantidades[producto.id]?[propietarios.nildo] ?? 0,
        ),
    ];
    vistas.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return vistas;
  }

  Future<List<MovimientoStockVista>> _leerMovimientos(int productoId) async {
    final propietarios = await _usuarios();
    final movimientos = await (db.select(db.movimientosStock)
          ..where((movimiento) => movimiento.productoId.equals(productoId))
          ..orderBy([
            (movimiento) => OrderingTerm.desc(movimiento.fechaCarga),
            (movimiento) => OrderingTerm.desc(movimiento.id),
          ])
          ..limit(50))
        .get();

    return [
      for (final movimiento in movimientos)
        MovimientoStockVista(
          id: movimiento.id,
          productoId: movimiento.productoId,
          tipo: movimiento.tipo,
          cantidad: movimiento.cantidad,
          propietario: _nombrePropietario(propietarios, movimiento.usuarioId),
          descripcion: movimiento.descripcion,
          fechaCarga: movimiento.fechaCarga,
          fechaSalida: movimiento.fechaSalida,
        ),
    ];
  }

  Future<void> _aplicar({
    int? productoId,
    required String nombre,
    required bool crearSiNoExiste,
    required bool actualizarPrecios,
    double? precioCompra,
    double? precioVenta,
    required String propietario,
    required int cantidad,
    required bool esEntrada,
    required String descripcion,
  }) async {
    if (nombre.isEmpty) {
      throw StockException('El nombre del producto es obligatorio.');
    }
    if (cantidad <= 0) {
      throw StockException('La cantidad debe ser mayor a cero.');
    }
    if (precioCompra != null && precioCompra < 0) {
      throw StockException('El precio de compra no puede ser negativo.');
    }
    if (precioVenta != null && precioVenta < 0) {
      throw StockException('El precio de venta no puede ser negativo.');
    }

    final propietarios = await _usuarios();
    final usuarioId = _idPropietario(propietarios, propietario);
    final propietarioCanonico =
        usuarioId == propietarios.yo ? propietarioYo : propietarioNildo;
    int? saldoListo;
    String? nombreListo;
    double? compraLista;
    double? ventaLista;
    int? productoListo;
    int? movimientoListo;

    await db.transaction(() async {
      final idProducto = await _resolverProducto(
        productoId: productoId,
        nombre: nombre,
        crearSiNoExiste: crearSiNoExiste,
        actualizarPrecios: actualizarPrecios,
        precioCompra: precioCompra ?? 0,
        precioVenta: precioVenta,
      );

      final filas = await (db.select(db.stock)
            ..where(
              (fila) =>
                  fila.productoId.equals(idProducto) &
                  fila.usuarioId.equals(usuarioId),
            ))
          .get();
      final actual = filas.fold<int>(
        0,
        (suma, fila) => suma + fila.cantidadActual,
      );
      final nuevo = esEntrada ? actual + cantidad : actual - cantidad;
      if (nuevo < 0) {
        throw StockException('No hay stock suficiente para esa salida.');
      }

      if (filas.isEmpty) {
        await db.into(db.stock).insert(
              StockCompanion.insert(
                productoId: idProducto,
                usuarioId: usuarioId,
                cantidadActual: Value(nuevo),
              ),
            );
      } else {
        await (db.update(db.stock)
              ..where((fila) => fila.id.equals(filas.first.id)))
            .write(StockCompanion(cantidadActual: Value(nuevo)));
        // Sin clave única producto+usuario: si hay filas repetidas, queda
        // una sola con el total para no sumar el stock dos veces.
        for (final extra in filas.skip(1)) {
          await (db.delete(db.stock)..where((fila) => fila.id.equals(extra.id)))
              .go();
        }
      }

      final movimientoId = await db.into(db.movimientosStock).insert(
            MovimientosStockCompanion.insert(
              productoId: idProducto,
              usuarioId: usuarioId,
              tipo: esEntrada ? tipoEntrada : tipoSalida,
              cantidad: cantidad,
              descripcion: Value<String?>(descripcion),
              fechaCarga: Value(DateTime.now()),
              fechaSalida: esEntrada
                  ? const Value<DateTime?>.absent()
                  : Value<DateTime?>(DateTime.now()),
            ),
          );
      movimientoListo = movimientoId;
      productoListo = idProducto;

      final guardado = await (db.select(db.productos)
            ..where((producto) => producto.id.equals(idProducto)))
          .getSingle();
      saldoListo = nuevo;
      nombreListo = guardado.nombre;
      compraLista = guardado.precioCompra;
      ventaLista = guardado.precioVenta;
    });

    final saldo = saldoListo;
    final nombreRemoto = nombreListo;
    final compra = compraLista;
    final venta = ventaLista;
    if (saldo == null ||
        saldo < 0 ||
        nombreRemoto == null ||
        compra == null ||
        venta == null) {
      return;
    }
    ReplicaScope.diferir(
      () => StockRemoto.replicarMovimiento(
        DatosMovimientoRemoto(
          nombre: nombreRemoto,
          precioCompra: compra,
          precioVenta: venta,
          pisarCompra: actualizarPrecios && precioCompra != null,
          pisarVenta: actualizarPrecios && precioVenta != null,
          propietario: propietarioCanonico,
          cantidad: cantidad,
          saldo: saldo,
          tipo: esEntrada ? tipoEntrada : tipoSalida,
          descripcion: descripcion,
          productoLocalId: productoListo,
          movimientoLocalId: movimientoListo,
        ),
      ),
    );
  }

  Future<int> _resolverProducto({
    int? productoId,
    required String nombre,
    required bool crearSiNoExiste,
    required bool actualizarPrecios,
    required double precioCompra,
    double? precioVenta,
  }) async {
    Producto? existente;
    if (productoId != null) {
      existente = await (db.select(db.productos)
            ..where((producto) => producto.id.equals(productoId)))
          .getSingleOrNull();
    }
    existente ??= await _buscarPorNombre(nombre);

    if (existente == null) {
      if (!crearSiNoExiste) {
        throw StockException('No se encontró el producto "$nombre".');
      }
      return db.into(db.productos).insert(
            ProductosCompanion.insert(
              nombre: nombre,
              precioCompra: Value(precioCompra),
              precioVenta: Value(precioVenta ?? 0),
            ),
          );
    }

    if (actualizarPrecios) {
      await (db.update(db.productos)
            ..where((producto) => producto.id.equals(existente!.id)))
          .write(
        ProductosCompanion(
          precioCompra: Value(precioCompra),
          precioVenta:
              precioVenta == null ? const Value.absent() : Value(precioVenta),
        ),
      );
    }
    return existente.id;
  }

  Future<Producto?> _buscarPorNombre(String nombre) async {
    final clave = nombre.trim().toLowerCase();
    final productos = await db.select(db.productos).get();
    Producto? elegido;
    for (final producto in productos) {
      if (producto.nombre.trim().toLowerCase() != clave) continue;
      if (elegido == null || producto.id < elegido.id) {
        elegido = producto;
      }
    }
    return elegido;
  }

  Future<_Propietarios> _usuarios() async {
    return _Propietarios(
      yo: await _idUsuario(propietarioYo),
      nildo: await _idUsuario(propietarioNildo),
    );
  }

  Future<int> _idUsuario(String nombre) async {
    final clave = nombre.trim().toLowerCase();
    final usuarios = await db.select(db.usuarios).get();
    Usuario? elegido;
    for (final usuario in usuarios) {
      if (usuario.nombre.trim().toLowerCase() != clave) continue;
      if (elegido == null || usuario.id < elegido.id) {
        elegido = usuario;
      }
    }
    if (elegido != null) return elegido.id;
    return db.into(db.usuarios).insert(
          UsuariosCompanion.insert(nombre: nombre.trim()),
        );
  }

  int _idPropietario(_Propietarios propietarios, String propietario) {
    final clave = propietario.trim().toLowerCase();
    if (clave == propietarioYo.toLowerCase()) return propietarios.yo;
    if (clave == propietarioNildo.toLowerCase()) return propietarios.nildo;
    throw StockException('El propietario debe ser Yo o Nildo.');
  }

  String _nombrePropietario(_Propietarios propietarios, int usuarioId) {
    if (usuarioId == propietarios.yo) return propietarioYo;
    if (usuarioId == propietarios.nildo) return propietarioNildo;
    return 'Usuario $usuarioId';
  }
}
