import 'package:flutter/material.dart';
import '../data/app_database.dart' show AppDatabase;
import '../data/pedido_repository.dart';
import '../theme/app_theme.dart';

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

/// Sin [database] se mantiene la demo en memoria.
/// Con [database] los pedidos se leen y escriben en SQLite.
class PedidosScreen extends StatelessWidget {
  final AppDatabase? database;

  const PedidosScreen({super.key, this.database});

  @override
  Widget build(BuildContext context) {
    final db = database;
    if (db == null) {
      return const _PedidosMemoriaScreen();
    }
    return _PedidosDbScreen(database: db);
  }
}

class _PedidosMemoriaScreen extends StatefulWidget {
  const _PedidosMemoriaScreen();

  @override
  State<_PedidosMemoriaScreen> createState() => _PedidosMemoriaScreenState();
}

class _PedidosMemoriaScreenState extends State<_PedidosMemoriaScreen> {
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
      final estadoOk = filtroEstado == 'todos' || p.estado.name == filtroEstado;
      final clienteOk = filtroCliente.isEmpty ||
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
      builder: (context) => AlertDialog(
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
      builder: (context) => _PedidoDetalleDialog(
        pedido: pedido,
        onEstadoChange: (nuevoEstado) => _actualizarEstado(pedido, nuevoEstado),
        onEliminar: () => _eliminarPedido(pedido),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Pedidos',
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
                    decoration: InputDecoration(
                      labelText: 'Buscar por cliente',
                      prefixIcon: Icon(Icons.search,
                          color: Theme.of(context).iconTheme.color),
                    ),
                    onChanged: (v) => setState(() => filtroCliente = v),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: filtroEstado,
                  items: estados
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e[0].toUpperCase() + e.substring(1),
                              style: Theme.of(context).textTheme.bodyLarge),
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
                children: pedidosFiltrados.map((pedido) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      title: Text(
                        pedido.clienteNombre,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha: ${pedido.fecha.day}/${pedido.fecha.month}/${pedido.fecha.year}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Row(
                            children: [
                              _EstadoChip(estado: pedido.estado),
                              const SizedBox(width: 8),
                              Text(
                                'Seña: USD ${pedido.montoSenado.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodyMedium,
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
                        itemBuilder: (context) => [
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
        color = Theme.of(context).brightness == Brightness.dark
            ? Color(0xFFFBC02D)
            : Colors.amber;
        break;
      case PedidoEstado.pagado:
        color = Theme.of(context).brightness == Brightness.dark
            ? AppColors.lima
            : AppColors.tealFuerte;
        break;
      case PedidoEstado.entregado:
        color = Theme.of(context).brightness == Brightness.dark
            ? AppColors.azulClaro
            : AppColors.azul;
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
              children: productos
                  .map(
                    (p) => ListTile(
                      title: Text('${p.nombre} x${p.cantidad}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => productos.remove(p)),
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

double? _parseMonto(String raw) {
  final texto = raw.trim().replaceAll(',', '.');
  if (texto.isEmpty) return null;
  return double.tryParse(texto);
}

String _fechaCorta(DateTime fecha) => '${fecha.day}/${fecha.month}/${fecha.year}';

String _fechaHora(DateTime fecha) {
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '${_fechaCorta(fecha)} $hora:$minuto';
}

String _usd(double valor) => 'USD ${valor.toStringAsFixed(2)}';

class _PedidosDbScreen extends StatefulWidget {
  final AppDatabase database;

  const _PedidosDbScreen({required this.database});

  @override
  State<_PedidosDbScreen> createState() => _PedidosDbScreenState();
}

class _PedidosDbScreenState extends State<_PedidosDbScreen> {
  late final PedidoRepository _repo = PedidoRepository(widget.database);
  List<PedidoResumen> _pedidos = [];
  bool _cargando = true;
  String? _error;
  String _filtroEstado = 'todos';
  String _filtroCliente = '';

  static const _estadosFiltro = ['todos', ...EstadosPedido.valores];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final pedidos = await _repo.listarPedidos();
      if (!mounted) return;
      setState(() {
        _pedidos = pedidos;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los pedidos.';
      });
    }
  }

  List<PedidoResumen> get _filtrados {
    final consulta = _filtroCliente.trim().toLowerCase();
    return _pedidos.where((pedido) {
      final estadoOk =
          _filtroEstado == 'todos' || pedido.estado == _filtroEstado;
      final clienteOk = consulta.isEmpty ||
          pedido.clienteNombre.toLowerCase().contains(consulta);
      return estadoOk && clienteOk;
    }).toList();
  }

  Future<void> _nuevoPedido() async {
    final creado = await showDialog<bool>(
      context: context,
      builder: (context) => _NuevoPedidoDbDialog(repo: _repo),
    );
    if (creado == true && mounted) {
      await _cargar();
    }
  }

  Future<void> _eliminarPedido(PedidoResumen pedido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text('¿Seguro que deseas eliminar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await _repo.eliminarPedido(pedido.id);
      if (!mounted) return;
      await _cargar();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo eliminar el pedido.');
    }
  }

  Future<void> _verDetalle(PedidoResumen pedido) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PedidoDbDetalleDialog(
        repo: _repo,
        pedidoInicial: pedido,
        onActualizado: _cargar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Pedidos',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevoPedido,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Buscar por cliente',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    onChanged: (valor) => setState(() => _filtroCliente = valor),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filtroEstado,
                  items: _estadosFiltro
                      .map(
                        (estado) => DropdownMenuItem(
                          value: estado,
                          child: Text(
                            estado == 'todos'
                                ? 'Todos'
                                : EstadosPedido.etiqueta(estado),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (valor) {
                    if (valor == null) return;
                    setState(() => _filtroEstado = valor);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(child: _buildLista()),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_cargando && _pedidos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final pedidos = _filtrados;
    if (pedidos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 48),
          Center(child: Text('No hay pedidos para mostrar.')),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      children: pedidos.map(_tarjeta).toList(),
    );
  }

  Widget _tarjeta(PedidoResumen pedido) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        isThreeLine: true,
        title: Text(
          pedido.clienteNombre,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fecha: ${_fechaCorta(pedido.fecha)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _EstadoDbChip(estado: pedido.estado),
                Text(
                  'Total: ${_usd(pedido.montoTotal)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Seña: ${_usd(pedido.montoSenado)}',
                  style: Theme.of(context).textTheme.bodyMedium,
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
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'ver',
              child: Text('Ver/Editar'),
            ),
            if (pedido.estado == EstadosPedido.pendiente)
              const PopupMenuItem(
                value: 'eliminar',
                child: Text('Eliminar'),
              ),
          ],
        ),
        onTap: () => _verDetalle(pedido),
      ),
    );
  }
}

class _EstadoDbChip extends StatelessWidget {
  final String estado;

  const _EstadoDbChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final Color color;
    switch (estado) {
      case EstadosPedido.pendiente:
        color = oscuro ? const Color(0xFFFBC02D) : Colors.amber;
        break;
      case EstadosPedido.enProceso:
        color = oscuro ? AppColors.azulClaro : AppColors.azul;
        break;
      case EstadosPedido.completado:
        color = oscuro ? AppColors.lima : AppColors.tealFuerte;
        break;
      case EstadosPedido.cancelado:
        color = Colors.red;
        break;
      default:
        color = Theme.of(context).colorScheme.primary;
    }
    return Chip(
      label: Text(EstadosPedido.etiqueta(estado)),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}

class _LineaBorrador {
  final int? productoId;
  final String nombre;
  final int cantidad;
  final double precioVenta;
  final bool esNuevo;

  const _LineaBorrador({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioVenta,
    required this.esNuevo,
  });

  _LineaBorrador copyWith({int? cantidad, double? precioVenta}) {
    return _LineaBorrador(
      productoId: productoId,
      nombre: nombre,
      cantidad: cantidad ?? this.cantidad,
      precioVenta: precioVenta ?? this.precioVenta,
      esNuevo: esNuevo,
    );
  }
}

class _NuevoPedidoDbDialog extends StatefulWidget {
  final PedidoRepository repo;

  const _NuevoPedidoDbDialog({required this.repo});

  @override
  State<_NuevoPedidoDbDialog> createState() => _NuevoPedidoDbDialogState();
}

class _NuevoPedidoDbDialogState extends State<_NuevoPedidoDbDialog> {
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _senaCtrl = TextEditingController();

  List<ClientePedido> _clientes = [];
  List<ProductoPedidoOpcion> _productos = [];
  final List<_LineaBorrador> _lineas = [];
  int? _clienteId;
  int? _productoId;
  bool _modoNuevo = false;
  bool _pagoCompleto = false;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  double get _total => calcularMontoTotal(
        _lineas.map(
          (linea) => (precioVenta: linea.precioVenta, cantidad: linea.cantidad),
        ),
      );

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _cantidadCtrl.dispose();
    _senaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarOpciones() async {
    try {
      final clientes = await widget.repo.listarClientes();
      final productos = await widget.repo.listarProductos();
      if (!mounted) return;
      setState(() {
        _clientes = clientes;
        _productos = productos;
        _cargando = false;
        if (clientes.isNotEmpty) _clienteId = clientes.first.id;
        if (productos.isEmpty) {
          _modoNuevo = true;
        } else {
          _productoId = productos.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar clientes y productos.';
      });
    }
  }

  bool _esLaMisma(_LineaBorrador a, _LineaBorrador b) {
    if (a.productoId != null && b.productoId != null) {
      return a.productoId == b.productoId;
    }
    return a.nombre.trim().toLowerCase() == b.nombre.trim().toLowerCase();
  }

  void _sincronizarSena() {
    if (_pagoCompleto) {
      _senaCtrl.text = _total.toStringAsFixed(2);
    }
  }

  void _sumarLinea(_LineaBorrador linea) {
    setState(() {
      final index = _lineas.indexWhere((actual) => _esLaMisma(actual, linea));
      if (index >= 0) {
        final previa = _lineas[index];
        _lineas[index] = previa.copyWith(
          cantidad: previa.cantidad + linea.cantidad,
          precioVenta: linea.esNuevo ? linea.precioVenta : previa.precioVenta,
        );
      } else {
        _lineas.add(linea);
      }
      _error = null;
      _sincronizarSena();
    });
  }

  void _agregarExistente() {
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    ProductoPedidoOpcion? producto;
    for (final item in _productos) {
      if (item.id == _productoId) producto = item;
    }
    if (producto == null || cantidad <= 0) {
      setState(() {
        _error = 'Elige un producto y una cantidad mayor a cero.';
      });
      return;
    }
    _sumarLinea(
      _LineaBorrador(
        productoId: producto.id,
        nombre: producto.nombre,
        cantidad: cantidad,
        precioVenta: producto.precioVenta,
        esNuevo: false,
      ),
    );
    _cantidadCtrl.text = '1';
  }

  void _agregarNuevo() {
    final nombre = _nombreCtrl.text.trim();
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    final precio = _parseMonto(_precioCtrl.text);
    if (nombre.isEmpty || cantidad <= 0 || precio == null || precio < 0) {
      setState(() {
        _error = 'Completa nombre, cantidad y precio de venta.';
      });
      return;
    }
    ProductoPedidoOpcion? existente;
    for (final item in _productos) {
      if (item.nombre.trim().toLowerCase() == nombre.toLowerCase()) {
        existente = item;
        break;
      }
    }
    if (existente != null) {
      _sumarLinea(
        _LineaBorrador(
          productoId: existente.id,
          nombre: existente.nombre,
          cantidad: cantidad,
          precioVenta: existente.precioVenta,
          esNuevo: false,
        ),
      );
    } else {
      _sumarLinea(
        _LineaBorrador(
          productoId: null,
          nombre: nombre,
          cantidad: cantidad,
          precioVenta: precio,
          esNuevo: true,
        ),
      );
    }
    _nombreCtrl.clear();
    _precioCtrl.clear();
    _cantidadCtrl.text = '1';
  }

  void _quitar(_LineaBorrador linea) {
    setState(() {
      _lineas.remove(linea);
      _error = null;
      _sincronizarSena();
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final clienteId = _clienteId;
    if (clienteId == null) {
      setState(() => _error = 'Elige un cliente existente.');
      return;
    }
    if (_lineas.isEmpty) {
      setState(() => _error = 'Agrega al menos un producto.');
      return;
    }

    final double sena;
    if (_pagoCompleto) {
      sena = _total;
    } else {
      final texto = _senaCtrl.text.trim();
      if (texto.isEmpty) {
        sena = 0;
      } else {
        final parseado = _parseMonto(texto);
        if (parseado == null) {
          setState(() => _error = 'La seña no es un número válido.');
          return;
        }
        sena = parseado;
      }
    }
    if (sena < 0) {
      setState(() => _error = 'La seña no puede ser negativa.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repo.crearPedido(
        clienteId: clienteId,
        montoSenado: sena,
        lineas: [
          for (final linea in _lineas)
            if (linea.productoId != null)
              LineaPedidoBorrador(
                productoId: linea.productoId,
                cantidad: linea.cantidad,
              )
            else
              LineaPedidoBorrador(
                nombreNuevo: linea.nombre,
                precioVenta: linea.precioVenta,
                cantidad: linea.cantidad,
              ),
        ],
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar el pedido.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Pedido'),
      content: _cargando
          ? const SizedBox(
              width: 280,
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_clientes.isEmpty)
                    const Text(
                      'No hay clientes cargados. Crea un cliente en la pantalla Clientes para asociarle el pedido.',
                    )
                  else
                    DropdownButton<int>(
                      isExpanded: true,
                      value: _clienteId,
                      items: _clientes
                          .map(
                            (cliente) => DropdownMenuItem(
                              value: cliente.id,
                              child: Text(cliente.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (valor) => setState(() => _clienteId = valor),
                    ),
                  const SizedBox(height: 12),
                  if (_productos.isNotEmpty)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Existente'),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Nuevo'),
                        ),
                      ],
                      selected: {_modoNuevo},
                      onSelectionChanged: (seleccion) {
                        setState(() => _modoNuevo = seleccion.first);
                      },
                    ),
                  if (_productos.isEmpty)
                    Text(
                      'No hay productos. Carga nombre y precio de venta para crear uno.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 8),
                  if (!_modoNuevo && _productos.isNotEmpty)
                    DropdownButton<int>(
                      isExpanded: true,
                      value: _productoId,
                      items: _productos
                          .map(
                            (producto) => DropdownMenuItem(
                              value: producto.id,
                              child: Text(
                                '${producto.nombre} · ${_usd(producto.precioVenta)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (valor) => setState(() => _productoId = valor),
                    ),
                  if (_modoNuevo) ...[
                    TextField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Producto'),
                    ),
                    TextField(
                      controller: _precioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Precio de venta (USD)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _cantidadCtrl,
                          decoration: const InputDecoration(labelText: 'Cant.'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed:
                            _modoNuevo ? _agregarNuevo : _agregarExistente,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                  ..._lineas.map(
                    (linea) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${linea.nombre} x${linea.cantidad}'),
                      subtitle: Text(
                        '${_usd(linea.precioVenta)} c/u · ${_usd(linea.precioVenta * linea.cantidad)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _quitar(linea),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monto total: ${_usd(_total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'La seña se muestra aparte y no se resta del total.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  CheckboxListTile(
                    value: _pagoCompleto,
                    onChanged: (valor) {
                      setState(() {
                        _pagoCompleto = valor ?? false;
                        _sincronizarSena();
                      });
                    },
                    title: const Text('Pago completo'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!_pagoCompleto)
                    TextField(
                      controller: _senaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Seña / anticipo (USD)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  if (_pagoCompleto)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Seña: ${_usd(_total)}'),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando || _cargando || _clientes.isEmpty
              ? null
              : () {
                  _guardar();
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _PedidoDbDetalleDialog extends StatefulWidget {
  final PedidoRepository repo;
  final PedidoResumen pedidoInicial;
  final Future<void> Function() onActualizado;

  const _PedidoDbDetalleDialog({
    required this.repo,
    required this.pedidoInicial,
    required this.onActualizado,
  });

  @override
  State<_PedidoDbDetalleDialog> createState() => _PedidoDbDetalleDialogState();
}

class _PedidoDbDetalleDialogState extends State<_PedidoDbDetalleDialog> {
  late PedidoResumen _pedido = widget.pedidoInicial;
  bool _ocupado = false;
  String? _error;

  List<String> _opcionesEstado(String actual) {
    if (EstadosPedido.valores.contains(actual)) return EstadosPedido.valores;
    return [actual, ...EstadosPedido.valores];
  }

  Future<void> _cambiar(String? nuevo) async {
    if (nuevo == null || nuevo == _pedido.estado || _ocupado) return;
    if (!EstadosPedido.esValido(nuevo)) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await widget.repo.cambiarEstado(_pedido.id, nuevo);
      final actualizado = await widget.repo.obtenerPedido(_pedido.id);
      if (!mounted) {
        await widget.onActualizado();
        return;
      }
      if (actualizado == null) {
        Navigator.pop(context);
        await widget.onActualizado();
        return;
      }
      setState(() {
        _pedido = actualizado;
        _ocupado = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = 'No se pudo cambiar el estado.';
      });
      return;
    }
    await widget.onActualizado();
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text('¿Seguro que deseas eliminar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await widget.repo.eliminarPedido(_pedido.id);
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onActualizado();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = 'No se pudo eliminar el pedido.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detalle de Pedido'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente: ${_pedido.clienteNombre}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Fecha: ${_fechaCorta(_pedido.fecha)}'),
            const SizedBox(height: 8),
            _EstadoDbChip(estado: _pedido.estado),
            const SizedBox(height: 8),
            Text(
              'Monto total: ${_usd(_pedido.montoTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Seña: ${_usd(_pedido.montoSenado)}'),
            const SizedBox(height: 12),
            DropdownButton<String>(
              isExpanded: true,
              value: _pedido.estado,
              items: _opcionesEstado(_pedido.estado)
                  .map(
                    (estado) => DropdownMenuItem(
                      value: estado,
                      child: Text(EstadosPedido.etiqueta(estado)),
                    ),
                  )
                  .toList(),
              onChanged: _ocupado ? null : (valor) => _cambiar(valor),
            ),
            const SizedBox(height: 16),
            const Text(
              'Productos:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_pedido.items.isEmpty) const Text('Sin productos'),
            ..._pedido.items.map(
              (item) => Text(
                '${item.nombre} x${item.cantidad} · ${_usd(item.precioVenta)} c/u · ${_usd(item.subtotal)}',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Historial de estados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_pedido.historial.isEmpty)
              const Text('Sin cambios de estado.')
            else
              ..._pedido.historial.map(
                (cambio) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_fechaHora(cambio.fechaCambio)}: ${EstadosPedido.etiqueta(cambio.estadoAnterior)} → ${EstadosPedido.etiqueta(cambio.estadoNuevo)}',
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_pedido.estado == EstadosPedido.pendiente)
          TextButton(
            onPressed: _ocupado ? null : () => _eliminar(),
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
