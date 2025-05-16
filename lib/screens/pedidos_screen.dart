import 'package:flutter/material.dart';

// Modelos básicos para la demo
enum PedidoEstado { pendiente, pagado, entregado }

String pedidoEstadoToString(PedidoEstado estado) {
  switch (estado) {
    case PedidoEstado.pendiente:
      return 'Pendiente';
    case PedidoEstado.pagado:
      return 'Pagado';
    case PedidoEstado.entregado:
      return 'Entregado';
  }
}

class ProductoPedido {
  final String nombre;
  final int cantidad;
  ProductoPedido({required this.nombre, required this.cantidad});
}

class Pedido {
  final String id;
  final String clienteNombre;
  final DateTime fecha;
  PedidoEstado estado;
  double montoSenado;
  List<ProductoPedido> productos;
  Pedido({
    required this.id,
    required this.clienteNombre,
    required this.fecha,
    required this.estado,
    required this.montoSenado,
    required this.productos,
  });
}

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  List<Pedido> pedidos = [
    Pedido(
      id: '1',
      clienteNombre: 'Kevin',
      fecha: DateTime.now().subtract(const Duration(days: 1)),
      estado: PedidoEstado.pendiente,
      montoSenado: 50,
      productos: [
        ProductoPedido(nombre: 'Powerbank', cantidad: 2),
        ProductoPedido(nombre: 'Cable USB', cantidad: 5),
      ],
    ),
    Pedido(
      id: '2',
      clienteNombre: 'Nildo',
      fecha: DateTime.now(),
      estado: PedidoEstado.pagado,
      montoSenado: 100,
      productos: [ProductoPedido(nombre: 'Cargador rápido', cantidad: 1)],
    ),
  ];

  String filtroEstado = 'todos';
  String filtroCliente = '';
  final estados = ['todos', 'pendiente', 'pagado', 'entregado'];

  List<Pedido> get pedidosFiltrados {
    return pedidos.where((p) {
        final estadoOk =
            filtroEstado == 'todos' || p.estado.name == filtroEstado;
        final clienteOk =
            filtroCliente.isEmpty ||
            p.clienteNombre.toLowerCase().contains(filtroCliente.toLowerCase());
        return estadoOk && clienteOk;
      }).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  void _nuevoPedido() async {
    final nuevo = await showDialog<Pedido>(
      context: context,
      builder: (context) => _NuevoPedidoDialog(),
    );
    if (nuevo != null) {
      setState(() => pedidos.add(nuevo));
    }
  }

  void _eliminarPedido(Pedido pedido) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar pedido'),
            content: const Text('¿Seguro que deseas eliminar este pedido?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => pedidos.remove(pedido));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  void _actualizarEstado(Pedido pedido, PedidoEstado nuevoEstado) {
    setState(() {
      final idx = pedidos.indexWhere((p) => p.id == pedido.id);
      if (idx != -1) {
        pedidos[idx].estado = nuevoEstado;
      }
    });
  }

  void _verDetalle(Pedido pedido) {
    showDialog(
      context: context,
      builder:
          (context) => _PedidoDetalleDialog(
            pedido: pedido,
            onEstadoChange:
                (nuevoEstado) => _actualizarEstado(pedido, nuevoEstado),
            onEliminar: () => _eliminarPedido(pedido),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Gestión de Pedidos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: ElevatedButton.icon(
              onPressed: _nuevoPedido,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                '+ Nuevo Pedido',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filtros
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por cliente',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => filtroCliente = v),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: filtroEstado,
                  items:
                      estados
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e[0].toUpperCase() + e.substring(1)),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => filtroEstado = v!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children:
                    pedidosFiltrados.map((pedido) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          title: Text(
                            pedido.clienteNombre,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fecha: ${pedido.fecha.day}/${pedido.fecha.month}/${pedido.fecha.year}',
                              ),
                              Row(
                                children: [
                                  _EstadoChip(estado: pedido.estado),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Seña: USD ${pedido.montoSenado.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'ver') {
                                _verDetalle(pedido);
                              } else if (value == 'eliminar') {
                                _eliminarPedido(pedido);
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'ver',
                                    child: Text('Ver/Editar'),
                                  ),
                                  if (pedido.estado == PedidoEstado.pendiente)
                                    const PopupMenuItem(
                                      value: 'eliminar',
                                      child: Text('Eliminar'),
                                    ),
                                ],
                          ),
                          onTap: () => _verDetalle(pedido),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar el estado con color
class _EstadoChip extends StatelessWidget {
  final PedidoEstado estado;
  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (estado) {
      case PedidoEstado.pendiente:
        color = Colors.amber;
        break;
      case PedidoEstado.pagado:
        color = Colors.green;
        break;
      case PedidoEstado.entregado:
        color = Colors.blue;
        break;
    }
    return Chip(
      label: Text(pedidoEstadoToString(estado)),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}

// Diálogo para crear nuevo pedido
class _NuevoPedidoDialog extends StatefulWidget {
  @override
  State<_NuevoPedidoDialog> createState() => _NuevoPedidoDialogState();
}

class _NuevoPedidoDialogState extends State<_NuevoPedidoDialog> {
  String cliente = '';
  double montoSenado = 0;
  List<ProductoPedido> productos = [];
  String productoNombre = '';
  int productoCantidad = 1;
  bool pagoCompleto = false;

  double get montoTotal {
    // Simulación: cada producto vale 10 USD
    return productos.fold<double>(0, (sum, p) => sum + p.cantidad * 10);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Pedido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Cliente'),
              onChanged: (v) => cliente = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Producto'),
                    onChanged: (v) => productoNombre = v,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Cant.'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => productoCantidad = int.tryParse(v) ?? 1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (productoNombre.isNotEmpty && productoCantidad > 0) {
                      setState(() {
                        productos.add(
                          ProductoPedido(
                            nombre: productoNombre,
                            cantidad: productoCantidad,
                          ),
                        );
                        productoNombre = '';
                        productoCantidad = 1;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              children:
                  productos
                      .map(
                        (p) => ListTile(
                          title: Text('${p.nombre} x${p.cantidad}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed:
                                () => setState(() => productos.remove(p)),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: pagoCompleto,
              onChanged: (v) {
                setState(() {
                  pagoCompleto = v ?? false;
                  if (pagoCompleto) {
                    montoSenado = montoTotal;
                  }
                });
              },
              title: const Text('Pago completo'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (!pagoCompleto)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Monto señado (USD)',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => montoSenado = double.tryParse(v) ?? 0,
              ),
            if (pagoCompleto)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Monto total: USD ${montoTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (cliente.isNotEmpty && productos.isNotEmpty) {
              Navigator.pop(
                context,
                Pedido(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  clienteNombre: cliente,
                  fecha: DateTime.now(),
                  estado: PedidoEstado.pendiente,
                  montoSenado: pagoCompleto ? montoTotal : montoSenado,
                  productos: productos,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Completa cliente y productos')),
              );
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// Diálogo para ver/editar detalle de pedido
class _PedidoDetalleDialog extends StatelessWidget {
  final Pedido pedido;
  final void Function(PedidoEstado)? onEstadoChange;
  final VoidCallback? onEliminar;
  const _PedidoDetalleDialog({
    required this.pedido,
    this.onEstadoChange,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Detalle de Pedido'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente: ${pedido.clienteNombre}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Fecha: ${pedido.fecha.day}/${pedido.fecha.month}/${pedido.fecha.year}',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _EstadoChip(estado: pedido.estado),
                const SizedBox(width: 12),
                Text('Seña: USD ${pedido.montoSenado.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Productos:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...pedido.productos.map((p) => Text('${p.nombre} x${p.cantidad}')),
          ],
        ),
      ),
      actions: [
        if (pedido.estado == PedidoEstado.pendiente && onEstadoChange != null)
          ElevatedButton(
            onPressed: () => onEstadoChange!(PedidoEstado.pagado),
            child: const Text('Marcar como Pagado'),
          ),
        if (pedido.estado == PedidoEstado.pagado && onEstadoChange != null)
          ElevatedButton(
            onPressed: () => onEstadoChange!(PedidoEstado.entregado),
            child: const Text('Marcar como Entregado'),
          ),
        if (onEliminar != null)
          TextButton(
            onPressed: onEliminar,
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
