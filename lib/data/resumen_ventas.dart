import 'ampliacion_local.dart';
import 'pedido_repository.dart';
import '../models/pedido_estado.dart';
import 'app_database.dart';

/// Totales de ventas en un rango (importe y cantidad de pedidos).
class TotalesPeriodo {
  const TotalesPeriodo({
    required this.monto,
    required this.cantidadPedidos,
    this.ganancia = 0,
  });

  final double monto;
  final int cantidadPedidos;

  /// Suma de las ventas del período que tienen costo. Las que no, no entran.
  final double ganancia;

  static const vacio = TotalesPeriodo(monto: 0, cantidadPedidos: 0);
}

/// Producto agregado por unidades vendidas en el mes en curso.
class ProductoMasVendido {
  const ProductoMasVendido({
    required this.nombre,
    required this.unidades,
  });

  final String nombre;
  final int unidades;
}

/// Fila breve para la lista de ventas recientes.
class VentaReciente {
  const VentaReciente({
    required this.fecha,
    required this.clienteNombre,
    required this.estado,
    required this.montoTotal,
    this.origen = '',
    this.autor = '',
    this.productos = '',
    this.medioPago = '',
    this.fiado = false,
    this.ganancia,
  });

  final DateTime fecha;
  final String clienteNombre;
  final String estado;
  final double montoTotal;
  final String origen;
  final String autor;
  final String productos;

  /// efectivo, transferencia u otro. Vacío si esa venta no lo guardó.
  final String medioPago;
  final bool fiado;

  /// Null si ningún producto de la venta tiene precio de compra.
  final double? ganancia;
}

/// Snapshot del resumen de ventas (RF 3.5).
class ResumenVentasDatos {
  const ResumenVentasDatos({
    required this.hoy,
    required this.ultimos7Dias,
    required this.mesActual,
    required this.topProductosMes,
    required this.ultimasVentas,
    this.pedidosPaginaHoy = 0,
    this.pedidosPaginaMes = 0,
  });

  final TotalesPeriodo hoy;
  final TotalesPeriodo ultimos7Dias;
  final TotalesPeriodo mesActual;
  final List<ProductoMasVendido> topProductosMes;
  final List<VentaReciente> ultimasVentas;

  /// Pedidos con origen tienda, sin los cancelados.
  final int pedidosPaginaHoy;
  final int pedidosPaginaMes;

  static const vacio = ResumenVentasDatos(
    hoy: TotalesPeriodo.vacio,
    ultimos7Dias: TotalesPeriodo.vacio,
    mesActual: TotalesPeriodo.vacio,
    topProductosMes: [],
    ultimasVentas: [],
  );
}

/// Arma el resumen leyendo pedidos como [PedidoRepository.listarPedidos].
///
/// El importe de cada pedido usa [PedidoResumen.montoTotal] (suma de líneas con
/// `precioVenta × cantidad`). En Drift el precio vive en `productos.precio_venta`;
/// `productos_pedido` solo guarda cantidad, igual que al listar pedidos.
class ResumenVentasConsulta {
  const ResumenVentasConsulta(this.db);

  final AppDatabase db;

