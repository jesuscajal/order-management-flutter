import 'package:drift/drift.dart';

import '../backend/clientes_remoto.dart';
import '../backend/pedidos_remoto.dart';
import '../backend/stock_remoto.dart';
import '../models/pedido_estado.dart';
import 'ampliacion_local.dart';
import 'app_database.dart';
import 'capital_repository.dart';
import 'stock_repository.dart';

/// Total de un pedido: precio de venta por cantidad.
/// La seña no se resta de este importe.
double calcularMontoTotal(
  Iterable<({double precioVenta, int cantidad})> lineas,
) {
  var total = 0.0;
  for (final linea in lineas) {
    total += linea.precioVenta * linea.cantidad;
  }
  return total;
}

/// Pesos que se restan del total. [tipo] es `monto` o `porcentaje`.
/// No supera [bruto] y no toca el precio de catálogo.
double descuentoEnDinero({
  required double bruto,
  required String tipo,
  required double valor,
}) {
  if (bruto.isNaN || bruto.isInfinite || bruto <= 0) return 0;
  if (valor.isNaN || valor.isInfinite || valor <= 0) return 0;
  final brutoCent = CapitalRepository.enCentavos(bruto);
  if (brutoCent <= 0) return 0;
  final normalizado = MetaPedido.normalizarDescuento(tipo);
  final int centavos;
  if (normalizado == 'porcentaje') {
    final pct = valor > 100 ? 100.0 : valor;
    centavos = (brutoCent * pct / 100).round();
  } else if (normalizado == 'monto') {
    centavos = CapitalRepository.enCentavos(valor);
  } else {
    return 0;
  }
  final tope = centavos > brutoCent ? brutoCent : (centavos < 0 ? 0 : centavos);
  return tope / 100;
}

/// Total a cobrar de un pedido.
///
/// Si la ampliación guardó variantes o unidades, suma el precio de cada línea.
/// Si no, usa el precio de catálogo, igual que antes.
/// Si el pedido tiene descuento, este importe ya está descontado.
double totalParaCobro({
  required Iterable<({int productoId, int cantidad, double precioCatalogo})>
      lineas,
  MetaPedido? meta,
}) {
  final bruto = _totalBruto(lineas: lineas, meta: meta);
  if (meta == null) return bruto;
  final descuento = meta.descuentoSobre(bruto);
  final neto = CapitalRepository.enCentavos(bruto) -
      CapitalRepository.enCentavos(descuento);
  if (neto <= 0) return 0;
  return neto / 100;
}

