import '../../data/ampliacion_local.dart';
import '../../data/app_database.dart';
import '../../data/capital_repository.dart';
import '../../data/pedido_repository.dart';
import '../../data/stock_repository.dart';
import '../../models/pedido_estado.dart';

/// Efectivo o transferencia. La venta simple no admite cuotas ni otro medio.
enum MedioVentaSimple { efectivo, transferencia }

/// Una línea ya resuelta, lista para mostrar y, si el orquestador confirma, guardar.
class LineaVentaPreparada {
  const LineaVentaPreparada({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioVentaUnitario,
    required this.costoUnitario,
  });

  final int productoId;
  final String nombre;
  final int cantidad;

  /// Precio de venta del producto, o el que vino explícito en la línea.
  final double precioVentaUnitario;

  /// Precio de compra histórico del producto. No sale de la frase.
  final double costoUnitario;

  double get ingreso => precioVentaUnitario * cantidad;

  double get costo => costoUnitario * cantidad;

  double get ganancia => ingreso - costo;
}

/// Venta calculada y todavía no escrita.
class BorradorVentaSimple {
  BorradorVentaSimple({
    required List<LineaVentaPreparada> lineas,
    required this.medio,
    required this.clienteNombre,
  }) : lineas = List<LineaVentaPreparada>.unmodifiable(lineas);

  final List<LineaVentaPreparada> lineas;
  final MedioVentaSimple medio;

  /// Puede ser "Mostrador" si no dijeron cliente.
  final String clienteNombre;

  double get ingreso =>
      lineas.fold<double>(0, (total, linea) => total + linea.ingreso);

  double get costo =>
      lineas.fold<double>(0, (total, linea) => total + linea.costo);

  double get ganancia => ingreso - costo;

  /// Texto en español para mostrar antes de escribir.
  String resumen() {
    final texto = StringBuffer()
      ..writeln('Venta simple. Todavía no se guardó nada.')
      ..writeln('Cliente: $clienteNombre')
      ..writeln('Medio: ${_etiquetaMedio(medio)}');
    if (lineas.isEmpty) {
      texto.writeln('Sin productos.');
    } else {
      texto.writeln('Productos:');
      for (final linea in lineas) {
        texto.writeln(
          '- ${linea.nombre} x${linea.cantidad} · '
          'precio ${_pesos(linea.precioVentaUnitario)} · '
          'costo ${_pesos(linea.costoUnitario)}',
        );
      }
    }
    texto
      ..writeln('Ingreso: ${_pesos(ingreso)}')
      ..writeln('Costo: ${_pesos(costo)}')
      ..write('Ganancia estimada: ${_pesos(ganancia)}');
    return texto.toString();
  }
}

/// Arma y, solo si el orquestador lo pide, confirma una venta cobrada al momento.
class VentaAsistente {
  const VentaAsistente(this.database);

  final AppDatabase database;

  /// No escribe el pedido ni mueve stock ni capital.
  ///
  /// El id ya viene elegido: no busca en el catálogo. De cada producto usa
  /// id, nombre, precioCompra, precioVenta y stock, los mismos datos que
  /// CoincidenciaProducto. Suma las cantidades del mismo producto antes de
  /// mirar el stock. El precio de venta y el costo salen del producto
  /// guardado, salvo un precio de venta explícito en la línea.
  ///
  /// Si falta stock, lanza [StateError] con cuánto hay y cuánto se pidió.
  /// Un producto que no controla stock no exige unidades.
  Future<BorradorVentaSimple> prepararVenta({
    required List<({int productoId, int cantidad, double? precioVenta})> lineas,
    required MedioVentaSimple medio,
    String clienteNombre = 'Mostrador',
  }) async {
    if (lineas.isEmpty) {
      throw ArgumentError('La venta necesita al menos un producto.');
    }

    final porId = await _leerProductos();
    final fichas = (await const AmpliacionLocal().cargar()).fichas;
    final grupos = <int, ({int cantidad, double? precio})>{};

    for (final linea in lineas) {
      if (linea.cantidad <= 0) {
        throw ArgumentError('La cantidad tiene que ser mayor a cero.');
      }
      _exigirPrecio(linea.precioVenta, 'El precio de venta');
      final producto = porId[linea.productoId];
      if (producto == null) {
        throw StateError('El producto no existe.');
      }
      final actual = grupos[linea.productoId];
      if (actual != null && actual.precio != linea.precioVenta) {
        throw StateError(
          'No puedo sumar ${producto.nombre}: las líneas traen precios de venta distintos.',
        );
      }
      grupos[linea.productoId] = (
        cantidad: (actual?.cantidad ?? 0) + linea.cantidad,
        precio: linea.precioVenta,
      );
    }

    final preparadas = <LineaVentaPreparada>[];
    for (final entrada in grupos.entries) {
      final datos = porId[entrada.key]!;
      final pedido = entrada.value.cantidad;
      final controla = fichas[datos.id]?.controlaStock ?? true;
      if (controla && datos.stock < pedido) {
        throw StateError(
          'No hay stock suficiente de ${datos.nombre}. Hay ${datos.stock} y se pidieron $pedido.',
        );
      }
      final venta = entrada.value.precio ?? datos.precioVenta;
      _exigirPrecio(venta, 'El precio de venta de ${datos.nombre}');
      _exigirPrecio(datos.precioCompra, 'El costo de ${datos.nombre}');
      preparadas.add(
        LineaVentaPreparada(
          productoId: datos.id,
          nombre: datos.nombre,
          cantidad: pedido,
          precioVentaUnitario: venta,
          costoUnitario: datos.precioCompra,
        ),
      );
    }

    final cliente = clienteNombre.trim();
    return BorradorVentaSimple(
      lineas: preparadas,
      medio: medio,
      clienteNombre: cliente.isEmpty ? 'Mostrador' : cliente,
    );
  }

