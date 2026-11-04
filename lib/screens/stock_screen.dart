import 'package:flutter/material.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/stock_repository.dart';
import '../theme/app_theme.dart';
import 'ficha_producto_panel.dart';

/// Gestión de stock.
///
/// [database] es opcional y no es `required`, así `const StockScreen()` sigue
/// compilando. Si es null, se mantienen los datos de demostración en memoria.
/// Si no es null, los productos y las cantidades se leen y escriben en Drift.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  StockRepository? _repo;
  List<ProductoStock> _productos = [];
  Map<int, FichaProducto> _fichas = {};
  bool _cargando = false;
  String? _error;
  int _cargaToken = 0;

  bool get _usaBase => _repo != null;

  @override
  void initState() {
    super.initState();
    _vincularBase(widget.database, notificar: false);
  }

  @override
  void didUpdateWidget(StockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      _vincularBase(widget.database, notificar: true);
    }
  }

  void _vincularBase(AppDatabase? database, {required bool notificar}) {
    _cargaToken++;
    void aplicar() {
      _error = null;
      if (database == null) {
        _repo = null;
        _productos = _demostracion();
        _cargando = false;
        return;
      }
      _repo = StockRepository(database);
      _cargando = true;
    }

    if (notificar) {
      setState(aplicar);
    } else {
      aplicar();
    }
    if (database != null) {
      _cargar(anunciar: false);
    }
  }

  List<ProductoStock> _demostracion() {
    return [
      const ProductoStock(
        nombre: 'Powerbank',
        precioCompra: 10,
        precioVenta: 15,
        stockYo: 30,
        stockNildo: 20,
      ),
      const ProductoStock(
        nombre: 'Cable USB',
        precioCompra: 1,
        precioVenta: 2,
        stockYo: 70,
        stockNildo: 30,
      ),
    ];
  }

  Future<void> _cargar({bool silencioso = false, bool anunciar = true}) async {
    final repo = _repo;
    if (repo == null) return;
    final token = ++_cargaToken;
    if (!silencioso && anunciar && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final productos = await repo.obtenerProductos();
      final fichas = await const AmpliacionLocal().cargar();
      if (!mounted || token != _cargaToken) return;
      setState(() {
        _productos = productos;
        _fichas = fichas.fichas;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || token != _cargaToken) return;
      if (silencioso) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el stock: $e')),
        );
        return;
      }
      setState(() {
        _cargando = false;
        _error = 'No se pudo leer el stock: $e';
      });
    }
  }

  Future<void> _mostrarAlta() {
    return showDialog<void>(
      context: context,
      builder: (context) => _AltaStockDialog(onGuardar: _guardarEntrada),
    );
  }

  Future<void> _guardarEntrada({
    required String nombre,
    required int cantidad,
    required double precioCompra,
    required double? precioVenta,
    required String propietario,
  }) async {
    final repo = _repo;
    if (repo != null) {
      await repo.registrarEntrada(
        nombre: nombre,
        cantidad: cantidad,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
        propietario: propietario,
      );
      await const AmpliacionLocal().anotar(
        accion: 'alta',
        entidad: 'stock',
        detalle: 'Entrada de $cantidad de $nombre',
      );
      if (!mounted) return;
      await _cargar(silencioso: true);
      return;
    }

    final indice = _productos.indexWhere(
      (producto) => producto.nombre.toLowerCase() == nombre.toLowerCase(),
    );
    final esYo = propietario == StockRepository.propietarioYo;
    if (indice < 0) {
      _productos.add(
        ProductoStock(
          nombre: nombre,
          precioCompra: precioCompra,
          precioVenta: precioVenta ?? 0,
          stockYo: esYo ? cantidad : 0,
          stockNildo: esYo ? 0 : cantidad,
        ),
      );
    } else {
      final actual = _productos[indice];
      _productos[indice] = actual.copyWith(
        precioCompra: precioCompra,
        precioVenta: precioVenta,
        stockYo: esYo ? actual.stockYo + cantidad : actual.stockYo,
        stockNildo: esYo ? actual.stockNildo : actual.stockNildo + cantidad,
      );
    }
    if (!mounted) return;
    setState(() {});
  }

  void _abrirDetalle(ProductoStock producto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleProductoScreen(
          producto: producto,
          repositorio: _repo,
          onActualizado: _aplicarActualizacion,
        ),
      ),
    );
  }

  void _aplicarActualizacion(ProductoStock producto) {
    if (_usaBase) {
      _cargar(silencioso: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      final indice = _productos.indexWhere(
        (item) => item.nombre.toLowerCase() == producto.nombre.toLowerCase(),
      );
      if (indice >= 0) {
        _productos[indice] = producto;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Gestión de Stock',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: ElevatedButton.icon(
              onPressed: _mostrarAlta,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Añadir stock',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: const StadiumBorder(),
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
      body: _buildCuerpo(context),
    );
  }

  Widget _buildCuerpo(BuildContext context) {
    if (_cargando && _productos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _productos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _cargar(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: _productos.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay productos cargados. Usá «Añadir stock» para registrar el primero.',
              ),
            )
          : Scrollbar(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Producto',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Stock total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Tu stock',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Stock de Nildo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Precio compra',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Precio venta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: [
                      for (final producto in _productos)
                        DataRow(
                          onSelectChanged: (_) => _abrirDetalle(producto),
                          cells: [
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto.nombre,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (_stockBajo(producto))
                                    const Text(
                                      'Stock bajo',
                                      style: TextStyle(
                                        color: AppColors.alerta,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(Text('${producto.stockTotal}')),
                            DataCell(Text('${producto.stockYo}')),
                            DataCell(Text('${producto.stockNildo}')),
                            DataCell(Text(_moneda(producto.precioCompra))),
                            DataCell(Text(_moneda(producto.precioVenta))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  bool _stockBajo(ProductoStock producto) {
    final ficha = producto.id == null ? null : _fichas[producto.id];
    if (ficha != null && !ficha.controlaStock) return false;
    final umbral = ficha?.umbral ?? 2;
    return producto.stockTotal <= umbral;
  }
}

typedef _GuardarEntrada = Future<void> Function({
  required String nombre,
  required int cantidad,
  required double precioCompra,
  required double? precioVenta,
  required String propietario,
});

class _AltaStockDialog extends StatefulWidget {
  const _AltaStockDialog({required this.onGuardar});

  final _GuardarEntrada onGuardar;

  @override
  State<_AltaStockDialog> createState() => _AltaStockDialogState();
}

class _AltaStockDialogState extends State<_AltaStockDialog> {
  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _compraCtrl = TextEditingController();
  final _ventaCtrl = TextEditingController();
  var _propietario = StockRepository.propietarioYo;
  var _guardando = false;
  String? _mensajeError;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _compraCtrl.dispose();
    _ventaCtrl.dispose();
    super.dispose();
  }

  String? _validar() {
    if (_nombreCtrl.text.trim().isEmpty) {
      return 'El nombre del producto es obligatorio.';
    }
    final cantidad = _parseEntero(_cantidadCtrl.text);
    if (cantidad == null || cantidad <= 0) {
      return 'La cantidad debe ser un entero mayor a cero.';
    }
    final compra = _parseDecimal(_compraCtrl.text);
    if (compra == null || compra < 0) {
      return 'Ingresá un precio de compra válido.';
    }
    if (_ventaCtrl.text.trim().isNotEmpty) {
      final venta = _parseDecimal(_ventaCtrl.text);
      if (venta == null || venta < 0) {
        return 'Ingresá un precio de venta válido.';
      }
    }
    return null;
  }

  Future<void> _guardar() async {
    final error = _validar();
    if (error != null) {
      setState(() => _mensajeError = error);
      return;
    }
    setState(() {
      _guardando = true;
      _mensajeError = null;
    });
    try {
      await widget.onGuardar(
        nombre: _nombreCtrl.text.trim(),
        cantidad: _parseEntero(_cantidadCtrl.text)!,
        precioCompra: _parseDecimal(_compraCtrl.text)!,
        precioVenta: _parseDecimal(_ventaCtrl.text),
        propietario: _propietario,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _mensajeError =
            e is StockException ? e.mensaje : 'No se pudo guardar el stock: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Añadir stock',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cantidadCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _compraCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Precio de compra'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ventaCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio de venta (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _propietario,
              items: const [
                DropdownMenuItem(
                  value: StockRepository.propietarioYo,
                  child: Text('Yo'),
                ),
                DropdownMenuItem(
                  value: StockRepository.propietarioNildo,
                  child: Text('Nildo'),
                ),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) {
                      if (valor == null) return;
                      setState(() => _propietario = valor);
                    },
              decoration: const InputDecoration(
                labelText: 'Propietario del stock',
              ),
            ),
            if (_mensajeError != null) ...[
              const SizedBox(height: 12),
              Text(
                _mensajeError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class DetalleProductoScreen extends StatefulWidget {
  const DetalleProductoScreen({
    super.key,
    required this.producto,
    required this.onActualizado,
    this.repositorio,
  });

  final ProductoStock producto;
  final StockRepository? repositorio;
  final ValueChanged<ProductoStock> onActualizado;

  @override
  State<DetalleProductoScreen> createState() => _DetalleProductoScreenState();
}

class _DetalleProductoScreenState extends State<DetalleProductoScreen> {
  late ProductoStock _producto;
  List<MovimientoStockVista> _movimientos = [];
  bool _cargandoHistorial = false;
  bool _guardandoPrecios = false;
  bool _guardandoNombre = false;
  bool _guardandoAjuste = false;
  String _propietario = StockRepository.propietarioYo;
  String _tipo = StockRepository.tipoEntrada;
  String? _errorPrecios;
  String? _errorNombre;
  String? _errorAjuste;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _compraCtrl;
  late final TextEditingController _ventaCtrl;
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _descripcionCtrl;

  @override
  void initState() {
    super.initState();
    _producto = widget.producto;
    _nombreCtrl = TextEditingController(text: _producto.nombre);
    _compraCtrl =
        TextEditingController(text: _textoPrecio(_producto.precioCompra));
    _ventaCtrl =
        TextEditingController(text: _textoPrecio(_producto.precioVenta));
    _cantidadCtrl = TextEditingController();
    _descripcionCtrl = TextEditingController();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _compraCtrl.dispose();
    _ventaCtrl.dispose();
    _cantidadCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    final repo = widget.repositorio;
    final id = _producto.id;
    if (repo == null || id == null) return;
    setState(() => _cargandoHistorial = true);
    try {
      final movimientos = await repo.movimientosDe(id);
      if (!mounted) return;
      setState(() {
        _movimientos = movimientos;
        _cargandoHistorial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoHistorial = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo leer el historial: $e')),
      );
    }
  }

  Future<void> _guardarNombre() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _errorNombre = 'El nombre no puede quedar vacío.');
      return;
    }
    setState(() {
      _guardandoNombre = true;
      _errorNombre = null;
    });
    try {
      final repo = widget.repositorio;
      final id = _producto.id;
      if (repo != null && id != null) {
        await repo.renombrar(productoId: id, nombre: nombre);
        final fresco = await repo.obtenerPorId(id);
        if (!mounted) return;
        final actualizado = fresco ?? _producto.copyWith(nombre: nombre);
        setState(() {
          _producto = actualizado;
          _guardandoNombre = false;
        });
        widget.onActualizado(actualizado);
        return;
      }
      if (!mounted) return;
      final actualizado = _producto.copyWith(nombre: nombre);
      setState(() {
        _producto = actualizado;
        _guardandoNombre = false;
      });
      widget.onActualizado(actualizado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardandoNombre = false;
        _errorNombre = e is StockException
            ? e.mensaje
            : 'No se pudo cambiar el nombre: $e';
      });
    }
  }

  Future<void> _guardarPrecios() async {
    final compra = _parseDecimal(_compraCtrl.text);
    final venta = _parseDecimal(_ventaCtrl.text);
    if (compra == null || compra < 0 || venta == null || venta < 0) {
      setState(() {
        _errorPrecios = 'Ingresá precios válidos, mayores o iguales a cero.';
      });
      return;
    }

    setState(() {
      _guardandoPrecios = true;
      _errorPrecios = null;
    });
    try {
      final repo = widget.repositorio;
      final id = _producto.id;
      if (repo != null && id != null) {
        await repo.actualizarPrecios(
          productoId: id,
          precioCompra: compra,
          precioVenta: venta,
        );
        final fresco = await repo.obtenerPorId(id);
        if (!mounted) return;
        final actualizado = fresco ??
            _producto.copyWith(precioCompra: compra, precioVenta: venta);
        setState(() {
          _producto = actualizado;
          _guardandoPrecios = false;
        });
        widget.onActualizado(actualizado);
        return;
      }

      final actualizado = _producto.copyWith(
        precioCompra: compra,
        precioVenta: venta,
      );
      if (!mounted) return;
      setState(() {
        _producto = actualizado;
        _guardandoPrecios = false;
      });
      widget.onActualizado(actualizado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardandoPrecios = false;
        _errorPrecios = e is StockException
            ? e.mensaje
            : 'No se pudieron guardar los precios: $e';
      });
    }
  }

  Future<void> _guardarAjuste() async {
    final cantidad = _parseEntero(_cantidadCtrl.text);
    if (cantidad == null || cantidad <= 0) {
      setState(() {
        _errorAjuste = 'La cantidad debe ser un entero mayor a cero.';
      });
      return;
    }
    final esYo = _propietario == StockRepository.propietarioYo;
    final disponible = esYo ? _producto.stockYo : _producto.stockNildo;
    if (_tipo == StockRepository.tipoSalida && cantidad > disponible) {
      setState(() {
        _errorAjuste = 'No hay stock suficiente para esa salida.';
      });
      return;
    }

    setState(() {
      _guardandoAjuste = true;
      _errorAjuste = null;
    });
    try {
      final repo = widget.repositorio;
      final id = _producto.id;
      if (repo != null && id != null) {
        await repo.registrarAjuste(
          productoId: id,
          nombre: _producto.nombre,
          cantidad: cantidad,
          propietario: _propietario,
          tipo: _tipo,
          descripcion: _descripcionCtrl.text,
        );
        final fresco = await repo.obtenerPorId(id);
        final movimientos = await repo.movimientosDe(id);
        if (!mounted) return;
        final actualizado = fresco ?? _producto;
        setState(() {
          _producto = actualizado;
          _movimientos = movimientos;
          _guardandoAjuste = false;
          _cantidadCtrl.clear();
          _descripcionCtrl.clear();
        });
        widget.onActualizado(actualizado);
        return;
      }

      final delta = _tipo == StockRepository.tipoEntrada ? cantidad : -cantidad;
      final actualizado = _producto.copyWith(
        stockYo: esYo ? _producto.stockYo + delta : _producto.stockYo,
        stockNildo: esYo ? _producto.stockNildo : _producto.stockNildo + delta,
      );
      if (!mounted) return;
      setState(() {
        _producto = actualizado;
        _guardandoAjuste = false;
        _cantidadCtrl.clear();
        _descripcionCtrl.clear();
      });
      widget.onActualizado(actualizado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardandoAjuste = false;
        _errorAjuste = e is StockException
            ? e.mensaje
            : 'No se pudo registrar el ajuste: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usaBase = widget.repositorio != null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Detalle: ${_producto.nombre}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    if (_errorNombre != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorNombre!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (_producto.precioVenta > 0 || _producto.precioCompra > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Margen: ${_moneda(_producto.precioVenta - _producto.precioCompra)}',
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _guardandoNombre ? null : _guardarNombre,
                        child: Text(
                          _guardandoNombre ? 'Guardando...' : 'Guardar nombre',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Precio de compra: ${_moneda(_producto.precioCompra)}'),
                    Text('Precio de venta: ${_moneda(_producto.precioVenta)}'),
                    Text('Tu stock: ${_producto.stockYo}'),
                    Text('Stock de Nildo: ${_producto.stockNildo}'),
                    Text(
                      'Stock total: ${_producto.stockTotal}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      usaBase
                          ? 'Los cambios se guardan en este dispositivo. Si el negocio está en la nube, también se copian ahí.'
                          : 'Modo demostración: los cambios quedan solo en memoria.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (_producto.id != null) ...[
              const SizedBox(height: 16),
              FichaProductoPanel(productoId: _producto.id!),
            ],
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Precios',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _compraCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio de compra',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ventaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio de venta',
                      ),
                    ),
                    if (_errorPrecios != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorPrecios!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _guardandoPrecios ? null : _guardarPrecios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _guardandoPrecios ? 'Guardando...' : 'Guardar precios',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ajuste de stock',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _propietario,
                      decoration: const InputDecoration(
                        labelText: 'Propietario',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: StockRepository.propietarioYo,
                          child: Text('Yo'),
                        ),
                        DropdownMenuItem(
                          value: StockRepository.propietarioNildo,
                          child: Text('Nildo'),
                        ),
                      ],
                      onChanged: _guardandoAjuste
                          ? null
                          : (valor) {
                              if (valor == null) return;
                              setState(() => _propietario = valor);
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de movimiento',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: StockRepository.tipoEntrada,
                          child: Text('Entrada'),
                        ),
                        DropdownMenuItem(
                          value: StockRepository.tipoSalida,
                          child: Text('Salida'),
                        ),
                      ],
                      onChanged: _guardandoAjuste
                          ? null
                          : (valor) {
                              if (valor == null) return;
                              setState(() => _tipo = valor);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cantidadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descripcionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                      ),
                    ),
                    if (_errorAjuste != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorAjuste!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _guardandoAjuste ? null : _guardarAjuste,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _guardandoAjuste ? 'Guardando...' : 'Registrar ajuste',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (!usaBase)
                      Text(
                        'El historial se registra cuando la pantalla usa la base de datos.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else if (_cargandoHistorial)
                      const Center(child: CircularProgressIndicator())
                    else if (_movimientos.isEmpty)
                      const Text('Todavía no hay movimientos.')
                    else
                      for (final movimiento in _movimientos) ...[
                        Text(
                          '${_etiquetaTipo(movimiento.tipo)} · ${movimiento.cantidad} · ${movimiento.propietario}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (movimiento.descripcion != null &&
                            movimiento.descripcion!.isNotEmpty)
                          Text(movimiento.descripcion!),
                        Text(
                          _fecha(movimiento.fechaCarga),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _etiquetaTipo(String tipo) {
  switch (tipo) {
    case StockRepository.tipoEntrada:
      return 'Entrada';
    case StockRepository.tipoSalida:
      return 'Salida';
    default:
      return tipo;
  }
}

String _moneda(double valor) => 'US\$ ${valor.toStringAsFixed(2)}';

String _textoPrecio(double valor) {
  final texto = valor.toStringAsFixed(2);
  if (texto.endsWith('.00')) {
    return texto.substring(0, texto.length - 3);
  }
  return texto;
}

String _fecha(DateTime fecha) {
  final local = fecha.toLocal();
  String dos(int numero) => numero.toString().padLeft(2, '0');
  return '${dos(local.day)}/${dos(local.month)}/${local.year} '
      '${dos(local.hour)}:${dos(local.minute)}';
}

int? _parseEntero(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty) return null;
  return int.tryParse(limpio);
}

double? _parseDecimal(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  return double.tryParse(limpio);
}
