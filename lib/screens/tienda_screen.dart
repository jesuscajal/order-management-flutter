import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/vidriera_local.dart';
import '../data/pedido_repository.dart';
import '../data/stock_repository.dart';
import '../data/tienda_catalogo.dart';
import '../data/paises_latam.dart';
import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../utils/moneda.dart';

/// Catálogo de la tienda: productos ya guardados y pedido local por WhatsApp.
///
/// [database] es opcional, igual que en el resto de las pantallas. Si es null,
/// no se inventan productos: se muestra que no hay una base conectada.
class TiendaScreen extends StatefulWidget {
  const TiendaScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  StockRepository? _repo;
  List<ProductoStock> _productos = [];
  Map<int, FichaProducto> _fichas = {};
  Map<int, DatoVidriera> _vidriera = {};
  final Map<String, int> _cantidades = {};
  String? _negocio;
  String _codigoMoneda = monedaPorDefecto;
  PaisLatam? _pais;
  bool _cargando = false;
  bool _abriendoWhatsApp = false;
  String? _error;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _vincular(widget.database, notificar: false);
  }

  @override
  void didUpdateWidget(TiendaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      _vincular(widget.database, notificar: true);
    }
  }

  void _vincular(AppDatabase? database, {required bool notificar}) {
    final token = ++_token;
    void aplicar() {
      _repo = database == null ? null : StockRepository(database);
      _productos = [];
      _fichas = {};
      _vidriera = {};
      _cantidades.clear();
      _error = null;
      _abriendoWhatsApp = false;
      _cargando = database != null;
    }

    if (notificar) {
      setState(aplicar);
    } else {
      aplicar();
    }
    _leerNegocio(token);
    if (database != null) {
      _cargar(token, anunciar: false);
    }
  }

  Future<void> _leerNegocio(int token) async {
    try {
      final guardado = await NegocioStore().leer();
      if (!mounted || token != _token) return;
      final nombre = guardado?.nombre.trim() ?? '';
      setState(() {
        _codigoMoneda = codigoMoneda(guardado?.moneda);
        _pais = paisPorCodigo(guardado?.pais);
        if (nombre.isNotEmpty) _negocio = nombre;
      });
    } catch (_) {
      // El pedido igual se puede armar: el mensaje usa «Gexi» si no hay nombre.
    }
  }

  Future<void> _cargar(int token, {required bool anunciar}) async {
    final repo = _repo;
    if (repo == null) return;
    if (anunciar && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final productos = await repo.obtenerProductos();
      final doc = await const AmpliacionLocal().cargar();
      final vidriera = await const VidrieraLocal().cargar();
      if (!mounted || token != _token) return;
      setState(() {
        _productos = productos;
        _fichas = doc.fichas;
        _vidriera = vidriera;
        _sincronizarCantidades();
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || token != _token) return;
      if (anunciar && _productos.isNotEmpty) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar la tienda: $e')),
        );
        return;
      }
      setState(() {
        _cargando = false;
        _error = 'No se pudo leer la tienda: $e';
      });
    }
  }

  Future<void> _refrescar() {
    return _cargar(_token, anunciar: true);
  }

  void _sincronizarCantidades() {
    final validas = <String, int>{};
    for (final producto in _productos) {
      final variantes = _variantesDe(producto);
      if (variantes.isNotEmpty) {
        for (final variante in variantes) {
          final clave = _claveVariante(producto, variante.etiqueta);
          final actual = _cantidades[clave] ?? 0;
          if (actual <= 0 || variante.stock <= 0) continue;
          validas[clave] = actual > variante.stock ? variante.stock : actual;
        }
        continue;
      }
      final actual = _cantidades[_clave(producto)] ?? 0;
      if (actual <= 0 || producto.stockTotal <= 0) continue;
      validas[_clave(producto)] =
          actual > producto.stockTotal ? producto.stockTotal : actual;
    }
    _cantidades
      ..clear()
      ..addAll(validas);
  }

  List<VarianteLocal> _variantesDe(ProductoStock producto) {
    final id = producto.id;
    if (id == null) return const [];
    final vistas = <String>{};
    return [
      for (final variante in _fichas[id]?.variantes ?? const <VarianteLocal>[])
        if (variante.etiqueta.isNotEmpty &&
            vistas.add(variante.etiqueta.toLowerCase()))
          variante,
    ];
  }

  List<_OpcionVariante> _opcionesDe(ProductoStock producto) {
    return [
      for (final variante in _variantesDe(producto))
        _OpcionVariante(
          etiqueta: variante.etiqueta,
          stock: variante.stock < 0 ? 0 : variante.stock,
          precio: variante.precio ?? producto.precioVenta,
          cantidad:
              _cantidades[_claveVariante(producto, variante.etiqueta)] ?? 0,
        ),
    ];
  }

  String _clave(ProductoStock producto) {
    final id = producto.id;
    if (id != null) return 'id:$id';
    return 'nombre:${producto.nombre.trim().toLowerCase()}';
  }

  String _claveVariante(ProductoStock producto, String etiqueta) =>
      '${_clave(producto)}|v:${etiqueta.toLowerCase()}';

  int _cantidadDe(ProductoStock producto) => _cantidades[_clave(producto)] ?? 0;

  void _cambiarCantidad(ProductoStock producto, int delta) {
    final tope = producto.stockTotal;
    if (tope <= 0) return;
    final siguiente = (_cantidadDe(producto) + delta).clamp(0, tope);
    setState(() {
      final clave = _clave(producto);
      if (siguiente == 0) {
        _cantidades.remove(clave);
      } else {
        _cantidades[clave] = siguiente;
      }
    });
  }

  void _cambiarVariante(ProductoStock producto, String etiqueta, int delta) {
    VarianteLocal? variante;
    for (final item in _variantesDe(producto)) {
      if (item.etiqueta.toLowerCase() == etiqueta.toLowerCase()) {
        variante = item;
        break;
      }
    }
    if (variante == null || (variante.stock <= 0 && delta > 0)) return;
    final tope = variante.stock < 0 ? 0 : variante.stock;
    final clave = _claveVariante(producto, variante.etiqueta);
    final siguiente = ((_cantidades[clave] ?? 0) + delta).clamp(0, tope);
    setState(() {
      if (siguiente == 0) {
        _cantidades.remove(clave);
      } else {
        _cantidades[clave] = siguiente;
      }
    });
  }

  List<LineaPedidoTienda> _lineas() {
    final lineas = <LineaPedidoTienda>[];
    for (final producto in _productos) {
      final productoId = producto.id;
      if (productoId == null) continue;
      final variantes = _variantesDe(producto);
      if (variantes.isNotEmpty) {
        for (final variante in variantes) {
          final cantidad =
              _cantidades[_claveVariante(producto, variante.etiqueta)] ?? 0;
          if (cantidad <= 0) continue;
          lineas.add(
            LineaPedidoTienda(
              productoId: productoId,
              nombre: '${producto.nombre} · ${variante.etiqueta}',
              cantidad: cantidad,
              precioUnitario: variante.precio ?? producto.precioVenta,
              variante: variante.etiqueta,
            ),
          );
        }
        continue;
      }
      final cantidad = _cantidadDe(producto);
      if (cantidad <= 0) continue;
      lineas.add(
        LineaPedidoTienda(
          productoId: productoId,
          nombre: producto.nombre,
          cantidad: cantidad,
          precioUnitario: producto.precioVenta,
        ),
      );
    }
    return lineas;
  }

  Future<void> _pedirPorWhatsApp() async {
    final lineas = _lineas();
    if (lineas.isEmpty || _abriendoWhatsApp) return;

    final database = widget.database;
    final stockRepository = _repo;
    if (database == null) {
      setState(() => _abriendoWhatsApp = true);
      final abierto = await _abrirWhatsApp(
        enlaceCarritoWhatsApp(
          negocio: _negocio ?? 'Gexi',
          lineas: lineas,
          moneda: _codigoMoneda,
        ),
      );
      if (!mounted) return;
      setState(() {
        if (abierto) _cantidades.clear();
        _abriendoWhatsApp = false;
      });
      if (!abierto) _avisar('No se pudo abrir WhatsApp.');
      return;
    }
    if (stockRepository == null) {
      _avisar('La tienda todavía se está preparando. Probá de nuevo.');
      return;
    }

    final comprador = await showDialog<_DatosComprador>(
      context: context,
      builder: (context) => _CompradorDialog(pais: _pais),
    );
    if (comprador == null || !mounted) return;

    final token = _token;
    setState(() => _abriendoWhatsApp = true);
    List<ProductoStock>? stockActualizado;
    DocumentoAmpliacion? docActual;
    try {
      stockActualizado = await stockRepository.obtenerProductos();
      docActual = await const AmpliacionLocal().cargar();
      if (!mounted || token != _token) return;

      final productosPorId = {
        for (final producto in stockActualizado)
          if (producto.id != null) producto.id!: producto,
      };
      final pedidas = <int, int>{};
      final lineasConfirmadas = <LineaPedidoTienda>[];
      for (final linea in lineas) {
        final producto = productosPorId[linea.productoId];
        if (producto == null) {
          throw StateError(
            '${linea.nombre} ya no está disponible. Actualizá la tienda y volvé a intentar.',
          );
        }
        var precio = producto.precioVenta;
        var etiqueta = '';
        if (linea.variante.isNotEmpty) {
          VarianteLocal? variante;
          for (final item
              in docActual.fichas[linea.productoId]?.variantes ??
                  const <VarianteLocal>[]) {
            if (item.etiqueta.toLowerCase() == linea.variante.toLowerCase()) {
              variante = item;
              break;
            }
          }
          if (variante == null) {
            throw StateError(
              'La variante ${linea.variante} de ${producto.nombre} ya no está.',
            );
          }
          if (linea.cantidad > variante.stock) {
            throw StateError(
              'No hay stock suficiente de ${producto.nombre} (${variante.etiqueta}). '
              'Hay ${variante.stock} y pediste ${linea.cantidad}.',
            );
          }
          precio = variante.precio ?? producto.precioVenta;
          etiqueta = variante.etiqueta;
        }
        pedidas.update(
          linea.productoId,
          (actual) => actual + linea.cantidad,
          ifAbsent: () => linea.cantidad,
        );
        lineasConfirmadas.add(
          LineaPedidoTienda(
            productoId: producto.id!,
            nombre: etiqueta.isEmpty
                ? producto.nombre
                : '${producto.nombre} · $etiqueta',
            cantidad: linea.cantidad,
            precioUnitario: precio,
            variante: etiqueta,
          ),
        );
      }
      for (final entrada in pedidas.entries) {
        final producto = productosPorId[entrada.key];
        if (producto == null) continue;
        if (entrada.value > producto.stockTotal) {
          throw StockException(
            'No hay stock suficiente de ${producto.nombre}. '
            'Hay ${producto.stockTotal} y pediste ${entrada.value}.',
          );
        }
      }

      final pedidoId = await PedidoRepository(database).crearPedido(
        clienteNombre: comprador.nombre,
        montoSenado: 0,
        lineas: [
          for (final linea in lineasConfirmadas)
            LineaPedidoBorrador(
              productoId: linea.productoId,
              cantidad: linea.cantidad,
              precioVenta:
                  linea.variante.isEmpty ? null : linea.precioUnitario,
              pisarPrecioCatalogo: false,
            ),
        ],
      );
      await const AmpliacionLocal().marcarPedido(
        pedidoId: pedidoId,
        origen: 'tienda',
        lineas: [
          for (final linea in lineasConfirmadas)
            if (linea.variante.isNotEmpty)
              LineaMeta(
                productoId: linea.productoId,
                cantidad: linea.cantidad,
                precio: linea.precioUnitario,
                variante: linea.variante,
              ),
        ],
      );
      if (!mounted || token != _token) return;

      final enlace = enlacePedidoWhatsApp(
        negocio: _negocio ?? 'Gexi',
        pedidoId: pedidoId,
        comprador: comprador.nombre,
        telefono: comprador.telefono,
        lineas: lineasConfirmadas,
        moneda: _codigoMoneda,
      );
      final abierto = await _abrirWhatsApp(enlace);
      if (!mounted || token != _token) return;
      final fichas = docActual.fichas;
      setState(() {
        _productos = stockActualizado!;
        _fichas = fichas;
        _cantidades.clear();
        _abriendoWhatsApp = false;
      });
      if (!abierto) {
        _avisar(
          'El pedido #$pedidoId quedó guardado, pero no se pudo abrir WhatsApp.',
        );
      }
    } catch (error) {
      if (!mounted || token != _token) return;
      final fichas = docActual?.fichas;
      setState(() {
        if (stockActualizado != null) {
          _productos = stockActualizado;
        }
        if (fichas != null) _fichas = fichas;
        if (stockActualizado != null || fichas != null) {
          _sincronizarCantidades();
        }
        _abriendoWhatsApp = false;
      });
      _avisar(_mensajeErrorPedido(error));
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<bool> _abrirWhatsApp(Uri enlace) async {
    try {
      if (await launchUrl(enlace, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // En web a veces no existe el modo externo. Se intenta el modo de la plataforma.
    }
    try {
      return await launchUrl(enlace, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Tienda',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (widget.database == null) {
      return _estado(
        icono: Icons.storefront_outlined,
        titulo: 'Sin catálogo',
        detalle: _negocio == null
            ? 'No hay una base conectada, así que no puedo mostrar los productos guardados.'
            : 'No hay una base conectada, así que no puedo mostrar los productos de $_negocio.',
      );
    }
    if (_cargando && _productos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primario),
      );
    }
    if (_error != null && _productos.isEmpty) {
      return _estado(
        icono: Icons.cloud_off_outlined,
        titulo: 'No pude leer los productos',
        detalle: _error!,
        accion: ElevatedButton(
          onPressed: _refrescar,
          style: _botonPrimario(),
          child: const Text('Reintentar'),
        ),
      );
    }

    final lineas = _lineas();
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primario,
            onRefresh: _refrescar,
            child: _productos.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: const [
                      _EstadoContenido(
                        icono: Icons.inventory_2_outlined,
                        titulo: 'Todavía no hay productos',
                        detalle:
                            'Cargalos en Stock y volvé a entrar. Van a aparecer acá con el precio de venta.',
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: _productos.length + 1,
                    itemBuilder: (context, indice) {
                      if (indice == 0) return _encabezado();
                      final producto = _productos[indice - 1];
                      final pieza =
                          producto.id == null ? null : _vidriera[producto.id];
                      return _TarjetaProducto(
                        producto: producto,
                        descripcion: pieza?.descripcion ?? '',
                        fotoBase64: pieza?.fotoBase64 ?? '',
                        moneda: _codigoMoneda,
                        cantidad: _cantidadDe(producto),
                        opciones: _opcionesDe(producto),
                        onMenos: () => _cambiarCantidad(producto, -1),
                        onMas: () => _cambiarCantidad(producto, 1),
                        onVariante: (etiqueta, delta) =>
                            _cambiarVariante(producto, etiqueta, delta),
                      );
                    },
                  ),
          ),
        ),
        if (_productos.isNotEmpty) _barraPedido(lineas),
      ],
    );
  }

  Widget _encabezado() {
    final negocio = _negocio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            negocio ?? 'Catálogo',
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Elegí las cantidades y mandá el pedido por WhatsApp.',
            style: TextStyle(color: AppColors.textoSuave, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _barraPedido(List<LineaPedidoTienda> lineas) {
    final total = totalPedidoTienda(lineas);
    final unidades =
        lineas.fold<int>(0, (suma, linea) => suma + linea.cantidad);
    final puedePedir = lineas.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: AppColors.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lineas.isEmpty
                      ? 'Sumá al menos un producto.'
                      : unidades == 1
                          ? '1 unidad'
                          : '$unidades unidades',
                  style: const TextStyle(color: AppColors.textoSuave),
                ),
              ),
              Text(
                monedaTienda(total, _codigoMoneda),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: puedePedir ? _pedirPorWhatsApp : null,
            icon: _abriendoWhatsApp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
            label: const Text('Pedir por WhatsApp'),
            style: _botonPrimario(),
          ),
        ],
      ),
    );
  }

  Widget _estado({
    required IconData icono,
    required String titulo,
    required String detalle,
    Widget? accion,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _EstadoContenido(
          icono: icono,
          titulo: titulo,
          detalle: detalle,
          accion: accion,
        ),
      ),
    );
  }
}

