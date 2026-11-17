import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/stock_repository.dart';
import '../data/vidriera_local.dart';
import '../services/asistente/foto_catalogo_asistente.dart';
import '../services/negocio_local.dart';
import '../services/openai_chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/elegir_foto.dart';
import '../utils/moneda.dart';
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

const _topeImagenesProducto = 4;

class _StockScreenState extends State<StockScreen> {
  StockRepository? _repo;
  List<ProductoStock> _productos = [];
  Map<int, FichaProducto> _fichas = {};
  Map<int, List<String>> _fotos = {};
  bool _cargando = false;
  String? _error;
  int _cargaToken = 0;
  final _busqueda = TextEditingController();

  bool get _usaBase => _repo != null;
  String _codigoMoneda = monedaPorDefecto;

  @override
  void initState() {
    super.initState();
    _leerMoneda();
    _vincularBase(widget.database, notificar: false);
  }

  Future<void> _leerMoneda() async {
    final codigo = await monedaDelNegocio();
    if (!mounted || codigo == _codigoMoneda) return;
    setState(() => _codigoMoneda = codigo);
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
      final vidriera = await const VidrieraLocal().cargar();
      if (!mounted || token != _cargaToken) return;
      setState(() {
        _productos = productos;
        _fichas = fichas.fichas;
        _fotos = {
          for (final entrada in vidriera.entries)
            entrada.key: _fotosGenerales(entrada.value),
        };
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
    String? fotoBase64,
    required String categoria,
  }) async {
    final repo = _repo;
    final foto = fotoBase64?.trim() ?? '';
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
      if (categoria.trim().isNotEmpty) {
        try {
          await _asignarCategoria(nombre, categoria.trim());
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El stock se guardó. No se pudo asignar la categoría.'),
              ),
            );
          }
        }
      }
      if (foto.isNotEmpty) {
        try {
          await _adjuntarFotoDeEntrada(nombre, foto);
        } catch (error) {
          if (mounted) {
            final texto = error is VidrieraRechazada
                ? error.mensaje
                : 'No se pudo guardar la foto.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('El stock se guardó. $texto')),
            );
          }
        }
      }
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
    if (foto.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El stock quedó en memoria. En este modo la foto no se guarda.',
          ),
        ),
      );
    }
  }

  Future<void> _asignarCategoria(String nombre, String categoria) async {
    final repo = _repo;
    if (repo == null) return;
    final productos = await repo.obtenerProductos();
    ProductoStock? hallado;
    for (final producto in productos) {
      if (producto.nombre.toLowerCase() == nombre.toLowerCase()) {
        hallado = producto;
        break;
      }
    }
    final id = hallado?.id;
    if (id == null) return;
    final doc = await const AmpliacionLocal().cargar();
    final actual = doc.fichas[id] ?? const FichaProducto();
    final elegidas = [
      for (final item in actual.todas)
        if (item.toLowerCase() != categoria.toLowerCase()) item,
      categoria,
    ];
    await const AmpliacionLocal().guardarFicha(
      id,
      FichaProducto(
        categoria: elegidas.first,
        categorias: elegidas,
        atributos: actual.atributos,
        controlaStock: actual.controlaStock,
        visibleEnTienda: actual.visibleEnTienda,
        umbral: actual.umbral,
        unidades: actual.unidades,
        variantes: actual.variantes,
      ),
    );
  }

  Future<void> _adjuntarFotoDeEntrada(String nombre, String fotoBase64) async {
    final repo = _repo;
    if (repo == null) {
      throw const VidrieraRechazada(
        'En el modo de demostración la foto no se guarda.',
      );
    }
    final productos = await repo.obtenerProductos();
    ProductoStock? hallado;
    for (final producto in productos) {
      if (producto.nombre.toLowerCase() == nombre.toLowerCase()) {
        hallado = producto;
        break;
      }
    }
    final id = hallado?.id;
    if (id == null) {
      throw const VidrieraRechazada(
        'No encontré el producto para adjuntar la foto.',
      );
    }
    await _sumarFotos(id, [fotoBase64]);
  }

  List<String> _fotosGenerales(DatoVidriera dato) {
    return [
      for (final foto in dato.galeria)
        if (foto.variante.trim().isEmpty && foto.base64.isNotEmpty) foto.base64,
    ];
  }

  List<String> _imagenesDe(ProductoStock producto) {
    final id = producto.id;
    if (id == null) return const [];
    return _fotos[id] ?? const [];
  }

  Future<void> _sumarFotos(int productoId, List<String> nuevas) async {
    if (nuevas.isEmpty) return;
    final actual = await const VidrieraLocal().de(productoId);
    final generales = _fotosGenerales(actual);
    final variantes = [
      for (final foto in actual.galeria)
        if (foto.variante.trim().isNotEmpty) foto,
    ];
    final cupo = _topeImagenesProducto - generales.length;
    if (cupo <= 0) {
      throw const VidrieraRechazada(
        'Este producto ya tiene 4 imágenes.',
      );
    }
    final aceptadas = <FotoVidriera>[];
    for (final foto in nuevas) {
      if (aceptadas.length >= cupo) break;
      final rechazo = motivoRechazoFoto(foto);
      if (rechazo != null) throw VidrieraRechazada(rechazo);
      aceptadas.add(FotoVidriera(base64: foto));
    }
    await const VidrieraLocal().guardar(
      productoId: productoId,
      descripcion: actual.descripcion,
      fotoBase64: '',
      fotos: [
        for (final foto in generales) FotoVidriera(base64: foto),
        ...aceptadas,
        ...variantes,
      ],
    );
  }

  Future<void> _gestionarImagenes(ProductoStock producto) async {
    final id = producto.id;
    if (id == null) {
      _avisar('En este modo la imagen no se guarda.');
      return;
    }
    final cambio = await showDialog<bool>(
      context: context,
      builder: (context) => _ImagenesProductoDialog(
        productoId: id,
        nombre: producto.nombre,
        iniciales: _imagenesDe(producto),
      ),
    );
    if (cambio == true && mounted) await _cargar(silencioso: true);
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
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
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Stock',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'anadir-stock',
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: _mostrarAlta,
        icon: const Icon(Icons.add),
        label: const Text(
          'Añadir stock',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
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
              FilledButton(
                onPressed: () => _cargar(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final bajos = _productos.where(_stockBajo).length;
    final visibles = _visibles;
    final buscando = _busqueda.text.trim().isNotEmpty;
    return Column(
      children: [
        if (_productos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _busqueda,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar producto',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: buscando
                    ? IconButton(
                        tooltip: 'Borrar',
                        onPressed: () {
                          _busqueda.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        Expanded(
          child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        if (_productos.isNotEmpty && !buscando) ...[
          const _TituloStock('Resumen'),
          DecoratedBox(
            decoration: AppColors.tarjeta,
            child: Column(
              children: [
                _FilaStock(
                  icono: Icons.inventory_2_outlined,
                  color: AppColors.primario,
                  titulo: 'Productos',
                  detalle: 'Tocá uno para ver precios y movimientos',
                  valor: '${_productos.length}',
                ),
                const Divider(height: 1, indent: 66, color: AppColors.linea),
                _FilaStock(
                  icono: Icons.warning_amber_rounded,
                  color: bajos == 0 ? AppColors.lima : AppColors.alerta,
                  titulo: 'Stock bajo',
                  detalle: bajos == 0
                      ? 'Ninguno por debajo del mínimo'
                      : 'Conviene reponer',
                  valor: '$bajos',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
        const _TituloStock('Productos'),
        DecoratedBox(
          decoration: AppColors.tarjeta,
          child: _productos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Todavía no hay productos. Tocá Añadir stock para cargar el primero.',
                    style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                  ),
                )
              : visibles.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Ningún producto coincide con la búsqueda.',
                        style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                      ),
                    )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: [
                      for (var i = 0; i < visibles.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 78,
                            color: AppColors.linea,
                          ),
                        _FilaProducto(
                          producto: visibles[i],
                          fotos: _imagenesDe(visibles[i]),
                          bajo: _stockBajo(visibles[i]),
                          moneda: _codigoMoneda,
                          onTap: () => _abrirDetalle(visibles[i]),
                          onFoto: () => _gestionarImagenes(visibles[i]),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
          ),
        ),
      ],
    );
  }

  bool _stockBajo(ProductoStock producto) {
    final ficha = producto.id == null ? null : _fichas[producto.id];
    if (ficha != null && !ficha.controlaStock) return false;
    final umbral = ficha?.umbral ?? 2;
    return producto.stockTotal <= umbral;
  }

  List<ProductoStock> get _visibles {
    final consulta = _plano(_busqueda.text);
    if (consulta.isEmpty) return _productos;
    return [
      for (final producto in _productos)
        if (_plano(producto.nombre).contains(consulta)) producto,
    ];
  }

  String _plano(String texto) {
    const origen = 'áéíóúüñ';
    const destino = 'aeiouun';
    var salida = texto.trim().toLowerCase();
    for (var i = 0; i < origen.length; i++) {
      salida = salida.replaceAll(origen[i], destino[i]);
    }
    return salida;
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }
}

class _CeldaImagen extends StatelessWidget {
  const _CeldaImagen({required this.fotos, required this.onTap});

  final List<String> fotos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primera = fotos.isEmpty ? null : bytesDeFotoVidriera(fotos.first);
    if (primera == null) {
      return Material(
        color: AppColors.limaBrillo,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              Icons.add_a_photo_outlined,
              color: AppColors.primario,
              size: 22,
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              primera,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          if (fotos.length > 1)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.texto,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${fotos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TituloStock extends StatelessWidget {
  const _TituloStock(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textoSuave,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _FilaStock extends StatelessWidget {
  const _FilaStock({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.detalle,
    required this.valor,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String detalle;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            valor,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({
    required this.producto,
    required this.fotos,
    required this.bajo,
    required this.moneda,
    required this.onTap,
    required this.onFoto,
  });

  final ProductoStock producto;
  final List<String> fotos;
  final bool bajo;
  final String moneda;
  final VoidCallback onTap;
  final VoidCallback onFoto;

  @override
  Widget build(BuildContext context) {
    final colorCantidad = bajo ? AppColors.alerta : AppColors.texto;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _CeldaImagen(fotos: fotos, onTap: onFoto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Venta ${formatearMoneda(producto.precioVenta, moneda)}',
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 13,
                      ),
                    ),
                    if (bajo)
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
              const SizedBox(width: 8),
              Text(
                '${producto.stockTotal}',
                style: TextStyle(
                  color: colorCantidad,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagenesProductoDialog extends StatefulWidget {
  const _ImagenesProductoDialog({
    required this.productoId,
    required this.nombre,
    required this.iniciales,
  });

  final int productoId;
  final String nombre;
  final List<String> iniciales;

  @override
  State<_ImagenesProductoDialog> createState() => _ImagenesProductoDialogState();
}

class _ImagenesProductoDialogState extends State<_ImagenesProductoDialog> {
  late List<String> _fotos = List<String>.of(widget.iniciales);
  bool _guardando = false;
  bool _generando = false;
  bool _cambio = false;
  String? _error;

  Future<void> _generar() async {
    if (_guardando || _generando) return;
    if (_fotos.length >= _topeImagenesProducto) {
      setState(() => _error = 'Este producto ya tiene 4 imágenes.');
      return;
    }
    final nombre = widget.nombre.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Falta el nombre del producto para generar la imagen.');
      return;
    }
    setState(() {
      _generando = true;
      _error = null;
    });
    try {
      final actual = await const VidrieraLocal().de(widget.productoId);
      final texto = await _fotoGenerada(
        nombre: nombre,
        descripcion: actual.descripcion,
      );
      if (!mounted) return;
      final rechazo = motivoRechazoFoto(texto);
      if (rechazo != null) {
        setState(() => _error = rechazo);
        return;
      }
      final variantes = [
        for (final foto in actual.galeria)
          if (foto.variante.trim().isNotEmpty) foto,
      ];
      await const VidrieraLocal().guardar(
        productoId: widget.productoId,
        descripcion: actual.descripcion,
        fotoBase64: '',
        fotos: [
          for (final foto in _fotos) FotoVidriera(base64: foto),
          FotoVidriera(base64: texto),
          ...variantes,
        ],
      );
      if (!mounted) return;
      setState(() {
        _fotos = [..._fotos, texto];
        _cambio = true;
      });
    } on ChatIaException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.mensaje);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is VidrieraRechazada
            ? error.mensaje
            : 'No se pudo generar la imagen.';
      });
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _agregar() async {
    if (_guardando || _generando) return;
    if (_fotos.length >= _topeImagenesProducto) {
      setState(() => _error = 'Este producto ya tiene 4 imágenes.');
      return;
    }
    final origen = await preguntarOrigenFoto(context);
    if (origen == null || !mounted) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final archivos = await elegirFotos(
        origen: origen,
        variasEnGaleria: true,
      );
      if (!mounted) return;
      if (archivos.isEmpty) return;
      final cupo = _topeImagenesProducto - _fotos.length;
      final tomadas = archivos.take(cupo).toList();
      final nuevas = <String>[];
      for (final archivo in tomadas) {
        final texto = base64Encode(await archivo.readAsBytes());
        final rechazo = motivoRechazoFoto(texto);
        if (rechazo != null) {
          setState(() => _error = rechazo);
          return;
        }
        nuevas.add(texto);
      }
      final actual = await const VidrieraLocal().de(widget.productoId);
      final variantes = [
        for (final foto in actual.galeria)
          if (foto.variante.trim().isNotEmpty) foto,
      ];
      await const VidrieraLocal().guardar(
        productoId: widget.productoId,
        descripcion: actual.descripcion,
        fotoBase64: '',
        fotos: [
          for (final foto in _fotos) FotoVidriera(base64: foto),
          for (final foto in nuevas) FotoVidriera(base64: foto),
          ...variantes,
        ],
      );
      if (!mounted) return;
      setState(() {
        _fotos = [..._fotos, ...nuevas];
        _cambio = true;
        _error = archivos.length > cupo
            ? 'Se guardaron $cupo. El máximo es 4 imágenes.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is VidrieraRechazada
            ? error.mensaje
            : 'No se pudo guardar la imagen.';
      });
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lleno = _fotos.length >= _topeImagenesProducto;
    final ocupado = _guardando || _generando;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.nombre),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _fotos.isEmpty
                  ? 'Todavía no tiene imágenes. Podés agregar hasta 4.'
                  : '${_fotos.length} de $_topeImagenesProducto imágenes.',
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            if (_fotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final foto in _fotos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(foto),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const SizedBox(
                          width: 72,
                          height: 72,
                          child: ColoredBox(
                            color: Color(0xFFF3F4F6),
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: ocupado || lleno ? null : _agregar,
              icon: Icon(
                _guardando ? Icons.hourglass_top : Icons.add_a_photo_outlined,
              ),
              label: Text(_guardando ? 'Guardando...' : 'Agregar imagen'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: ocupado || lleno ? null : _generar,
              icon: Icon(
                _generando ? Icons.hourglass_top : Icons.auto_awesome_outlined,
              ),
              label: Text(
                _generando ? 'Generando...' : 'Generar según título y descripción',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.alerta)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: ocupado
              ? null
              : () => Navigator.pop(context, _cambio),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

typedef _GuardarEntrada = Future<void> Function({
  required String nombre,
  required int cantidad,
  required double precioCompra,
  required double? precioVenta,
  required String propietario,
  String? fotoBase64,
  required String categoria,
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
  var _guardando = false;
  List<String> _categorias = const [];
  String _categoria = '';
  var _leyendoFoto = false;
  var _generando = false;
  String? _fotoBase64;
  String? _mensajeError;

  @override
  void initState() {
    super.initState();
    _leerCategorias();
  }

  Future<void> _leerCategorias() async {
    final negocio = await NegocioStore().leer();
    if (!mounted) return;
    setState(() {
      _categorias = [
        for (final nombre in negocio?.categorias ?? const <String>[])
          if (nombre.trim().isNotEmpty) nombre.trim(),
      ];
    });
  }

  Future<void> _nuevaCategoria() async {
    final campo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: campo,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    final nombre = campo.text.trim();
    campo.dispose();
    if (ok != true || nombre.isEmpty || !mounted) return;
    String? existente;
    for (final item in _categorias) {
      if (item.toLowerCase() == nombre.toLowerCase()) existente = item;
    }
    if (existente != null) {
      setState(() => _categoria = existente!);
      return;
    }
    final lista = [..._categorias, nombre];
    try {
      await NegocioStore().guardarCatalogo(categorias: lista);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensajeError = 'No se pudo crear la categoría.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _categorias = lista;
      _categoria = nombre;
      _mensajeError = null;
    });
  }

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

  Future<void> _generarFoto() async {
    if (_guardando || _leyendoFoto || _generando) return;
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() {
        _mensajeError = 'Escribí el nombre del producto para generar la imagen.';
      });
      return;
    }
    setState(() {
      _generando = true;
      _mensajeError = null;
    });
    try {
      final texto = await _fotoGenerada(nombre: nombre);
      if (!mounted) return;
      final rechazo = motivoRechazoFoto(texto);
      if (rechazo != null) {
        setState(() => _mensajeError = rechazo);
        return;
      }
      setState(() => _fotoBase64 = texto);
    } on ChatIaException catch (error) {
      if (!mounted) return;
      setState(() => _mensajeError = error.mensaje);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensajeError = 'No se pudo generar la imagen.');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _elegirFoto() async {
    if (_guardando || _leyendoFoto || _generando) return;
    final origen = await preguntarOrigenFoto(context);
    if (origen == null || !mounted) return;
    setState(() {
      _leyendoFoto = true;
      _mensajeError = null;
    });
    try {
      final archivos = await elegirFotos(
        origen: origen,
        variasEnGaleria: false,
      );
      if (archivos.isEmpty || !mounted) return;
      final texto = base64Encode(await archivos.first.readAsBytes());
      final rechazo = motivoRechazoFoto(texto);
      if (!mounted) return;
      if (rechazo != null) {
        setState(() => _mensajeError = rechazo);
        return;
      }
      setState(() => _fotoBase64 = texto);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensajeError = 'No pude abrir la cámara o la galería.');
    } finally {
      if (mounted) setState(() => _leyendoFoto = false);
    }
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
        propietario: StockRepository.propietarioYo,
        fotoBase64: _fotoBase64,
        categoria: _categoria,
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
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Categoría',
                style: TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final nombre in _categorias)
                    ChoiceChip(
                      label: Text(nombre),
                      selected: _categoria.toLowerCase() == nombre.toLowerCase(),
                      onSelected: _guardando
                          ? null
                          : (activa) => setState(
                                () => _categoria = activa ? nombre : '',
                              ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Nueva'),
                    onPressed: _guardando ? null : _nuevaCategoria,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: (_guardando || _leyendoFoto || _generando)
                    ? null
                    : _elegirFoto,
                icon: Icon(
                  _leyendoFoto
                      ? Icons.hourglass_top
                      : Icons.add_a_photo_outlined,
                ),
                label: Text(
                  _leyendoFoto
                      ? 'Leyendo foto...'
                      : (_fotoBase64 == null
                          ? 'Foto del producto'
                          : 'Cambiar foto'),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: (_guardando || _leyendoFoto || _generando)
                    ? null
                    : _generarFoto,
                icon: Icon(
                  _generando
                      ? Icons.hourglass_top
                      : Icons.auto_awesome_outlined,
                ),
                label: Text(
                  _generando
                      ? 'Generando...'
                      : 'Generar según el nombre',
                ),
              ),
            ),
            if (_fotoBase64 != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(_fotoBase64!),
                  height: 96,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: (_guardando || _generando)
                      ? null
                      : () => setState(() => _fotoBase64 = null),
                  child: const Text('Quitar foto'),
                ),
              ),
            ],
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
  String _tipo = StockRepository.tipoEntrada;
  String? _errorPrecios;
  String? _errorNombre;
  String? _errorAjuste;

  String _codigoMoneda = monedaPorDefecto;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _compraCtrl;
  late final TextEditingController _ventaCtrl;
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _descripcionCtrl;

  @override
  void initState() {
    super.initState();
    _leerMoneda();
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

  Future<void> _leerMoneda() async {
    final codigo = await monedaDelNegocio();
    if (!mounted || codigo == _codigoMoneda) return;
    setState(() => _codigoMoneda = codigo);
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

  Future<void> _registrarAjusteUnico(
    StockRepository repo, {
    required int id,
    required int cantidad,
    required String descripcion,
  }) async {
    if (_tipo == StockRepository.tipoEntrada) {
      await repo.registrarAjuste(
        productoId: id,
        nombre: _producto.nombre,
        cantidad: cantidad,
        propietario: StockRepository.propietarioYo,
        tipo: StockRepository.tipoEntrada,
        descripcion: descripcion,
      );
      return;
    }
    var resto = cantidad;
    final deYo = resto > _producto.stockYo ? _producto.stockYo : resto;
    resto -= deYo;
    if (deYo > 0) {
      await repo.registrarAjuste(
        productoId: id,
        nombre: _producto.nombre,
        cantidad: deYo,
        propietario: StockRepository.propietarioYo,
        tipo: StockRepository.tipoSalida,
        descripcion: descripcion,
      );
    }
    if (resto > 0) {
      await repo.registrarAjuste(
        productoId: id,
        nombre: _producto.nombre,
        cantidad: resto,
        propietario: StockRepository.propietarioNildo,
        tipo: StockRepository.tipoSalida,
        descripcion: descripcion,
      );
    }
  }

  ProductoStock _aplicarAjusteLocal(int cantidad) {
    if (_tipo == StockRepository.tipoEntrada) {
      return _producto.copyWith(stockYo: _producto.stockYo + cantidad);
    }
    var resto = cantidad;
    final deYo = resto > _producto.stockYo ? _producto.stockYo : resto;
    resto -= deYo;
    return _producto.copyWith(
      stockYo: _producto.stockYo - deYo,
      stockNildo: _producto.stockNildo - resto,
    );
  }

  Future<void> _guardarAjuste() async {
    final cantidad = _parseEntero(_cantidadCtrl.text);
    if (cantidad == null || cantidad <= 0) {
      setState(() {
        _errorAjuste = 'La cantidad debe ser un entero mayor a cero.';
      });
      return;
    }
    if (_tipo == StockRepository.tipoSalida && cantidad > _producto.stockTotal) {
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
        await _registrarAjusteUnico(
          repo,
          id: id,
          cantidad: cantidad,
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

      final actualizado = _aplicarAjusteLocal(cantidad);
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

  Widget _datoDetalle(String titulo, String valor, {bool fuerte = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 14),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: AppColors.texto,
              fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usaBase = widget.repositorio != null;
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _producto.nombre,
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
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
                        'Margen: ${formatearMoneda(_producto.precioVenta - _producto.precioCompra, _codigoMoneda)}',
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
                    const SizedBox(height: 12),
                    _datoDetalle(
                      'Costo',
                      formatearMoneda(_producto.precioCompra, _codigoMoneda),
                    ),
                    _datoDetalle(
                      'Venta',
                      formatearMoneda(_producto.precioVenta, _codigoMoneda),
                    ),
                    _datoDetalle('Stock', '${_producto.stockTotal}', fuerte: true),
                  ],
                ),
              ),
            ),
            if (_producto.id != null) ...[
              const SizedBox(height: 16),
              FichaProductoPanel(
                productoId: _producto.id!,
                nombre: _nombreCtrl.text.trim().isEmpty
                    ? _producto.nombre
                    : _nombreCtrl.text.trim(),
              ),
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
                      for (final movimiento in _movimientos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                movimiento.tipo == StockRepository.tipoSalida
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded,
                                size: 18,
                                color: movimiento.tipo == StockRepository.tipoSalida
                                    ? AppColors.alerta
                                    : AppColors.lima,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_etiquetaTipo(movimiento.tipo)} · ${movimiento.propietario}',
                                      style: const TextStyle(
                                        color: AppColors.texto,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      [
                                        _fecha(movimiento.fechaCarga),
                                        if (movimiento.descripcion != null &&
                                            movimiento.descripcion!.isNotEmpty)
                                          movimiento.descripcion!,
                                      ].join(' · '),
                                      style: const TextStyle(
                                        color: AppColors.textoSuave,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${movimiento.cantidad}',
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
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

Future<String> _fotoGenerada({
  required String nombre,
  String descripcion = '',
}) async {
  final jpeg = await FotoCatalogoAsistente().generar(
    nombre: nombre,
    descripcion: descripcion,
  );
  return base64Encode(jpeg);
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

String _textoPrecio(double valor) {
  if (!valor.isFinite) return '';
  final entero = valor == valor.roundToDouble();
  final fijo = valor.abs().toStringAsFixed(entero ? 0 : 2);
  final punto = fijo.indexOf('.');
  final entera = punto < 0 ? fijo : fijo.substring(0, punto);
  final decimales = punto < 0 ? '' : fijo.substring(punto + 1);
  final miles = StringBuffer();
  for (var i = 0; i < entera.length; i++) {
    if (i > 0 && (entera.length - i) % 3 == 0) miles.write('.');
    miles.write(entera[i]);
  }
  final cuerpo = decimales.isEmpty ? miles.toString() : '${miles.toString()},$decimales';
  return valor < 0 ? '-$cuerpo' : cuerpo;
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

double? _parseDecimal(String texto) => leerMontoEscrito(texto);