  /// Escribe la venta y devuelve el id local del pedido.
  ///
  /// En una transacción de Drift crea el pedido con pago completo
  /// (seña = total) y lo pasa a confirmado, que descuenta el stock.
  /// El movimiento de capital "venta cobrada" lo anota [PedidoRepository.crearPedido]
  /// porque la seña cubre el total: acá no se vuelve a registrar.
  /// Después guarda el medio en la ficha del pedido y anota el cobro.
  Future<int> confirmarVenta(BorradorVentaSimple borrador) async {
    if (borrador.lineas.isEmpty) {
      throw ArgumentError('La venta necesita al menos un producto.');
    }
    final cliente = borrador.clienteNombre.trim();
    if (cliente.isEmpty) {
      throw ArgumentError('La venta necesita un cliente.');
    }
    final vistos = <int>{};
    for (final linea in borrador.lineas) {
      if (linea.cantidad <= 0) {
        throw ArgumentError('La cantidad tiene que ser mayor a cero.');
      }
      if (!vistos.add(linea.productoId)) {
        throw StateError(
          '${linea.nombre} está repetido. Hay que sumar las cantidades antes de confirmar.',
        );
      }
      _exigirPrecio(linea.precioVentaUnitario, 'El precio de venta');
      _exigirPrecio(linea.costoUnitario, 'El costo');
    }

    final medio = _claveMedio(borrador.medio);
    final total = CapitalRepository.enCentavos(borrador.ingreso) / 100;
    final repo = PedidoRepository(database);
    final id = await database.transaction(() async {
      final pedidoId = await repo.crearPedido(
        clienteNombre: cliente,
        montoSenado: total,
        medioPago: medio,
        lineas: [
          for (final linea in borrador.lineas)
            LineaPedidoBorrador(
              productoId: linea.productoId,
              precioVenta: linea.precioVentaUnitario,
              cantidad: linea.cantidad,
              pisarPrecioCatalogo: false,
            ),
        ],
      );
      await repo.cambiarEstado(pedidoId, PedidoEstado.confirmado.texto);
      return pedidoId;
    });

    await const AmpliacionLocal().marcarPedido(
      pedidoId: id,
      origen: 'venta',
      precios: {
        for (final linea in borrador.lineas)
          linea.productoId: linea.precioVentaUnitario,
      },
      medioPago: medio,
      fiado: false,
    );
    if (CapitalRepository.enCentavos(total) > 0) {
      await const AmpliacionLocal().anotarCobro(id);
    }
    return id;
  }

  /// id, nombre, precioCompra, precioVenta y stock. Misma forma que
  /// CoincidenciaProducto, leída por id. No busca por nombre ni crea usuarios.
  Future<Map<int, _ProductoElegido>> _leerProductos() async {
    final productos = await database.select(database.productos).get();
    final usuarios = await database.select(database.usuarios).get();
    final duenos = <int>{};
    for (final usuario in usuarios) {
      final nombre = usuario.nombre.trim().toLowerCase();
      if (nombre == StockRepository.propietarioYo.toLowerCase() ||
          nombre == StockRepository.propietarioNildo.toLowerCase()) {
        duenos.add(usuario.id);
      }
    }
    final filas = await database.select(database.stock).get();
    final stock = <int, int>{};
    for (final fila in filas) {
      if (!duenos.contains(fila.usuarioId)) continue;
      stock.update(
        fila.productoId,
        (actual) => actual + fila.cantidadActual,
        ifAbsent: () => fila.cantidadActual,
      );
    }
    return {
      for (final producto in productos)
        producto.id: (
          id: producto.id,
          nombre: producto.nombre,
          precioCompra: producto.precioCompra,
          precioVenta: producto.precioVenta,
          stock: stock[producto.id] ?? 0,
        ),
    };
  }
}

/// Campos de un producto ya elegido. No es la búsqueda del catálogo.
typedef _ProductoElegido = ({
  int id,
  String nombre,
  double precioCompra,
  double precioVenta,
  int stock,
});

void _exigirPrecio(double? precio, String etiqueta) {
  if (precio == null) return;
  if (precio.isNaN || precio.isInfinite) {
    throw ArgumentError('$etiqueta no es válido.');
  }
  if (precio < 0) {
    throw ArgumentError('$etiqueta no puede ser negativo.');
  }
}

String _claveMedio(MedioVentaSimple medio) {
  switch (medio) {
    case MedioVentaSimple.efectivo:
      return 'efectivo';
    case MedioVentaSimple.transferencia:
      return 'transferencia';
  }
}

String _etiquetaMedio(MedioVentaSimple medio) {
  final etiqueta = MetaPedido.etiquetaMedio(_claveMedio(medio));
  if (etiqueta.isEmpty) return _claveMedio(medio);
  return etiqueta;
}

String _pesos(double valor) =>
    '\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