class _EstadoContenido extends StatelessWidget {
  const _EstadoContenido({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.tarjeta,
          child: Icon(icono, color: AppColors.primario, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detalle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textoSuave, height: 1.4),
        ),
        if (accion != null) ...[
          const SizedBox(height: 16),
          accion!,
        ],
      ],
    );
  }
}

class _DatosComprador {
  const _DatosComprador({required this.nombre, this.telefono});

  final String nombre;
  final String? telefono;
}

class _CompradorDialog extends StatefulWidget {
  const _CompradorDialog({this.pais});

  final PaisLatam? pais;

  @override
  State<_CompradorDialog> createState() => _CompradorDialogState();
}

class _CompradorDialogState extends State<_CompradorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  bool _acepta = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    if (!_acepta) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El comprador tiene que aceptar el uso de sus datos.'),
        ),
      );
      return;
    }
    final telefono = telefonoConPrefijo(_telefonoController.text, widget.pais);
    Navigator.pop(
      context,
      _DatosComprador(
        nombre: _nombreController.text.trim(),
        telefono: telefono.isEmpty ? null : telefono,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.fondoClaro,
      title: const Text(
        'Confirmá tu pedido',
        style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresá tus datos antes de guardar y abrir WhatsApp.',
                style: TextStyle(color: AppColors.textoSuave, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Tu nombre',
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'Ingresá tu nombre.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _confirmar(),
                decoration: InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  prefixText: widget.pais == null ? null : '${widget.pais!.prefijo} ',
                  hintText: widget.pais?.ejemplo ?? 'Tu teléfono',
                  helperText: widget.pais == null
                      ? null
                      : '${widget.pais!.nombre}: característica ${widget.pais!.prefijo}.',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _acepta,
                onChanged: (valor) => setState(() => _acepta = valor ?? false),
                title: const Text(
                  'El comprador acepta que sus datos se usen solo para este pedido.',
                  style: TextStyle(color: AppColors.texto, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textoSuave,
            shape: const StadiumBorder(),
          ),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          style: _botonPrimario(),
          child: const Text('Guardar y abrir'),
        ),
      ],
    );
  }
}

