import '../models/pedido_estado.dart';
import 'app_database.dart';

class HechoActividad {
  const HechoActividad({
    required this.fecha,
    required this.titulo,
    required this.detalle,
    this.actor = '',
    this.ambito = '',
  });

  final DateTime fecha;
  final String titulo;
  final String detalle;
  final String actor;
  final String ambito;
}

/// Junta el historial que ya existe en la base. No crea tablas.
Future<List<HechoActividad>> cargarActividad(AppDatabase db) async {
  final hechos = <HechoActividad>[];

  final historialPedidos = await db.select(db.historialPedidos).get();
  final pedidos = await db.select(db.pedidos).get();
  final clientes = await db.select(db.clientes).get();
  final pedidoPorId = {for (final pedido in pedidos) pedido.id: pedido};
  final clientePorId = {for (final cliente in clientes) cliente.id: cliente.nombre};
  for (final cambio in historialPedidos) {
    final pedido = pedidoPorId[cambio.pedidoId];
    final cliente = pedido == null
        ? 'Pedido #${cambio.pedidoId}'
        : clientePorId[pedido.clienteId] ?? 'Pedido #${cambio.pedidoId}';
    hechos.add(
      HechoActividad(
        fecha: cambio.fechaCambio,
        titulo: 'Pedido de $cliente',
        ambito: 'pedido',
        detalle:
            '${PedidoEstados.etiqueta(cambio.estadoAnterior)} → ${PedidoEstados.etiqueta(cambio.estadoNuevo)}',
      ),
    );
  }

  final historialClientes = await db.select(db.historialClientes).get();
  for (final cambio in historialClientes) {
    final nombre = clientePorId[cambio.clienteId] ?? 'Cliente ${cambio.clienteId}';
    hechos.add(
      HechoActividad(
        fecha: cambio.fechaCambio,
        titulo: 'Cliente $nombre',
        ambito: 'cliente',
        detalle: '${cambio.estadoAnterior} → ${cambio.estadoNuevo}',
      ),
    );
  }

  final movimientos = await db.select(db.movimientosStock).get();
  final productos = await db.select(db.productos).get();
  final usuarios = await db.select(db.usuarios).get();
  final productoPorId = {for (final producto in productos) producto.id: producto.nombre};
  final usuarioPorId = {for (final usuario in usuarios) usuario.id: usuario.nombre};
  for (final movimiento in movimientos) {
    final nombre = productoPorId[movimiento.productoId] ?? 'Producto';
    final quien = usuarioPorId[movimiento.usuarioId] ?? '';
    final nota = movimiento.descripcion?.trim();
    hechos.add(
      HechoActividad(
        fecha: movimiento.fechaCarga,
        titulo: '${movimiento.tipo} de $nombre',
        ambito: 'stock',
        actor: quien,
        detalle: [
          '${movimiento.cantidad} u.',
          if (quien.isNotEmpty) quien,
          if (nota != null && nota.isNotEmpty) nota,
        ].join(' · '),
      ),
    );
  }

  final capital = await db.select(db.movimientosCapital).get();
  for (final movimiento in capital) {
    final nota = movimiento.descripcion?.trim();
    hechos.add(
      HechoActividad(
        fecha: movimiento.fecha,
        titulo: '${movimiento.tipo} · ${movimiento.persona}',
        ambito: 'capital',
        actor: movimiento.persona,
        detalle: nota == null || nota.isEmpty
            ? movimiento.monto.toStringAsFixed(2)
            : '${movimiento.monto.toStringAsFixed(2)} · $nota',
      ),
    );
  }

  hechos.sort((a, b) => b.fecha.compareTo(a.fecha));
  if (hechos.length > 40) return hechos.sublist(0, 40);
  return hechos;
}
