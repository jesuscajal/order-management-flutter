import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/vidriera_local.dart';
import '../data/pedido_repository.dart';
import '../data/stock_repository.dart';
import '../data/tienda_catalogo.dart';
import '../backend/tienda_publica_remota.dart';
import '../services/negocio_local.dart';
import '../services/subdominio_tienda.dart';
import '../theme/app_theme.dart';
import '../widgets/logo_gexi.dart';
import '../widgets/fondo_gexi.dart';

/// Vidriera pública de un negocio.
///
/// Si hay base y el slug es el del negocio local, el pedido se guarda y
/// después se abre WhatsApp con el código. Si no hay base, solo se abre
/// WhatsApp, sin inventar un código.
class TiendaPublicaScreen extends StatefulWidget {
  const TiendaPublicaScreen({
    super.key,
    required this.slug,
    this.database,
  });

  final String slug;
  final AppDatabase? database;

  @override
  State<TiendaPublicaScreen> createState() => _TiendaPublicaScreenState();
}

class _TiendaPublicaScreenState extends State<TiendaPublicaScreen> {
  final Map<String, int> _cantidades = {};
  _NegocioPublicado? _negocio;
  List<_ProductoPublico> _productos = const [];
  String _filtroCategoria = '';
  bool _cargando = true;
  bool _abriendoWhatsApp = false;
  bool _aceptaDatos = false;
  bool _puedePersistir = false;
  String? _mensajeCatalogo;
  int _token = 0;

