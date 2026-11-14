import '../utils/moneda.dart';

/// Línea de un pedido armado en la tienda, todavía sin guardar.
class LineaPedidoTienda {
  const LineaPedidoTienda({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.variante = '',
    this.unidad = '',
  });

  final int productoId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final String variante;
  final String unidad;

  double get subtotal => precioUnitario * cantidad;
}

/// Precio visible con la moneda del negocio. Ver [formatearMoneda].
String monedaTienda(double valor, String codigo) =>
    formatearMoneda(valor, codigo);

double totalPedidoTienda(Iterable<LineaPedidoTienda> lineas) {
  var total = 0.0;
  for (final linea in lineas) {
    if (linea.cantidad <= 0) continue;
    total += linea.subtotal;
  }
  return total;
}

/// Texto en español para pegar en el chat de WhatsApp.
///
/// Incluye el código del pedido guardado, el comprador, cada producto con su
/// cantidad y el total.
/// No llama a ninguna API: el que abre el enlace es [enlacePedidoWhatsApp].
String mensajePedidoWhatsApp({
  required String negocio,
  required int pedidoId,
  required String comprador,
  String? telefono,
  required List<LineaPedidoTienda> lineas,
  required String moneda,
}) {
  final nombreNegocio = _nombreNegocio(negocio);
  final nombreComprador = _textoEnUnaLinea(comprador);
  final telefonoComprador = _textoEnUnaLinea(telefono ?? '');
  final pedidas = [
    for (final linea in lineas)
      if (linea.cantidad > 0) linea,
  ];
  final buffer = StringBuffer()
    ..writeln('Hola, quiero hacer un pedido en $nombreNegocio.')
    ..writeln()
    ..writeln('Código de pedido: #$pedidoId')
    ..writeln('Comprador: $nombreComprador');
  if (telefonoComprador.isNotEmpty) {
    buffer.writeln('Teléfono: $telefonoComprador');
  }
  buffer.writeln();
  if (pedidas.isEmpty) {
    buffer.write('Todavía no elegí productos.');
    return buffer.toString();
  }
  for (final linea in pedidas) {
    final producto =
        linea.nombre.trim().isEmpty ? 'Producto' : linea.nombre.trim();
    buffer.writeln(
      '$producto x ${linea.cantidad} — '
      '${monedaTienda(linea.precioUnitario, moneda)} c/u — '
      '${monedaTienda(linea.subtotal, moneda)}',
    );
  }
  buffer
    ..writeln()
    ..write('Total: ${monedaTienda(totalPedidoTienda(pedidas), moneda)}');
  return buffer.toString();
}

/// `https://wa.me/?text=` con el pedido. Sin número: el negocio no tiene teléfono.
Uri enlacePedidoWhatsApp({
  required String negocio,
  required int pedidoId,
  required String comprador,
  String? telefono,
  required List<LineaPedidoTienda> lineas,
  required String moneda,
}) {
  return Uri(
    scheme: 'https',
    host: 'wa.me',
    path: '/',
    queryParameters: {
      'text': mensajePedidoWhatsApp(
        negocio: negocio,
        pedidoId: pedidoId,
        comprador: comprador,
        telefono: telefono,
        lineas: lineas,
        moneda: moneda,
      ),
    },
  );
}

/// Enlace anterior de solo WhatsApp, usado cuando la pantalla no tiene base.
///
/// No agrega un código porque no existe un pedido persistido.
Uri enlaceCarritoWhatsApp({
  required String negocio,
  required List<LineaPedidoTienda> lineas,
  required String moneda,
}) {
  final pedidas = [
    for (final linea in lineas)
      if (linea.cantidad > 0) linea,
  ];
  final buffer = StringBuffer()
    ..writeln('Hola, quiero hacer un pedido en ${_nombreNegocio(negocio)}.')
    ..writeln();
  for (final linea in pedidas) {
    final producto =
        linea.nombre.trim().isEmpty ? 'Producto' : linea.nombre.trim();
    buffer.writeln(
      '$producto x ${linea.cantidad} — '
      '${monedaTienda(linea.precioUnitario, moneda)} c/u — '
      '${monedaTienda(linea.subtotal, moneda)}',
    );
  }
  buffer
    ..writeln()
    ..write('Total: ${monedaTienda(totalPedidoTienda(pedidas), moneda)}');
  return Uri(
    scheme: 'https',
    host: 'wa.me',
    path: '/',
    queryParameters: {'text': buffer.toString()},
  );
}

String _nombreNegocio(String negocio) {
  final limpio = _textoEnUnaLinea(negocio);
  return limpio.isEmpty ? 'Gexi' : limpio;
}

String _textoEnUnaLinea(String texto) {
  return texto.replaceAll(RegExp(r'\s+'), ' ').trim();
}
