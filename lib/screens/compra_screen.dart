import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/capital_repository.dart';
import '../data/stock_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

/// Compra a un proveedor: entra stock de un producto que ya existe.
///
/// [database] es opcional, igual que el resto de las pantallas que abre
/// Inicio. Sin base no se puede guardar. No crea productos ni tablas.
class CompraScreen extends StatefulWidget {
  const CompraScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<CompraScreen> createState() => _CompraScreenState();
}

class _CompraScreenState extends State<CompraScreen> {
  final _proveedor = TextEditingController();
  final _cantidad = TextEditingController();
  final _costo = TextEditingController();
  final _saldo = TextEditingController();

  List<ProductoStock> _productos = const [];
  int? _productoId;
  bool _cargando = false;
  bool _guardando = false;
  String? _error;
  _DatosCompra? _deudaPendiente;

  @override
  void initState() {
    super.initState();
    if (widget.database != null) {
      _cargando = true;
      _cargar();
    }
  }

  @override
  void dispose() {
    _proveedor.dispose();
    _cantidad.dispose();
    _costo.dispose();
    _saldo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final db = widget.database;
    if (db == null) return;
    try {
      final productos = await StockRepository(db).obtenerProductos();
      if (!mounted) return;
      final sigue = productos.any((producto) => producto.id == _productoId);
      setState(() {
        _productos = productos;
        if (!sigue) _productoId = null;
        _cargando = false;
        if (_deudaPendiente == null) _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        if (_deudaPendiente == null) {
          _error = 'No se pudo leer el stock: $error';
        }
      });
    }
  }

  ProductoStock? get _producto {
    for (final producto in _productos) {
      if (producto.id == _productoId) return producto;
    }
    return null;
  }

  Future<void> _guardar() async {
    final db = widget.database;
    if (db == null || _guardando) return;
    final pendiente = _deudaPendiente;
    if (pendiente != null) {
      await _anotarDeuda(db, pendiente);
      return;
    }
    final datos = _leer();
    if (datos is String) {
      setState(() => _error = datos);
      return;
    }
    final compra = datos as _DatosCompra;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar compra'),
        content: Text(_textoConfirmacion(compra)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    var stockListo = false;
    try {
      await StockRepository(db).registrarAjuste(
        productoId: compra.producto.id,
        nombre: compra.producto.nombre,
        cantidad: compra.cantidad,
        propietario: StockRepository.propietarioYo,
        tipo: StockRepository.tipoEntrada,
        descripcion: _descripcionStock(compra),
      );
      stockListo = true;
      if (compra.saldo > 0) {
        await CapitalRepository(db).registrar(
          persona: compra.proveedor,
          monto: compra.saldo,
          tipo: TiposCapital.capitalAPagar,
          descripcion: 'Compra de ${compra.producto.nombre}',
        );
      }
      try {
        final saldoTexto = compra.saldo > 0
            ? ' Saldo a pagar ${CapitalRepository.textoMonto(compra.saldo)}.'
            : '';
        await const AmpliacionLocal().anotar(
          accion: 'alta',
          entidad: 'stock',
          detalle:
              'Compra a ${compra.proveedor}: ${compra.cantidad} de ${compra.producto.nombre}.$saldoTexto',
        );
      } catch (_) {
        // La compra ya quedó. La nota de actividad no la deshace.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        if (stockListo) {
          _deudaPendiente = compra;
          _error =
              'El stock ya entró. Tocá «Anotar saldo pendiente» para guardar solo la deuda, sin sumar unidades otra vez.';
        } else {
          _error = error is StockException
              ? error.mensaje
              : 'No se pudo guardar la compra.';
        }
      });
      if (stockListo) await _cargar();
      return;
    }