  /// [limiteUltimas] acota la lista de ventas recientes (sin cancelados).
  Future<ResumenVentasDatos> cargar({
    int limiteUltimas = 10,
    String? soloAutor,
  }) async {
    final pedidos = await PedidoRepository(db).listarPedidos();
    final metas = await const AmpliacionLocal().cargar();
    final costos = <int, double>{
      for (final producto in await db.select(db.productos).get())
        producto.id: producto.precioCompra,
    };
    final autorFiltro = soloAutor?.trim().toLowerCase() ?? '';
    final ahora = DateTime.now();
    final hoy = _soloFecha(ahora);
    final inicio7 = hoy.subtract(const Duration(days: 6));

    var totalHoy = 0.0;
    var cantHoy = 0;
    var total7 = 0.0;
    var cant7 = 0;
    var totalMes = 0.0;
    var cantMes = 0;
    var gananciaHoy = 0.0;
    var ganancia7 = 0.0;
    var gananciaMes = 0.0;
    var pedidosPaginaHoy = 0;
    var pedidosPaginaMes = 0;

    final agregadoMes = <int, ({String nombre, int unidades})>{};
    final recientes = <VentaReciente>[];

    for (final pedido in pedidos) {
      if (_estaCancelado(pedido)) continue;
      final meta = metas.pedidos[pedido.id];
      if (autorFiltro.isNotEmpty &&
          (meta?.autor ?? '').trim().toLowerCase() != autorFiltro) {
        continue;
      }

      final fecha = _soloFecha(pedido.fecha.toLocal());
      final monto = totalParaCobro(
        lineas: [
          for (final item in pedido.items)
            (
              productoId: item.productoId,
              cantidad: item.cantidad,
              precioCatalogo: item.precioVenta,
            ),
        ],
        meta: meta,
      );

      final ganancia = gananciaSimple(
        pedido: pedido,
        meta: meta,
        costos: costos,
      );
      if (_mismoDia(fecha, hoy)) {
        totalHoy += monto;
        cantHoy++;
        if (ganancia != null) gananciaHoy += ganancia;
      }
      if (!fecha.isBefore(inicio7) && !fecha.isAfter(hoy)) {
        total7 += monto;
        cant7++;
        if (ganancia != null) ganancia7 += ganancia;
      }
      final esPagina = (meta?.origen ?? '') == 'tienda';
      if (esPagina && _mismoDia(fecha, hoy)) pedidosPaginaHoy++;
      if (_enMesCalendario(fecha, ahora)) {
        if (esPagina) pedidosPaginaMes++;
        totalMes += monto;
        cantMes++;
        if (ganancia != null) gananciaMes += ganancia;
        for (final item in pedido.items) {
          final previo = agregadoMes[item.productoId];
          agregadoMes[item.productoId] = (
            nombre: item.nombre,
            unidades: (previo?.unidades ?? 0) + item.cantidad,
          );
        }
      }

      if (recientes.length < limiteUltimas) {
        recientes.add(
          VentaReciente(
            fecha: pedido.fecha,
            clienteNombre: pedido.clienteNombre,
            estado: pedido.estado,
            montoTotal: monto,
            origen: meta?.origen ?? '',
            autor: meta?.autor ?? '',
            productos: [
              for (final item in pedido.items) item.nombre,
            ].join(', '),
            medioPago: meta?.medioPago ?? '',
            fiado: meta?.fiado ?? false,
            ganancia: ganancia,
          ),
        );
      }
    }

    final top = agregadoMes.entries
        .map(
          (entry) => ProductoMasVendido(
            nombre: entry.value.nombre,
            unidades: entry.value.unidades,
          ),
        )
        .toList()
      ..sort((a, b) {
        final porUnidades = b.unidades.compareTo(a.unidades);
        if (porUnidades != 0) return porUnidades;
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });

    return ResumenVentasDatos(
      hoy: TotalesPeriodo(
        monto: totalHoy,
        cantidadPedidos: cantHoy,
        ganancia: gananciaHoy,
      ),
      ultimos7Dias: TotalesPeriodo(
        monto: total7,
        cantidadPedidos: cant7,
        ganancia: ganancia7,
      ),
      mesActual: TotalesPeriodo(
        monto: totalMes,
        cantidadPedidos: cantMes,
        ganancia: gananciaMes,
      ),
      topProductosMes: top.take(5).toList(),
      ultimasVentas: recientes,
      pedidosPaginaHoy: pedidosPaginaHoy,
      pedidosPaginaMes: pedidosPaginaMes,
    );
  }

  static bool _estaCancelado(PedidoResumen pedido) =>
      PedidoEstados.leer(pedido.estado) == PedidoEstado.cancelado;

  static DateTime _soloFecha(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _enMesCalendario(DateTime fecha, DateTime referencia) =>
      fecha.year == referencia.year && fecha.month == referencia.month;
}

/// Precio cobrado de cada línea menos el precio de compra, por cantidad.
///
/// Si un producto no tiene costo, esa línea no entra. Si ninguna tiene,
/// devuelve null: no se inventa una ganancia con costo cero.
/// El descuento del pedido se reparte solo sobre las líneas que sí tienen costo.
double? gananciaSimple({
  required PedidoResumen pedido,
  required MetaPedido? meta,
  required Map<int, double> costos,
}) {
  final lineas = _lineasCobradas(pedido, meta);
  var margen = 0.0;
  var bruto = 0.0;
  var brutoConCosto = 0.0;
  var alguna = false;
  for (final linea in lineas) {
    if (linea.cantidad <= 0) continue;
    final cobrado = linea.precio * linea.cantidad;
    if (cobrado.isNaN || cobrado.isInfinite) continue;
    bruto += cobrado;
    final costo = costos[linea.productoId];
    if (costo == null || costo <= 0 || costo.isNaN || costo.isInfinite) {
      continue;
    }
    alguna = true;
    brutoConCosto += cobrado;
    margen += (linea.precio - costo) * linea.cantidad;
  }
  if (!alguna) return null;
  final descuento = meta?.descuentoSobre(bruto) ?? 0;
  final parte = bruto <= 0.009 ? 0.0 : descuento * (brutoConCosto / bruto);
  return ((margen - parte) * 100).round() / 100.0;
}

List<({int productoId, int cantidad, double precio})> _lineasCobradas(
  PedidoResumen pedido,
  MetaPedido? meta,
) {
  final detalladas = meta?.lineas ?? const <LineaMeta>[];
  if (detalladas.isEmpty) {
    return [
      for (final item in pedido.items)
        (
          productoId: item.productoId,
          cantidad: item.cantidad,
          precio: meta?.precioDe(item.productoId) ?? item.precioVenta,
        ),
    ];
  }
  final cubiertos = <int, int>{};
  final salida = <({int productoId, int cantidad, double precio})>[];
  for (final linea in detalladas) {
    cubiertos.update(
      linea.productoId,
      (actual) => actual + linea.cantidad,
      ifAbsent: () => linea.cantidad,
    );
    salida.add((
      productoId: linea.productoId,
      cantidad: linea.cantidad,
      precio: linea.precio,
    ));
  }
  for (final item in pedido.items) {
    final resto = item.cantidad - (cubiertos[item.productoId] ?? 0);
    if (resto <= 0) continue;
    salida.add((
      productoId: item.productoId,
      cantidad: resto,
      precio: meta?.precioDe(item.productoId) ?? item.precioVenta,
    ));
  }
  return salida;
}