double _totalBruto({
  required Iterable<({int productoId, int cantidad, double precioCatalogo})>
      lineas,
  MetaPedido? meta,
}) {
  final detalladas = meta?.lineas ?? const <LineaMeta>[];
  if (detalladas.isEmpty) {
    return calcularMontoTotal([
      for (final linea in lineas)
        (precioVenta: linea.precioCatalogo, cantidad: linea.cantidad),
    ]);
  }
  var total = 0.0;
  final cubiertos = <int, int>{};
  for (final linea in detalladas) {
    total += linea.precio * linea.cantidad;
    cubiertos.update(
      linea.productoId,
      (actual) => actual + linea.cantidad,
      ifAbsent: () => linea.cantidad,
    );
  }
  for (final linea in lineas) {
    final resto = linea.cantidad - (cubiertos[linea.productoId] ?? 0);
    if (resto <= 0) continue;
    total += linea.precioCatalogo * resto;
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

  /// Si es false, [precioVenta] entra en el total y en la deuda, pero no pisa
  /// el precio de venta del catálogo. Las variantes lo usan así.
  final bool pisarPrecioCatalogo;

  const LineaPedidoBorrador({
    this.productoId,
    this.nombreNuevo,
    this.precioVenta,
    required this.cantidad,
    this.pisarPrecioCatalogo = true,
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
    final clientes =
        filas.map((c) => ClientePedido(id: c.id, nombre: c.nombre)).toList();
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
  /// Si ya hay uno con el mismo nombre, devuelve ese id y actualiza el precio.
  ///
  /// `productos_pedido` no tiene columna de precio: el importe vive en
  /// `productos.precio_venta`. Por eso un precio nuevo pisa el del catálogo
  /// y también el total visible de pedidos anteriores de ese producto.
  Future<int> crearProductoMinimo({
    required String nombre,
    required double precioVenta,
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw ArgumentError('El producto necesita un nombre.');
    }
    if (precioVenta < 0) {
      throw ArgumentError('El precio de venta no puede ser negativo.');
    }
    final existente = await _buscarProductoPorNombre(limpio);
    if (existente != null) {
      await _guardarPrecio(existente, precioVenta);
      await _publicarProducto(existente);
      return existente;
    }
    final id = await db.into(db.productos).insert(
          ProductosCompanion.insert(
            nombre: limpio,
            precioVenta: Value(precioVenta),
          ),
        );
    await _publicarProducto(id);
    return id;
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
        clienteNombre:
            nombreCliente[pedido.clienteId] ?? 'Cliente ${pedido.clienteId}',
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

  /// Crea el pedido. Si no hay [clienteId], usa [clienteNombre] y lo da de
  /// alta en `clientes` cuando todavía no existe.
  ///
  /// El estado inicial sale de la seña contra el total ya descontado:
  /// pendiente, pendiente de pago o pagado.
  ///
  /// [descuento] se resta una sola vez. Si queda saldo, la deuda a cobrar
  /// es esa que ya registraba el alta. No se crea otra por fiado.
  ///
  /// Si hay negocio en Supabase, después se copia el pedido. Un fallo de
  /// red no deshace el guardado local ni se muestra como error.
  Future<int> crearPedido({
    int? clienteId,
    String? clienteNombre,
    required double montoSenado,
    required List<LineaPedidoBorrador> lineas,
    DateTime? fecha,
    double descuento = 0,
    String medioPago = '',
    bool fiado = false,
  }) {
    if (montoSenado < 0) {
      throw ArgumentError('La seña no puede ser negativa.');
    }
    if (lineas.isEmpty) {
      throw ArgumentError('El pedido necesita al menos un producto.');
    }
    return ReplicaScope.agrupar(() async {
      final pedidoCreado = await db.transaction(() async {
        final idCliente = await _resolverCliente(
          clienteId: clienteId,
          clienteNombre: clienteNombre,
        );
        final cliente = await (db.select(db.clientes)
              ..where((c) => c.id.equals(idCliente)))
            .getSingle();
        final nombreCliente = cliente.nombre.trim();
        final clienteVisible =
            nombreCliente.isEmpty ? 'Cliente $idCliente' : nombreCliente;

        final cantidades = <int, int>{};
        var total = 0.0;
        for (final linea in lineas) {
          if (linea.cantidad <= 0) {
            throw ArgumentError('La cantidad tiene que ser mayor a cero.');
          }
          final productoId = await _resolverProducto(linea);
          final fila = await (db.select(db.productos)
                ..where((p) => p.id.equals(productoId)))
              .getSingle();
          final precioLinea = linea.precioVenta;
          final precio = precioLinea != null &&
                  !precioLinea.isNaN &&
                  !precioLinea.isInfinite &&
                  precioLinea >= 0
              ? precioLinea
              : fila.precioVenta;
          total += precio * linea.cantidad;
          cantidades.update(
            productoId,
            (actual) => actual + linea.cantidad,
            ifAbsent: () => linea.cantidad,
          );
        }
        if (descuento.isNaN || descuento.isInfinite || descuento < 0) {
          throw ArgumentError('El descuento no puede ser negativo.');
        }
        final brutoCent = CapitalRepository.enCentavos(total);
        final descuentoCent = CapitalRepository.enCentavos(descuento);
        if (descuentoCent > brutoCent) {
          throw ArgumentError('El descuento no puede superar el total.');
        }
        final totalNeto = (brutoCent - descuentoCent) / 100;
        final estado = PedidoEstados.estadoInicial(
          sena: montoSenado,
          total: totalNeto,
        );

        final idNuevo = await db.into(db.pedidos).insert(
              PedidosCompanion.insert(
                clienteId: idCliente,
                fecha: Value(fecha ?? DateTime.now()),
                estado: Value(estado),
                montoSenado: Value(montoSenado),
              ),
            );

        for (final entry in cantidades.entries) {
          await db.into(db.productosPedido).insert(
                ProductosPedidoCompanion.insert(
                  pedidoId: idNuevo,
                  productoId: entry.key,
                  cantidad: entry.value,
                ),
              );
        }
        return (
          id: idNuevo,
          clienteNombre: clienteVisible,
          total: totalNeto,
        );
      });
      final pedidoId = pedidoCreado.id;
      final saldoCentavos = CapitalRepository.enCentavos(pedidoCreado.total) -
          CapitalRepository.enCentavos(montoSenado);
      if (saldoCentavos > 0) {
        try {
          await CapitalRepository(db).registrar(
            persona: pedidoCreado.clienteNombre,
            monto: saldoCentavos / 100,
            tipo: TiposCapital.capitalACobrar,
            descripcion: fiado
                ? 'Fiado · Saldo pendiente del pedido #$pedidoId'
                : MetaPedido.conMedio(
                    'Saldo pendiente del pedido #$pedidoId',
                    medio: medioPago,
                  ),
          );
        } catch (_) {}
      }
      final senaCentavos = CapitalRepository.enCentavos(montoSenado);
      if (senaCentavos > 0) {
        try {
          await CapitalRepository(db).registrar(
            persona: pedidoCreado.clienteNombre,
            monto: senaCentavos / 100,
            tipo: TiposCapital.ventaCobrada,
            descripcion: MetaPedido.conMedio(
              'Seña cobrada del pedido #$pedidoId',
              medio: medioPago,
            ),
          );
        } catch (_) {}
      }
      try {
        final datos = await _datosRemotos(
          pedidoLocalId: pedidoId,
          descuento: descuento,
        );
        ReplicaScope.diferir(() => PedidosRemoto.replicarAlta(datos));
      } catch (_) {}
      return pedidoId;
    });
  }

  /// Actualiza el estado y agrega una fila en `historial_pedidos`.
  /// No borra el historial anterior.
  ///
  /// Al pasar a confirmado o entregado descuenta stock con
  /// [StockRepository.registrarAjuste], que rechaza saldo negativo.
  /// Primero usa el stock de Yo y el resto el de Nildo. Si no alcanza,
  /// la transacción vuelve atrás y el estado no cambia.
  ///
  /// Si la ficha del producto tiene controlaStock en false, esa línea no
  /// descuenta stock ni exige unidades. Las que sí controlan stock siguen igual.
  ///
  /// Al cancelar un pedido `confirmado`, devuelve esas mismas salidas.
  /// Los textos viejos (`en proceso`, `completado`) no se reescriben hasta
  /// que haya una transición, y no se toman como stock ya descontado.
  ///
  /// Con Supabase activo, el estado nuevo y el historial se copian después
  /// de confirmar el cambio local. Si no hay negocio, queda solo en Drift.
  Future<void> cambiarEstado(int pedidoId, String nuevoEstado) {
    final destino = PedidoEstados.leer(nuevoEstado);
    if (destino == null || destino.texto != nuevoEstado.trim().toLowerCase()) {
      throw ArgumentError('Estado no válido.');
    }
    return ReplicaScope.agrupar(() async {
      MutacionAmpliacion? mutacion;
      final anterior = await db.transaction(() async {
        final pedido = await (db.select(db.pedidos)
              ..where((p) => p.id.equals(pedidoId)))
            .getSingleOrNull();
        if (pedido == null) {
          throw StateError('El pedido no existe.');
        }
        if (PedidoEstados.leer(pedido.estado) == destino) return null;
        if (!PedidoEstados.puedePasar(pedido.estado, destino)) {
          throw StateError('Esa transición no está permitida.');
        }

        final yaDesconto = PedidoEstados.yaDescontoStock(pedido.estado);
        if (destino.reservaStock && !yaDesconto) {
          mutacion = await const AmpliacionLocal().prepararDescuento(pedidoId);
          await _descontarStock(pedidoId);
        }
        if (destino == PedidoEstado.cancelado &&
            pedido.estado.trim().toLowerCase() ==
                PedidoEstado.confirmado.texto) {
          mutacion = await const AmpliacionLocal().prepararDevolucion(pedidoId);
          await _devolverStock(pedidoId);
        }

        await (db.update(db.pedidos)..where((p) => p.id.equals(pedidoId)))
            .write(
          PedidosCompanion(estado: Value(destino.texto)),
        );
        await db.into(db.historialPedidos).insert(
              HistorialPedidosCompanion.insert(
                pedidoId: pedidoId,
                estadoAnterior: pedido.estado,
                estadoNuevo: destino.texto,
                fechaCambio: Value(DateTime.now()),
              ),
            );
        return pedido.estado;
      });
      if (anterior == null) return;
      Object? errorFicha;
      final pendiente = mutacion;
      if (pendiente != null) {
        try {
          await const AmpliacionLocal().confirmarMutacion(pendiente);
        } catch (error) {
          errorFicha = error;
        }
      }
      try {
        final datos = await _datosRemotos(
          pedidoLocalId: pedidoId,
          estadoAnterior: anterior,
          estadoNuevo: destino.texto,
        );
        ReplicaScope.diferir(() => PedidosRemoto.replicarCambio(datos));
      } catch (_) {}
      if (errorFicha != null) {
        final detalle = errorFicha is StateError ? errorFicha.message : '';
        throw StateError(
          detalle.isEmpty
              ? 'El estado quedó guardado, pero no pude actualizar la unidad o la variante.'
              : 'El estado quedó guardado, pero no pude actualizar la unidad o la variante. $detalle',
        );
      }
    });
  }

  /// Suma un pago a la seña. No crea otra deuda: descuenta el saldo a cobrar
  /// de esa persona, como máximo hasta lo que todavía debe.
  ///
  /// Si la seña llega al total y el pedido sigue pendiente, pasa a pagado.
  /// Un pago parcial sobre un pendiente lo deja en pendiente de pago.
  Future<void> registrarSena({
    required int pedidoId,
    required double pago,
  }) async {
    if (pago.isNaN || pago.isInfinite || pago <= 0) {
      throw ArgumentError('El pago tiene que ser mayor a cero.');
    }
    final pagoCent = CapitalRepository.enCentavos(pago);
    if (pagoCent <= 0) {
      throw ArgumentError('El pago tiene que ser mayor a cero.');
    }

    final cobro = await db.transaction(() async {
      final pedido = await (db.select(db.pedidos)
            ..where((p) => p.id.equals(pedidoId)))
          .getSingleOrNull();
      if (pedido == null) {
        throw StateError('El pedido no existe.');
      }
      final leido = PedidoEstados.leer(pedido.estado);
      if (leido == null || leido == PedidoEstado.cancelado) {
        throw StateError('Ese pedido no admite un pago.');
      }

      final lineas = await (db.select(db.productosPedido)
            ..where((l) => l.pedidoId.equals(pedidoId)))
          .get();
      final productos = await db.select(db.productos).get();
      final precios = {for (final producto in productos) producto.id: producto.precioVenta};
      final meta = (await const AmpliacionLocal().cargar()).pedidos[pedidoId];
      final total = totalParaCobro(
        lineas: [
          for (final linea in lineas)
            (
              productoId: linea.productoId,
              cantidad: linea.cantidad,
              precioCatalogo: precios[linea.productoId] ?? 0,
            ),
        ],
        meta: meta,
      );
      final anterior = CapitalRepository.enCentavos(pedido.montoSenado);
      final totalCent = CapitalRepository.enCentavos(total);
      final nuevo = anterior + pagoCent;
      if (nuevo > totalCent) {
        throw StateError('El pago supera lo que resta del pedido.');
      }

      String? estadoNuevo;
      if (nuevo == totalCent &&
          (leido == PedidoEstado.pendiente ||
              leido == PedidoEstado.pendienteDePago)) {
        estadoNuevo = PedidoEstado.pagado.texto;
      } else if (anterior == 0 &&
          nuevo < totalCent &&
          leido == PedidoEstado.pendiente) {
        estadoNuevo = PedidoEstado.pendienteDePago.texto;
      }

      await (db.update(db.pedidos)..where((p) => p.id.equals(pedidoId))).write(
        PedidosCompanion(
          montoSenado: Value(nuevo / 100),
          estado: estadoNuevo == null ? const Value.absent() : Value(estadoNuevo),
        ),
      );
      if (estadoNuevo != null) {
        await db.into(db.historialPedidos).insert(
              HistorialPedidosCompanion.insert(
                pedidoId: pedidoId,
                estadoAnterior: pedido.estado,
                estadoNuevo: estadoNuevo,
                fechaCambio: Value(DateTime.now()),
              ),
            );
      }

      final cliente = await (db.select(db.clientes)
            ..where((c) => c.id.equals(pedido.clienteId)))
          .getSingleOrNull();
      return (
        cliente: cliente?.nombre ?? 'Cliente ${pedido.clienteId}',
        estadoAnterior: estadoNuevo == null ? null : pedido.estado,
        estadoNuevo: estadoNuevo,
      );
    });

    try {
      final capital = CapitalRepository(db);
      final meta = (await const AmpliacionLocal().cargar()).pedidos[pedidoId];
      final medio = meta?.medioPago ?? '';
      final filas = await capital.listar();
      final saldo = CapitalRepository.saldoDePersona(
        [
          for (final fila in filas)
            MovimientoParaResumen(
              persona: fila.persona,
              monto: fila.monto,
              tipo: fila.tipo,
            ),
        ],
        cobro.cliente,
      );
      final tope = CapitalRepository.enCentavos(saldo);
      final aplicar = tope < pagoCent ? tope : pagoCent;
      if (aplicar > 0) {
        await capital.registrarPagoParcial(
          persona: cobro.cliente,
          monto: aplicar / 100,
          descripcion: MetaPedido.conMedio(
            'Pago de seña del pedido #$pedidoId',
            medio: medio,
          ),
        );
      }
      await capital.registrar(
        persona: cobro.cliente,
        monto: pago,
        tipo: TiposCapital.ventaCobrada,
        descripcion: MetaPedido.conMedio(
          'Cobro del pedido #$pedidoId',
          medio: medio,
        ),
      );
    } catch (_) {}
    try {
      final datos = await _datosRemotos(
        pedidoLocalId: pedidoId,
        estadoAnterior: cobro.estadoAnterior,
        estadoNuevo: cobro.estadoNuevo,
      );
      ReplicaScope.diferir(() => PedidosRemoto.replicarCambio(datos));
    } catch (_) {}
  }

  /// Vuelve a empujar un pedido local. Si ya está mapeado, actualiza la fila.
  Future<void> publicarEnNube(int pedidoId) async {
    final datos = await _datosRemotos(pedidoLocalId: pedidoId);
    await PedidosRemoto.replicarAlta(datos);
  }

  /// Borra el pedido, sus líneas y el historial.
  /// La pantalla no lo usa: cancelar marca `cancelado` y conserva las filas.
  Future<void> eliminarPedido(int pedidoId) async {
    await db.transaction(() async {
      await (db.delete(db.historialPedidos)
            ..where((h) => h.pedidoId.equals(pedidoId)))
          .go();
      await (db.delete(db.productosPedido)
            ..where((l) => l.pedidoId.equals(pedidoId)))
          .go();
      await (db.delete(db.pedidos)..where((p) => p.id.equals(pedidoId))).go();
    });
    ReplicaScope.diferir(() => PedidosRemoto.borrar(pedidoId));
  }

  /// El alta del pedido manda el catálogo junto con el pedido. Acá solo se
  /// publica si el producto se creó suelto, fuera de esa transacción.
  Future<void> _publicarProducto(int id) async {
    if (ReplicaScope.anidado) return;
    final fila = await (db.select(db.productos)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    if (fila == null) return;
    ReplicaScope.diferir(
      () => StockRemoto.replicarProducto(
        DatosProductoRemoto(
          localId: fila.id,
          nombre: fila.nombre,
          precioCompra: fila.precioCompra,
          precioVenta: fila.precioVenta,
          pisarCompra: false,
          pisarVenta: true,
          activo: true,
        ),
      ),
    );
  }

  Future<DatosPedidoRemoto> _datosRemotos({
    required int pedidoLocalId,
    String? estadoAnterior,
    String? estadoNuevo,
    double descuento = 0,
  }) async {
    final pedido = await (db.select(db.pedidos)
          ..where((p) => p.id.equals(pedidoLocalId)))
        .getSingle();
    final cliente = await (db.select(db.clientes)
          ..where((c) => c.id.equals(pedido.clienteId)))
        .getSingleOrNull();
    final lineas = await (db.select(db.productosPedido)
          ..where((l) => l.pedidoId.equals(pedidoLocalId)))
        .get();
    final productos = await db.select(db.productos).get();
    final porId = {for (final producto in productos) producto.id: producto};
    final remotas = <LineaPedidoRemota>[];
    for (final linea in lineas) {
      final producto = porId[linea.productoId];
      final precio = producto?.precioVenta ?? 0;
      remotas.add(
        LineaPedidoRemota(
          nombre: producto?.nombre ?? 'Producto ${linea.productoId}',
          cantidad: linea.cantidad,
          precioVenta: precio,
          precioCompra: producto?.precioCompra ?? 0,
        ),
      );
    }
    final meta =
        (await const AmpliacionLocal().cargar()).pedidos[pedidoLocalId];
    var total = totalParaCobro(
      lineas: [
        for (final linea in lineas)
          (
            productoId: linea.productoId,
            cantidad: linea.cantidad,
            precioCatalogo: porId[linea.productoId]?.precioVenta ?? 0,
          ),
      ],
      meta: meta,
    );
    final guardado = meta?.descuentoMonto ?? 0;
    if (descuento > 0.009 && guardado <= 0) {
      final brutoCent = CapitalRepository.enCentavos(total);
      final descCent = CapitalRepository.enCentavos(descuento);
      final tope = descCent > brutoCent ? brutoCent : descCent;
      total = (brutoCent - tope) / 100;
    }
    final detalle = _detalleLineas(meta?.lineas ?? const []);
    final conDetalle = <LineaPedidoRemota>[];
    for (var i = 0; i < lineas.length; i++) {
      final base = remotas[i];
      final extra = detalle[lineas[i].productoId];
      conDetalle.add(
        LineaPedidoRemota(
          nombre: base.nombre,
          cantidad: base.cantidad,
          precioVenta: base.precioVenta,
          precioCompra: base.precioCompra,
          productoLocalId: lineas[i].productoId,
          variante: extra?.variante ?? '',
          unidad: extra?.unidad ?? '',
        ),
      );
    }
    final nombreCliente = cliente?.nombre.trim() ?? '';
    final descuentoAplicado =
        descuento > 0.009 ? descuento : (meta?.descuentoMonto ?? 0);
    final medio = meta == null
        ? null
        : (meta.fiado ? 'fiado' : meta.medioPago);
    return DatosPedidoRemoto(
      pedidoLocalId: pedidoLocalId,
      clienteLocalId: pedido.clienteId,
      clienteNombre:
          nombreCliente.isEmpty ? 'Cliente ${pedido.clienteId}' : nombreCliente,
      estado: estadoNuevo ?? pedido.estado,
      estadoAnterior: estadoAnterior,
      senia: pedido.montoSenado,
      total: total,
      origen: meta?.origen,
      medioPago: medio,
      nota: descuentoAplicado > 0.009 ? 'Total con descuento' : null,
      lineas: conDetalle,
    );
  }

  /// Variante o unidad solo si todas las líneas de ese producto coinciden.
  Map<int, ({String variante, String unidad})> _detalleLineas(
    List<LineaMeta> lineas,
  ) {
    final grupos = <int, List<LineaMeta>>{};
    for (final linea in lineas) {
      grupos.putIfAbsent(linea.productoId, () => []).add(linea);
    }
    final salida = <int, ({String variante, String unidad})>{};
    for (final entrada in grupos.entries) {
      final variantes = {
        for (final linea in entrada.value)
          if (linea.variante.trim().isNotEmpty) linea.variante.trim(),
      };
      final unidades = [
        for (final linea in entrada.value)
          if (linea.unidad.trim().isNotEmpty) linea.unidad.trim(),
      ];
      salida[entrada.key] = (
        variante: variantes.length == 1 ? variantes.first : '',
        unidad: unidades.length == 1 ? unidades.first : '',
      );
    }
    return salida;
  }

  Future<int> _resolverCliente({
    int? clienteId,
    String? clienteNombre,
  }) async {
    if (clienteId != null) {
      final cliente = await (db.select(db.clientes)
            ..where((c) => c.id.equals(clienteId)))
          .getSingleOrNull();
      if (cliente == null) {
        throw StateError('El cliente no existe.');
      }
      return cliente.id;
    }
    final nombre = (clienteNombre ?? '').trim();
    if (nombre.isEmpty) {
      throw ArgumentError('Elegí un cliente o escribí su nombre.');
    }
    final existente = await _buscarClientePorNombre(nombre);
    if (existente != null) return existente;
    final id = await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: nombre),
        );
    ReplicaScope.diferir(
      () => ClientesRemoto.replicar(localId: id, nombre: nombre),
    );
    return id;
  }

  Future<int> _resolverProducto(LineaPedidoBorrador linea) async {
    final precio = linea.precioVenta;
    if (precio != null && precio < 0) {
      throw ArgumentError('El precio de venta no puede ser negativo.');
    }
    final productoId = linea.productoId;
    if (productoId != null) {
      final existe = await (db.select(db.productos)
            ..where((p) => p.id.equals(productoId)))
          .getSingleOrNull();
      if (existe == null) {
        throw StateError('El producto no existe.');
      }
      if (precio != null && linea.pisarPrecioCatalogo) {
        await _guardarPrecio(existe.id, precio);
      }
      return existe.id;
    }
    return crearProductoMinimo(
      nombre: linea.nombreNuevo ?? '',
      precioVenta: precio ?? -1,
    );
  }

  Future<void> _guardarPrecio(int productoId, double precio) {
    return (db.update(db.productos)..where((p) => p.id.equals(productoId)))
        .write(ProductosCompanion(precioVenta: Value(precio)));
  }

  Future<int?> _buscarProductoPorNombre(String nombre) async {
    final clave = nombre.trim().toLowerCase();
    final productos = await db.select(db.productos).get();
    int? elegido;
    for (final producto in productos) {
      if (producto.nombre.trim().toLowerCase() != clave) continue;
      if (elegido == null || producto.id < elegido) elegido = producto.id;
    }
    return elegido;
  }

  Future<int?> _buscarClientePorNombre(String nombre) async {
    final clave = nombre.trim().toLowerCase();
    final clientes = await db.select(db.clientes).get();
    int? elegido;
    for (final cliente in clientes) {
      if (cliente.nombre.trim().toLowerCase() != clave) continue;
      if (elegido == null || cliente.id < elegido) elegido = cliente.id;
    }
    return elegido;
  }

  String _descripcionSalida(int pedidoId) => 'Salida por pedido $pedidoId';

  /// Baja el stock dentro de la transacción del pedido.
  /// [StockRepository.registrarAjuste] abre una transacción anidada y
  /// rechaza la salida si el propietario quedaría en negativo.
  Future<void> _descontarStock(int pedidoId) async {
    final stock = StockRepository(db);
    final lineas = await (db.select(db.productosPedido)
          ..where((l) => l.pedidoId.equals(pedidoId)))
        .get();
    final cantidades = <int, int>{};
    for (final linea in lineas) {
      cantidades.update(
        linea.productoId,
        (actual) => actual + linea.cantidad,
        ifAbsent: () => linea.cantidad,
      );
    }
    if (cantidades.isEmpty) return;

    final fichas = (await const AmpliacionLocal().cargar()).fichas;
    final productos = await stock.obtenerProductos();
    final porId = <int, ProductoStock>{
      for (final producto in productos)
        if (producto.id != null) producto.id!: producto,
    };

    final plan =
        <({int productoId, String nombre, String propietario, int cantidad})>[];
    for (final entry in cantidades.entries) {
      if (fichas[entry.key]?.controlaStock == false) continue;
      final producto = porId[entry.key];
      final nombre = producto?.nombre ?? 'Producto ${entry.key}';
      final hay = producto?.stockTotal ?? 0;
      if (hay < entry.value) {
        throw StateError(
          'No hay stock suficiente de $nombre. Hay $hay y el pedido pide ${entry.value}.',
        );
      }
      var falta = entry.value;
      final stockYo = producto?.stockYo ?? 0;
      if (stockYo > 0 && falta > 0) {
        final usarYo = stockYo < falta ? stockYo : falta;
        plan.add((
          productoId: entry.key,
          nombre: nombre,
          propietario: StockRepository.propietarioYo,
          cantidad: usarYo,
        ));
        falta -= usarYo;
      }
      if (falta > 0) {
        plan.add((
          productoId: entry.key,
          nombre: nombre,
          propietario: StockRepository.propietarioNildo,
          cantidad: falta,
        ));
      }
    }

    for (final paso in plan) {
      try {
        await stock.registrarAjuste(
          productoId: paso.productoId,
          nombre: paso.nombre,
          cantidad: paso.cantidad,
          propietario: paso.propietario,
          tipo: StockRepository.tipoSalida,
          descripcion: _descripcionSalida(pedidoId),
        );
      } on StockException catch (error) {
        throw StateError(error.mensaje);
      }
    }
  }

  /// Repone las salidas de este pedido, al mismo propietario, usando el
  /// texto de `movimientos_stock.descripcion`. No hay una columna de pedido
  /// en el movimiento: el vínculo es esa descripción.
  Future<void> _devolverStock(int pedidoId) async {
    final stock = StockRepository(db);
    final movimientos = await (db.select(db.movimientosStock)
          ..where(
            (m) =>
                m.descripcion.equals(_descripcionSalida(pedidoId)) &
                m.tipo.equals(StockRepository.tipoSalida),
          ))
        .get();
    if (movimientos.isEmpty) return;

    final productos = await stock.obtenerProductos();
    final nombres = <int, String>{
      for (final producto in productos)
        if (producto.id != null) producto.id!: producto.nombre,
    };

    for (final movimiento in movimientos) {
      final propietario = await _propietarioDe(movimiento.usuarioId);
      final nombre =
          nombres[movimiento.productoId] ?? 'Producto ${movimiento.productoId}';
      try {
        await stock.registrarAjuste(
          productoId: movimiento.productoId,
          nombre: nombre,
          cantidad: movimiento.cantidad,
          propietario: propietario,
          tipo: StockRepository.tipoEntrada,
          descripcion: 'Devolución por cancelar pedido $pedidoId',
        );
      } on StockException catch (error) {
        throw StateError(error.mensaje);
      }
    }
  }

  Future<String> _propietarioDe(int usuarioId) async {
    final usuario = await (db.select(db.usuarios)
          ..where((u) => u.id.equals(usuarioId)))
        .getSingleOrNull();
    final nombre = usuario?.nombre.trim().toLowerCase() ?? '';
    if (nombre == StockRepository.propietarioYo.toLowerCase()) {
      return StockRepository.propietarioYo;
    }
    if (nombre == StockRepository.propietarioNildo.toLowerCase()) {
      return StockRepository.propietarioNildo;
    }
    throw StateError(
      'No puedo devolver el stock: el movimiento no es de Yo ni de Nildo.',
    );
  }
}