  String get _slug => widget.slug.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _resolver();
  }

  @override
  void didUpdateWidget(TiendaPublicaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug || oldWidget.database != widget.database) {
      _resolver();
    }
  }

  Future<void> _resolver() async {
    final token = ++_token;
    setState(() {
      _cargando = true;
      _negocio = null;
      _productos = const [];
      _filtroCategoria = '';
      _cantidades.clear();
      _mensajeCatalogo = null;
      _abriendoWhatsApp = false;
      _puedePersistir = false;
    });

    if (_slug.isEmpty || SubdominioTienda.validarSlug(_slug) != null) {
      if (mounted && token == _token) {
        setState(() => _cargando = false);
      }
      return;
    }

    final local = await _buscarLocal();
    if (!mounted || token != _token) return;

    // Si este slug pertenece al negocio local pero su tienda está apagada, no
    // se intenta mostrar otra fuente con el mismo nombre.
    if (local.coincide && local.negocio == null) {
      setState(() => _cargando = false);
      return;
    }

    var negocio = local.negocio;
    TiendaPublica? remoto;
    if (negocio == null) {
      remoto = await const TiendaPublicaRemota().buscarPorSlug(_slug);
      if (!mounted || token != _token) return;
      if (remoto != null) {
        negocio = _NegocioPublicado(
          nombre: remoto.nombre,
          mensaje: remoto.mensajePublico,
          whatsapp: remoto.whatsapp,
        );
      }
    }
    if (negocio == null) {
      setState(() => _cargando = false);
      return;
    }

    var productos = const <_ProductoPublico>[];
    String? mensajeCatalogo;
    if (remoto != null) {
      final publicados =
          await const TiendaPublicaRemota().productosDe(remoto.id);
      final fotosRemotas =
          await const TiendaPublicaRemota().fotosDe(remoto.id);
      productos = [
        for (final producto in publicados)
          if (producto.stock > 0 && producto.precioVenta > 0)
            _ProductoPublico(
              clave: 'remoto:${producto.id}',
              nombre: producto.nombre,
              precioVenta: producto.precioVenta,
              stock: producto.stock,
              descripcion: producto.descripcion,
              categorias: producto.categorias,
              categoria: producto.categorias.join(' · '),
              galeria: [
                for (final url in producto.fotos)
                  _FotoGaleria(url: url),
                for (final foto in fotosRemotas)
                  if (foto.productoId == producto.id &&
                      foto.variante.isNotEmpty &&
                      !producto.fotos.contains(foto.url))
                    _FotoGaleria(url: foto.url, variante: foto.variante),
              ],
            ),
      ];
      if (productos.isEmpty) {
        mensajeCatalogo = 'Todavía no hay productos disponibles.';
      }
    } else {
      final database = widget.database;
      if (database == null) {
        mensajeCatalogo =
            'El catálogo no está disponible porque esta página no tiene una base conectada.';
      } else {
        try {
          final guardados = await StockRepository(database).obtenerProductos();
          final fichas = await const AmpliacionLocal().cargar();
          final vidriera = await const VidrieraLocal().cargar();
          final publicados = [
            for (final producto in guardados)
              if (producto.precioVenta > 0 &&
                  (producto.id == null ||
                      (fichas.fichas[producto.id]?.visibleEnTienda ?? true)))
                _ProductoPublico(
                  clave: producto.id == null
                      ? 'nombre:${producto.nombre.trim().toLowerCase()}'
                      : 'id:${producto.id}',
                  productoId: producto.id,
                  nombre: producto.nombre,
                  precioVenta: producto.precioVenta,
                  stock: (producto.id != null &&
                          fichas.fichas[producto.id]?.controlaStock == false)
                      ? 99
                      : producto.stockTotal,
                  categorias: producto.id == null
                      ? const []
                      : (fichas.fichas[producto.id]?.todas ?? const []),
                  categoria: producto.id == null
                      ? ''
                      : (fichas.fichas[producto.id]?.todas.join(' · ') ?? ''),
                  variantes: _variantesPublicas(producto, fichas.fichas),
                  descripcion: producto.id == null
                      ? ''
                      : (vidriera[producto.id]?.descripcion ?? ''),
                  galeria: _galeriaLocal(producto.id, vidriera),
                ),
          ]..sort((a, b) {
              final porCategoria =
                  a.categoria.toLowerCase().compareTo(b.categoria.toLowerCase());
              if (porCategoria != 0) return porCategoria;
              return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
            });
          productos = publicados;
          if (productos.isEmpty) {
            mensajeCatalogo = 'Todavía no hay productos disponibles.';
          }
        } catch (_) {
          mensajeCatalogo = 'No pudimos cargar los productos en este momento.';
        }
      }
    }

    if (!mounted || token != _token) return;
    setState(() {
      _negocio = negocio;
      _productos = productos;
      _mensajeCatalogo = mensajeCatalogo;
      _puedePersistir = remoto == null && widget.database != null;
      _cargando = false;
    });
  }

  List<_ProductoPublico> get _visibles {
    final filtro = _filtroCategoria.trim().toLowerCase();
    if (filtro.isEmpty) return _productos;
    return [
      for (final producto in _productos)
        if (producto.categorias.any((nombre) => nombre.toLowerCase() == filtro))
          producto,
    ];
  }

  List<String> get _categoriasDisponibles {
    final vistas = <String>{};
    final lista = <String>[];
    for (final producto in _productos) {
      for (final nombre in producto.categorias) {
        if (vistas.add(nombre.toLowerCase())) lista.add(nombre);
      }
    }
    lista.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return lista;
  }

  List<_FotoGaleria> _galeriaLocal(
    int? productoId,
    Map<int, DatoVidriera> vidriera,
  ) {
    if (productoId == null) return const [];
    final dato = vidriera[productoId];
    if (dato == null) return const [];
    final generales = [
      for (final foto in dato.galeria)
        if (foto.variante.trim().isEmpty) foto,
    ];
    final deVariante = [
      for (final foto in dato.galeria)
        if (foto.variante.trim().isNotEmpty) foto,
    ];
    return [
      for (final foto in [...generales, ...deVariante])
        if (bytesDeFotoVidriera(foto.base64) case final bytes?)
          _FotoGaleria(bytes: bytes, variante: foto.variante),
    ];
  }

  double _extraVidriera() {
    var extra = 0.0;
    for (final producto in _visibles) {
      var suma = 0.0;
      if (producto.galeria.isNotEmpty) suma += 100;
      final primera = producto.galeria.isEmpty ? null : producto.galeria.first;
      if (producto.galeria.length > 1 ||
          (primera?.variante.trim().isNotEmpty ?? false)) {
        suma += 18;
      }
      if (producto.descripcion.trim().isNotEmpty) suma += 56;
      if (suma > extra) extra = suma;
    }
    return extra;
  }

  List<_VariantePublica> _variantesPublicas(
    ProductoStock producto,
    Map<int, FichaProducto> fichas,
  ) {
    final id = producto.id;
    if (id == null) return const [];
    final vistas = <String>{};
    return [
      for (final variante in fichas[id]?.variantes ?? const <VarianteLocal>[])
        if (variante.etiqueta.isNotEmpty &&
            vistas.add(variante.etiqueta.toLowerCase()))
          _VariantePublica(
            etiqueta: variante.etiqueta,
            stock: variante.stock < 0 ? 0 : variante.stock,
            precio: variante.precio ?? producto.precioVenta,
          ),
    ];
  }

  Future<_ResultadoLocal> _buscarLocal() async {
    NegocioLocal? guardado;
    try {
      guardado = await NegocioStore().leer();
    } catch (_) {
      return const _ResultadoLocal();
    }
    if (guardado == null) return const _ResultadoLocal();
    if (guardado.slug.trim().toLowerCase() != _slug) {
      return const _ResultadoLocal();
    }
    if (!guardado.tiendaActiva) {
      return const _ResultadoLocal(coincide: true);
    }
    return _ResultadoLocal(
      coincide: true,
      negocio: _NegocioPublicado(
        nombre: guardado.nombre.trim(),
        mensaje: guardado.mensajePublico.trim(),
        whatsapp: guardado.whatsapp,
        tipo: guardado.tipoTienda,
      ),
    );
  }

  int _cantidadDe(_ProductoPublico producto) =>
      _cantidades[producto.clave] ?? 0;

  String _claveVariante(_ProductoPublico producto, String etiqueta) =>
      '${producto.clave}|v:${etiqueta.toLowerCase()}';

  int _cantidadVariante(_ProductoPublico producto, String etiqueta) =>
      _cantidades[_claveVariante(producto, etiqueta)] ?? 0;

  void _cambiarCantidad(_ProductoPublico producto, int cambio) {
    if (producto.variantes.isNotEmpty) return;
    final siguiente =
        (_cantidadDe(producto) + cambio).clamp(0, producto.stock);
    setState(() {
      if (siguiente == 0) {
        _cantidades.remove(producto.clave);
      } else {
        _cantidades[producto.clave] = siguiente;
      }
    });
  }

  void _cambiarVariante(
    _ProductoPublico producto,
    String etiqueta,
    int cambio,
  ) {
    _VariantePublica? variante;
    for (final item in producto.variantes) {
      if (item.etiqueta.toLowerCase() == etiqueta.toLowerCase()) {
        variante = item;
        break;
      }
    }
    if (variante == null) return;
    final tope = variante.stock < 0 ? 0 : variante.stock;
    if (tope <= 0 && cambio > 0) return;
    final clave = _claveVariante(producto, variante.etiqueta);
    final siguiente = ((_cantidades[clave] ?? 0) + cambio).clamp(0, tope);
    setState(() {
      if (siguiente == 0) {
        _cantidades.remove(clave);
      } else {
        _cantidades[clave] = siguiente;
      }
    });
  }

  List<_LineaPublica> get _lineas {
    final lineas = <_LineaPublica>[];
    for (final producto in _productos) {
      if (producto.variantes.isNotEmpty) {
        for (final variante in producto.variantes) {
          final cantidad = _cantidadVariante(producto, variante.etiqueta);
          if (cantidad <= 0) continue;
          lineas.add(
            _LineaPublica(
              producto: producto,
              cantidad: cantidad,
              variante: variante.etiqueta,
              precioUnitario: variante.precio,
            ),
          );
        }
        continue;
      }
      final cantidad = _cantidadDe(producto);
      if (cantidad <= 0) continue;
      lineas.add(
        _LineaPublica(
          producto: producto,
          cantidad: cantidad,
          precioUnitario: producto.precioVenta,
        ),
      );
    }
    return lineas;
  }

  Future<void> _pedirPorWhatsApp() async {
    final negocio = _negocio;
    final lineas = _lineas;
    if (negocio == null || lineas.isEmpty || _abriendoWhatsApp) return;
    if (!_aceptaDatos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aceptá el uso de tus datos para enviar el pedido.'),
        ),
      );
      return;
    }

    final database = widget.database;
    if (!_puedePersistir || database == null) {
      await _abrirPedidoSinGuardar(negocio, lineas);
      return;
    }

    final datos = await showDialog<_DatosCompradorPublico>(
      context: context,
      builder: (context) => const _DatosCompradorDialog(),
    );
    if (datos == null || !mounted) return;

    setState(() => _abriendoWhatsApp = true);
    try {
      final confirmadas = await _confirmarLineas(database, lineas);
      final pedidoId = await PedidoRepository(database).crearPedido(
        clienteNombre: datos.nombre,
        montoSenado: 0,
        lineas: [
          for (final linea in confirmadas)
            LineaPedidoBorrador(
              productoId: linea.producto.productoId,
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
          for (final linea in confirmadas)
            if (linea.variante.isNotEmpty && linea.producto.productoId != null)
              LineaMeta(
                productoId: linea.producto.productoId!,
                cantidad: linea.cantidad,
                precio: linea.precioUnitario,
                variante: linea.variante,
              ),
        ],
      );
      final comprobante = datos.comprobante;
      if (comprobante != null && comprobante.isNotEmpty) {
        await const AmpliacionLocal().guardarComprobante(
          pedidoId: pedidoId,
          base64: comprobante,
          estado: 'pendiente',
        );
      }
      if (!mounted) return;
      final abierto = await _abrirEnlace(
        enlacePedidoWhatsApp(
          negocio: negocio.nombre,
          pedidoId: pedidoId,
          comprador: datos.nombre,
          telefono: datos.telefono,
          lineas: [
            for (final linea in confirmadas)
              LineaPedidoTienda(
                productoId: linea.producto.productoId ?? 0,
                nombre: linea.nombreVisible,
                cantidad: linea.cantidad,
                precioUnitario: linea.precioUnitario,
                variante: linea.variante,
              ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() {
        _cantidades.clear();
        _abriendoWhatsApp = false;
      });
      if (!abierto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El pedido #$pedidoId quedó guardado, pero no se pudo abrir WhatsApp.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _abriendoWhatsApp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mensajePublico(error))),
      );
    }
  }

  Future<void> _abrirPedidoSinGuardar(
    _NegocioPublicado negocio,
    List<_LineaPublica> lineas,
  ) async {
    setState(() => _abriendoWhatsApp = true);
    final digitos = negocio.whatsapp.replaceAll(RegExp(r'\D'), '');
    final enlace = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: digitos.isEmpty ? '/' : '/$digitos',
      queryParameters: {'text': _mensajeWhatsApp(negocio, lineas)},
    );
    final abierto = await _abrirEnlace(enlace);
    if (!mounted) return;
    setState(() => _abriendoWhatsApp = false);
    if (!abierto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  Future<List<_LineaPublica>> _confirmarLineas(
    AppDatabase database,
    List<_LineaPublica> lineas,
  ) async {
    final guardados = await StockRepository(database).obtenerProductos();
    final doc = await const AmpliacionLocal().cargar();
    final porId = {
      for (final producto in guardados)
        if (producto.id != null) producto.id!: producto,
    };
    final pedidas = <int, int>{};
    final confirmadas = <_LineaPublica>[];
    for (final linea in lineas) {
      final id = linea.producto.productoId;
      if (id == null) {
        throw StateError(
          '${linea.nombreVisible} no se puede guardar en un pedido.',
        );
      }
      final producto = porId[id];
      if (producto == null) {
        throw StateError('${linea.producto.nombre} ya no está disponible.');
      }
      var precio = linea.precioUnitario;
      if (linea.variante.isNotEmpty) {
        VarianteLocal? variante;
        for (final item in doc.fichas[id]?.variantes ?? const <VarianteLocal>[]) {
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
      }
      final controla = doc.fichas[id]?.controlaStock ?? true;
      if (controla) {
        pedidas.update(
          id,
          (actual) => actual + linea.cantidad,
          ifAbsent: () => linea.cantidad,
        );
      }
      confirmadas.add(
        _LineaPublica(
          producto: linea.producto,
          cantidad: linea.cantidad,
          variante: linea.variante,
          precioUnitario: precio,
        ),
      );
    }
    for (final entrada in pedidas.entries) {
      final producto = porId[entrada.key];
      if (producto == null) continue;
      if (entrada.value > producto.stockTotal) {
        throw StateError(
          'No hay stock suficiente de ${producto.nombre}. '
          'Hay ${producto.stockTotal} y pediste ${entrada.value}.',
        );
      }
    }
    if (confirmadas.isEmpty) {
      throw StateError('El pedido necesita al menos un producto.');
    }
    return confirmadas;
  }

  Future<bool> _abrirEnlace(Uri enlace) async {
    try {
      if (await launchUrl(enlace, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Web puede no admitir el modo externo.
    }
    try {
      return await launchUrl(enlace, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  String _mensajeWhatsApp(
    _NegocioPublicado negocio,
    List<_LineaPublica> lineas,
  ) {
    final buffer = StringBuffer()
      ..writeln('Hola, quiero hacer un pedido en ${negocio.nombre}.')
      ..writeln('Tienda: $_slug')
      ..writeln();
    for (final linea in lineas) {
      buffer.writeln(
        '${linea.nombreVisible} x ${linea.cantidad} — '
        '${monedaTienda(linea.precioUnitario)} c/u — '
        '${monedaTienda(linea.subtotal)}',
      );
    }
    buffer
      ..writeln()
      ..write(
        'Total: ${monedaTienda(lineas.fold<double>(0, (total, linea) => total + linea.subtotal))}',
      );
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: FondoGexi(
        child: SafeArea(
          child: _cargando
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primario),
                )
              : _negocio == null
                  ? const _PaginaNoDisponible()
                  : _tienda(_negocio!),
        ),
      ),
    );
  }

  Widget _filtrosCategoria() {
    final categorias = _categoriasDisponibles;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Todas'),
            selected: _filtroCategoria.isEmpty,
            onSelected: (_) => setState(() => _filtroCategoria = ''),
          ),
          for (final nombre in categorias)
            FilterChip(
              label: Text(nombre),
              selected: _filtroCategoria.toLowerCase() == nombre.toLowerCase(),
              onSelected: (_) => setState(() {
                _filtroCategoria =
                    _filtroCategoria.toLowerCase() == nombre.toLowerCase()
                        ? ''
                        : nombre;
              }),
            ),
        ],
      ),
    );
  }

  Widget _tienda(_NegocioPublicado negocio) {
    final lineas = _lineas;
    final total =
        lineas.fold<double>(0, (suma, linea) => suma + linea.subtotal);
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Encabezado(negocio: negocio)),
              if (_categoriasDisponibles.isNotEmpty)
                SliverToBoxAdapter(child: _filtrosCategoria()),
              if (_productos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EstadoCatalogo(
                    mensaje: _mensajeCatalogo ??
                        'Todavía no hay productos disponibles.',
                  ),
                )
              else if (_visibles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EstadoCatalogo(
                    mensaje: 'No hay productos en esta categoría.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columnas = constraints.crossAxisExtent >= 900
                          ? 3
                          : constraints.crossAxisExtent >= 580
                              ? 2
                              : 1;
                      var filasVariante = 0;
                      for (final producto in _visibles) {
                        if (producto.variantes.length > filasVariante) {
                          filasVariante = producto.variantes.length;
                        }
                      }
                      final extra = _extraVidriera();
                      final alto = filasVariante == 0
                          ? 220.0 + extra
                          : (160.0 + filasVariante * 72).clamp(220.0, 480.0) +
                              extra;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnas,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: alto,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, indice) {
                            final producto = _visibles[indice];
                            return _TarjetaProducto(
                              producto: producto,
                              cantidad: _cantidadDe(producto),
                              onMenos: () => _cambiarCantidad(producto, -1),
                              onMas: () => _cambiarCantidad(producto, 1),
                              cantidadVariante: (etiqueta) =>
                                  _cantidadVariante(producto, etiqueta),
                              onVariante: (etiqueta, delta) =>
                                  _cambiarVariante(producto, etiqueta, delta),
                            );
                          },
                          childCount: _visibles.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_productos.isNotEmpty)
          _BarraPedido(
            total: total,
            unidades:
                lineas.fold<int>(0, (suma, linea) => suma + linea.cantidad),
            abriendo: _abriendoWhatsApp,
            aceptaDatos: _aceptaDatos,
            onAceptar: (valor) => setState(() => _aceptaDatos = valor),
            onPressed: lineas.isEmpty ? null : _pedirPorWhatsApp,
          ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.negocio});

  final _NegocioPublicado negocio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
          child: Column(
            children: [
              const LogoGexi(ancho: 148),
              const SizedBox(height: 8),
              Text(
                negocio.nombre,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 32,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              if (negocio.mensaje.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  negocio.mensaje,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                negocio.tipo == 'Menú' ? 'Elegí del menú' : 'Elegí tus productos',
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({
    required this.producto,
    required this.cantidad,
    required this.onMenos,
    required this.onMas,
    this.cantidadVariante,
    this.onVariante,
  });

  final _ProductoPublico producto;
  final int cantidad;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final int Function(String etiqueta)? cantidadVariante;
  final void Function(String etiqueta, int delta)? onVariante;

  @override
  Widget build(BuildContext context) {
    final foto = producto.galeria.isEmpty ? null : producto.galeria.first;
    final descripcion = producto.descripcion.trim();
    if (producto.variantes.isNotEmpty) {
      return _conVariantes(foto: foto, descripcion: descripcion);
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppColors.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (foto != null)
            _FotoPublica(foto: foto, pie: _pieGaleria(producto)),
          Text(
            producto.nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (descripcion.isNotEmpty) _TextoVidriera(texto: descripcion),
          const Spacer(),
          Text(
            monedaTienda(producto.precioVenta),
            style: const TextStyle(
              color: AppColors.primario,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          if (producto.categoria.isNotEmpty)
            Text(
              producto.categoria,
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
            ),
          Text(
            producto.stock <= 0 ? 'Agotado' : 'Stock: ${producto.stock}',
            style: TextStyle(
              color: producto.stock <= 0 ? AppColors.alerta : AppColors.textoSuave,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PasoCantidad(
                icono: Icons.remove,
                habilitado: cantidad > 0,
                onPressed: onMenos,
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '$cantidad',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _PasoCantidad(
                icono: Icons.add,
                habilitado: cantidad < producto.stock,
                onPressed: onMas,
              ),
              const Spacer(),
              if (cantidad > 0)
                Text(
                  monedaTienda(producto.precioVenta * cantidad),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conVariantes({
    required _FotoGaleria? foto,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppColors.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (foto != null)
            _FotoPublica(foto: foto, pie: _pieGaleria(producto)),
          Text(
            producto.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (descripcion.isNotEmpty) _TextoVidriera(texto: descripcion),
          if (producto.categoria.isNotEmpty)
            Text(
              producto.categoria,
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              primary: false,
              itemCount: producto.variantes.length,
              separatorBuilder: (context, indice) => const SizedBox(height: 8),
              itemBuilder: (context, indice) {
                final variante = producto.variantes[indice];
                final elegida = cantidadVariante?.call(variante.etiqueta) ?? 0;
                final agotada = variante.stock <= 0;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            variante.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.texto,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            monedaTienda(variante.precio),
                            style: const TextStyle(
                              color: AppColors.primario,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            agotada ? 'Agotada' : 'Stock: ${variante.stock}',
                            style: TextStyle(
                              color: agotada
                                  ? AppColors.alerta
                                  : AppColors.textoSuave,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PasoCantidad(
                      icono: Icons.remove,
                      habilitado: elegida > 0,
                      onPressed: () => onVariante?.call(variante.etiqueta, -1),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$elegida',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _PasoCantidad(
                      icono: Icons.add,
                      habilitado: !agotada && elegida < variante.stock,
                      onPressed: () => onVariante?.call(variante.etiqueta, 1),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PasoCantidad extends StatelessWidget {
  const _PasoCantidad({
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
      visualDensity: VisualDensity.compact,
      icon: Icon(icono, size: 19),
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

class _BarraPedido extends StatelessWidget {
  const _BarraPedido({
    required this.total,
    required this.unidades,
    required this.abriendo,
    required this.aceptaDatos,
    required this.onAceptar,
    required this.onPressed,
  });

  final double total;
  final int unidades;
  final bool abriendo;
  final bool aceptaDatos;
  final ValueChanged<bool> onAceptar;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: const Color(0x240F3A5A),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: aceptaDatos,
                    onChanged: (valor) => onAceptar(valor ?? false),
                    title: const Text(
                      'Acepto que mis datos se usen solo para gestionar este pedido.',
                      style: TextStyle(color: AppColors.texto, fontSize: 13),
                    ),
                  ),
                  Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          unidades == 1 ? '1 unidad' : '$unidades unidades',
                          style: const TextStyle(
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          monedaTienda(total),
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: abriendo ? null : onPressed,
                    icon: abriendo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const FaIcon(
                            FontAwesomeIcons.whatsapp,
                            size: 18,
                          ),
                    label: const Text('Pedir por WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primario,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.linea,
                      disabledForegroundColor: AppColors.textoSuave,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginaNoDisponible extends StatelessWidget {
  const _PaginaNoDisponible();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 52,
              color: AppColors.primario,
            ),
            SizedBox(height: 18),
            Text(
              'Esta página no está disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoCatalogo extends StatelessWidget {
  const _EstadoCatalogo({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: AppColors.tarjeta,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primario,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultadoLocal {
  const _ResultadoLocal({this.coincide = false, this.negocio});

  final bool coincide;
  final _NegocioPublicado? negocio;
}

class _NegocioPublicado {
  const _NegocioPublicado({
    required this.nombre,
    required this.mensaje,
    required this.whatsapp,
    this.tipo = 'Catálogo',
  });

  final String nombre;
  final String mensaje;
  final String whatsapp;
  final String tipo;
}

class _VariantePublica {
  const _VariantePublica({
    required this.etiqueta,
    required this.stock,
    required this.precio,
  });

  final String etiqueta;
  final int stock;
  final double precio;
}

class _FotoGaleria {
  const _FotoGaleria({this.bytes, this.url, this.variante = ''});

  final Uint8List? bytes;
  final String? url;
  final String variante;
}

class _ProductoPublico {
  const _ProductoPublico({
    required this.clave,
    required this.nombre,
    required this.precioVenta,
    required this.stock,
    this.categoria = '',
    this.categorias = const [],
    this.productoId,
    this.variantes = const [],
    this.descripcion = '',
    this.galeria = const [],
  });

  final String clave;
  final String nombre;
  final double precioVenta;
  final int stock;
  final String categoria;
  final List<String> categorias;
  final int? productoId;
  final List<_VariantePublica> variantes;
  final String descripcion;
  final List<_FotoGaleria> galeria;
}

String _pieGaleria(_ProductoPublico producto) {
  final vistas = <String>{};
  final lista = <String>[];
  for (final foto in producto.galeria) {
    final nombre = foto.variante.trim();
    if (nombre.isEmpty || !vistas.add(nombre.toLowerCase())) continue;
    lista.add(nombre);
  }
  if (lista.isNotEmpty) return 'Fotos: ${lista.join(', ')}';
  if (producto.galeria.length > 1) return '${producto.galeria.length} fotos';
  return '';
}

class _FotoPublica extends StatelessWidget {
  const _FotoPublica({required this.foto, required this.pie});

  final _FotoGaleria foto;
  final String pie;

  @override
  Widget build(BuildContext context) {
    final bytes = foto.bytes;
    final url = foto.url?.trim() ?? '';
    final imagen = bytes != null
        ? Image.memory(
            bytes,
            height: 84,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          )
        : url.isEmpty
            ? null
            : Image.network(
                url,
                height: 84,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              );
    if (imagen == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imagen,
          ),
          if (pie.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                pie,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _TextoVidriera extends StatelessWidget {
  const _TextoVidriera({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        texto,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textoSuave,
          fontSize: 13,
          height: 1.3,
        ),
      ),
    );
  }
}

class _LineaPublica {
  const _LineaPublica({
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    this.variante = '',
  });

  final _ProductoPublico producto;
  final int cantidad;
  final double precioUnitario;
  final String variante;

  String get nombreVisible =>
      variante.isEmpty ? producto.nombre : '${producto.nombre} · $variante';

  double get subtotal => precioUnitario * cantidad;
}

class _DatosCompradorPublico {
  const _DatosCompradorPublico({
    required this.nombre,
    this.telefono,
    this.comprobante,
  });

  final String nombre;
  final String? telefono;
  final String? comprobante;
}

class _DatosCompradorDialog extends StatefulWidget {
  const _DatosCompradorDialog();

  @override
  State<_DatosCompradorDialog> createState() => _DatosCompradorDialogState();
}

class _DatosCompradorDialogState extends State<_DatosCompradorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  String? _comprobante;
  String? _error;
  bool _leyendo = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _elegirComprobante() async {
    if (_leyendo) return;
    setState(() {
      _leyendo = true;
      _error = null;
    });
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 45,
      );
      if (archivo == null) return;
      final texto = base64Encode(await archivo.readAsBytes());
      if (!mounted) return;
      if (texto.length > topeComprobante) {
        setState(() {
          _error = 'La imagen es muy pesada. Probá con una foto más chica.';
        });
        return;
      }
      setState(() => _comprobante = texto);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pude leer la imagen.');
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    final telefono = _telefono.text.trim();
    Navigator.pop(
      context,
      _DatosCompradorPublico(
        nombre: _nombre.text.trim(),
        telefono: telefono.isEmpty ? null : telefono,
        comprobante: _comprobante,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.fondoClaro,
      title: const Text(
        'Tus datos',
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
                'El nombre es obligatorio. El teléfono y el comprobante son opcionales.',
                style: TextStyle(color: AppColors.textoSuave, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombre,
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
                controller: _telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  hintText: 'Tu teléfono',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _leyendo ? null : _elegirComprobante,
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    _comprobante == null
                        ? 'Adjuntar comprobante'
                        : 'Cambiar comprobante',
                  ),
                ),
              ),
              if (_comprobante != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(_comprobante!),
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Text(
                      'No se pudo mostrar la imagen.',
                      style: TextStyle(color: AppColors.alerta),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.alerta),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _leyendo ? null : _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primario,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: const Text('Guardar y abrir'),
        ),
      ],
    );
  }
}

String _mensajePublico(Object error) {
  if (error is StateError && error.message.isNotEmpty) return error.message;
  if (error is ArgumentError) {
    final mensaje = error.message;
    if (mensaje is String && mensaje.isNotEmpty) return mensaje;
  }
  return 'No se pudo guardar el pedido. Probá de nuevo.';
}
