import '../data/app_database.dart';

/// Arma un resumen de texto con lo que hay en SQLite para el asistente.
/// Pedidos y stock que solo viven en memoria de otras pantallas no entran acá.
class NegocioContexto {
  final AppDatabase database;

  NegocioContexto(this.database);

  Future<String> resumir() async {
    final buffer = StringBuffer();

    final clientes = await database.select(database.clientes).get();
    final productos = await database.select(database.productos).get();
    final stock = await database.select(database.stock).get();
    final usuarios = await database.select(database.usuarios).get();
    final pedidos = await database.select(database.pedidos).get();
    final lineas = await database.select(database.productosPedido).get();
    final movimientos = await database.select(database.movimientosCapital).get();

    final nombreProducto = {for (final p in productos) p.id: p.nombre};
    final nombreCliente = {for (final c in clientes) c.id: c.nombre};
    final nombreUsuario = {for (final u in usuarios) u.id: u.nombre};

    buffer.writeln('Clientes (${clientes.length}):');
    if (clientes.isEmpty) {
      buffer.writeln('- sin registros');
    } else {
      for (final c in clientes.take(40)) {
        buffer.writeln(
          '- ${c.nombre} | pago: ${c.estadoPago} | '
          'contacto: ${c.contacto ?? '-'} | email: ${c.email ?? '-'} | '
          'potencial: ${c.esPotencial ? 'sí' : 'no'}',
        );
      }
    }

    buffer.writeln('Productos (${productos.length}):');
    if (productos.isEmpty) {
      buffer.writeln('- sin registros');
    } else {
      for (final p in productos.take(40)) {
        buffer.writeln(
          '- ${p.nombre} | compra: ${p.precioCompra} | venta: ${p.precioVenta}',
        );
      }
    }

    buffer.writeln('Stock (${stock.length}):');
    if (stock.isEmpty) {
      buffer.writeln('- sin registros');
    } else {
      for (final s in stock.take(40)) {
        final producto = nombreProducto[s.productoId] ?? 'producto ${s.productoId}';
        final usuario = nombreUsuario[s.usuarioId] ?? 'usuario ${s.usuarioId}';
        buffer.writeln('- $producto | $usuario | cantidad: ${s.cantidadActual}');
      }
    }

    buffer.writeln('Pedidos (${pedidos.length}):');
    if (pedidos.isEmpty) {
      buffer.writeln('- sin registros');
    } else {
      for (final pedido in pedidos.take(40)) {
        final cliente = nombreCliente[pedido.clienteId] ?? 'cliente ${pedido.clienteId}';
        final items = lineas.where((l) => l.pedidoId == pedido.id).map((l) {
          final nombre = nombreProducto[l.productoId] ?? 'producto ${l.productoId}';
          return '$nombre x${l.cantidad}';
        }).join(', ');
        final fecha = pedido.fecha.toIso8601String().split('T').first;
        buffer.writeln(
          '- #$pedido.id | $cliente | $fecha | estado: ${pedido.estado} | '
          'seña: ${pedido.montoSenado} | items: ${items.isEmpty ? '-' : items}',
        );
      }
    }

    buffer.writeln('Movimientos de capital (${movimientos.length}):');
    if (movimientos.isEmpty) {
      buffer.writeln('- sin registros');
    } else {
      for (final m in movimientos.take(40)) {
        final fecha = m.fecha.toIso8601String().split('T').first;
        buffer.writeln(
          '- $fecha | ${m.persona} | ${m.tipo} | ${m.monto} | ${m.descripcion ?? ''}',
        );
      }
    }

    final texto = buffer.toString().trim();
    if (texto.length <= 8000) return texto;
    return texto.substring(0, 8000);
  }
}