class _OpcionVariante {
  const _OpcionVariante({
    required this.etiqueta,
    required this.stock,
    required this.precio,
    required this.cantidad,
  });

  final String etiqueta;
  final int stock;
  final double precio;
  final int cantidad;
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({
    required this.producto,
    required this.cantidad,
    required this.onMenos,
    required this.onMas,
    this.descripcion = '',
    this.fotoBase64 = '',
    this.moneda = monedaPorDefecto,
    this.opciones = const [],
    this.onVariante,
  });

  final ProductoStock producto;
  final String descripcion;
  final String fotoBase64;
  final String moneda;
  final int cantidad;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final List<_OpcionVariante> opciones;
  final void Function(String etiqueta, int delta)? onVariante;

  @override
  Widget build(BuildContext context) {
    final hayStock = producto.stockTotal > 0;
    final subtotalVariantes = opciones.fold<double>(
      0,
      (suma, opcion) => suma + opcion.precio * opcion.cantidad,
    );
    final foto = bytesDeFotoVidriera(fotoBase64);
    final texto = descripcion.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppColors.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (foto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                foto,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            producto.nombre,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (texto.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              texto,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textoSuave,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (opciones.isEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Precio de venta',
                        style: TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monedaTienda(producto.precioVenta, moneda),
                        style: const TextStyle(
                          color: AppColors.primario,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hayStock ? 'Stock: ${producto.stockTotal}' : 'Sin stock',
                        style: TextStyle(
                          color: hayStock
                              ? AppColors.textoSuave
                              : AppColors.alerta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _Cantidad(
                  cantidad: cantidad,
                  puedeRestar: cantidad > 0,
                  puedeSumar: hayStock && cantidad < producto.stockTotal,
                  onMenos: onMenos,
                  onMas: onMas,
                ),
              ],
            )
          else
            for (final opcion in opciones) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opcion.etiqueta,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          monedaTienda(opcion.precio, moneda),
                          style: const TextStyle(
                            color: AppColors.primario,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          opcion.stock <= 0
                              ? 'Agotada'
                              : 'Stock: ${opcion.stock}',
                          style: TextStyle(
                            color: opcion.stock <= 0
                                ? AppColors.alerta
                                : AppColors.textoSuave,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Cantidad(
                    cantidad: opcion.cantidad,
                    puedeRestar: opcion.cantidad > 0,
                    puedeSumar:
                        opcion.stock > 0 && opcion.cantidad < opcion.stock,
                    onMenos: () => onVariante?.call(opcion.etiqueta, -1),
                    onMas: () => onVariante?.call(opcion.etiqueta, 1),
                  ),
                ],
              ),
            ],
          if (opciones.isEmpty && cantidad > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Subtotal ${monedaTienda(producto.precioVenta * cantidad, moneda)}',
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (opciones.isNotEmpty && subtotalVariantes > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Subtotal ${monedaTienda(subtotalVariantes, moneda)}',
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cantidad extends StatelessWidget {
  const _Cantidad({
    required this.cantidad,
    required this.puedeRestar,
    required this.puedeSumar,
    required this.onMenos,
    required this.onMas,
  });

  final int cantidad;
  final bool puedeRestar;
  final bool puedeSumar;
  final VoidCallback onMenos;
  final VoidCallback onMas;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Paso(icono: Icons.remove, habilitado: puedeRestar, onPressed: onMenos),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 32),
          child: Text(
            '$cantidad',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _Paso(icono: Icons.add, habilitado: puedeSumar, onPressed: onMas),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.icono,
    required this.habilitado,
    required this.onPressed,
  });

  final IconData icono;
  final bool habilitado;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: habilitado ? onPressed : null,
      icon: Icon(icono, size: 18),
      color: AppColors.primario,
      disabledColor: AppColors.textoSuave,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.limaBrillo,
        disabledBackgroundColor: AppColors.linea,
        shape: const CircleBorder(),
      ),
    );
  }
}

ButtonStyle _botonPrimario() {
  return ElevatedButton.styleFrom(
    backgroundColor: AppColors.primario,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.linea,
    disabledForegroundColor: AppColors.textoSuave,
    elevation: 0,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  );
}

String _mensajeErrorPedido(Object error) {
  if (error is StockException && error.mensaje.isNotEmpty) {
    return error.mensaje;
  }
  if (error is StateError && error.message.isNotEmpty) {
    return error.message;
  }
  if (error is ArgumentError) {
    final mensaje = error.message;
    if (mensaje is String && mensaje.isNotEmpty) return mensaje;
  }
  return 'No se pudo guardar el pedido. Probá de nuevo.';
}