    if (!mounted) return;
    _deudaPendiente = null;
    final mensaje = compra.saldo > 0
        ? 'Entraron ${compra.cantidad} de ${compra.producto.nombre}. Quedó un saldo a pagar de ${CapitalRepository.textoMonto(compra.saldo)} con ${compra.proveedor}.'
        : 'Entraron ${compra.cantidad} de ${compra.producto.nombre}. No quedó saldo con ${compra.proveedor}.';
    _cantidad.clear();
    _costo.clear();
    _saldo.clear();
    setState(() => _guardando = false);
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _anotarDeuda(AppDatabase db, _DatosCompra compra) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await CapitalRepository(db).registrar(
        persona: compra.proveedor,
        monto: compra.saldo,
        tipo: TiposCapital.capitalAPagar,
        descripcion: 'Compra de ${compra.producto.nombre}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error =
            'El stock ya entró. Sigue faltando el saldo a pagar. Podés reintentar.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _deudaPendiente = null;
      _error = null;
    });
    _cantidad.clear();
    _costo.clear();
    _saldo.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Quedó un saldo a pagar de ${CapitalRepository.textoMonto(compra.saldo)} con ${compra.proveedor}.',
        ),
      ),
    );
  }

  Object _leer() {
    final proveedor = _proveedor.text.trim();
    if (proveedor.isEmpty) return 'Ingresá el proveedor.';
    final producto = _producto;
    if (producto == null || producto.id == null) {
      return 'Elegí un producto que ya esté en el stock.';
    }
    final cantidad = _entero(_cantidad.text);
    if (cantidad == null || cantidad <= 0) {
      return 'La cantidad tiene que ser un entero mayor a cero.';
    }
    final costo = _opcional(_costo.text);
    if (costo == null && _costo.text.trim().isNotEmpty) {
      return 'El costo unitario tiene que ser un número mayor o igual a cero.';
    }
    final saldo = _opcional(_saldo.text);
    if (saldo == null && _saldo.text.trim().isNotEmpty) {
      return 'El saldo a pagar tiene que ser un número mayor o igual a cero.';
    }
    return _DatosCompra(
      proveedor: proveedor,
      producto: producto,
      cantidad: cantidad,
      costo: costo,
      saldo: saldo ?? 0,
    );
  }

  int? _entero(String texto) {
    final limpio = texto.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    final entero = int.tryParse(limpio);
    if (entero != null) return entero;
    final decimal = double.tryParse(limpio);
    if (decimal == null || decimal != decimal.truncateToDouble()) return null;
    return decimal.toInt();
  }

  double? _opcional(String texto) {
    final limpio = texto.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    final valor = double.tryParse(limpio);
    if (valor == null || valor.isNaN || valor.isInfinite || valor < 0) {
      return null;
    }
    return CapitalRepository.enCentavos(valor) / 100;
  }

  String _descripcionStock(_DatosCompra compra) {
    final base = 'Compra a ${compra.proveedor}';
    final costo = compra.costo;
    if (costo == null) return base;
    return '$base · costo unitario ${CapitalRepository.textoMonto(costo)}';
  }

  String _textoConfirmacion(_DatosCompra compra) {
    final entrada =
        'Entran ${compra.cantidad} de ${compra.producto.nombre} al stock de Yo. La descripción nombra a ${compra.proveedor}.';
    if (compra.saldo > 0) {
      return '$entrada\n\nQueda un saldo a pagar de ${CapitalRepository.textoMonto(compra.saldo)} con ${compra.proveedor}.';
    }
    return '$entrada\n\nNo queda saldo a pagar.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text('Compra al proveedor')),
      body: FondoGexi(
        child: widget.database == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No hay base conectada.',
                    style: TextStyle(color: AppColors.textoSuave),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _cargando && _productos.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      const Text(
                        'Suma unidades de un producto que ya existe. El stock entra a nombre de Yo. Si el saldo a pagar es mayor a cero, queda como deuda con el proveedor.',
                        style: TextStyle(
                            color: AppColors.textoSuave, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppColors.tarjeta,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _proveedor,
                              enabled: _deudaPendiente == null,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Proveedor',
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_productos.isEmpty)
                              const Text(
                                'No hay productos cargados. Primero tenés que tener stock.',
                                style: TextStyle(color: AppColors.textoSuave),
                              )
                            else
                              DropdownButtonFormField<int>(
                                initialValue: _productoId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Producto',
                                ),
                                items: [
                                  for (final producto in _productos)
                                    if (producto.id != null)
                                      DropdownMenuItem(
                                        value: producto.id,
                                        child: Text(
                                          producto.nombre,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                ],
                                onChanged: _guardando || _deudaPendiente != null
                                    ? null
                                    : (valor) =>
                                        setState(() => _productoId = valor),
                              ),
                            if (_producto != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Stock de Yo: ${_producto!.stockYo}',
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: _cantidad,
                              enabled: _deudaPendiente == null,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Cantidad',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _costo,
                              enabled: _deudaPendiente == null,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Costo unitario (opcional)',
                                helperText:
                                    'Si lo completás, queda en la descripción de la entrada. No cambia el precio guardado del producto.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _saldo,
                              enabled: _deudaPendiente == null,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Saldo a pagar (opcional)',
                                helperText:
                                    'Dejalo vacío o en cero si ya está pago. Si es mayor a cero, se anota como capital a pagar.',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(color: AppColors.alerta),
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _guardando ||
                                      (_deudaPendiente == null &&
                                          _productos.isEmpty)
                                  ? null
                                  : _guardar,
                              child: Text(
                                _guardando
                                    ? 'Guardando...'
                                    : _deudaPendiente == null
                                        ? 'Guardar compra'
                                        : 'Anotar saldo pendiente',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _DatosCompra {
  const _DatosCompra({
    required this.proveedor,
    required this.producto,
    required this.cantidad,
    required this.costo,
    required this.saldo,
  });

  final String proveedor;
  final ProductoStock producto;
  final int cantidad;
  final double? costo;
  final double saldo;
}
