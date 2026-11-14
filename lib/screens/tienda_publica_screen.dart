import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/apariencia_tienda.dart';
import '../data/diseno_tienda.dart';
import '../data/paises_latam.dart';
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
import '../utils/moneda.dart';
import '../widgets/cuenta_pedido_tienda.dart';
import '../widgets/fondo_gexi.dart';
import '../widgets/vidriera/catalogo_vidriera.dart';
import '../widgets/vidriera/controles_vidriera.dart';
import '../widgets/vidriera/modelo_vidriera.dart';

/// Vidriera pública de un negocio.
///
/// Si hay base y el slug es el del negocio local, el pedido se guarda y
/// después se abre WhatsApp con el código. Si no hay base, solo se abre
/// WhatsApp, sin inventar un código.
///
/// Antes del nombre y el WhatsApp, el cliente elige crear cuenta, ingresar
/// o pedir sin cuenta.
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
  final _busqueda = TextEditingController();
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
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TiendaPublicaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug ||
        oldWidget.database != widget.database) {
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
      _busqueda.clear();
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
          id: remoto.id,
          nombre: remoto.nombre,
          mensaje: remoto.mensajePublico,
          whatsapp: remoto.whatsapp,
          moneda: remoto.moneda,
          apariencia: remoto.apariencia,
          logoUrl: remoto.logoUrl,
          aliasCobro: remoto.aliasCobro,
          facebookUrl: remoto.facebookUrl,
          instagramUrl: remoto.instagramUrl,
          mapsUrl: remoto.mapsUrl,
          latitud: remoto.latitud,
          longitud: remoto.longitud,
          horario: remoto.horario,
          rubros: _textosPublicos(remoto, 'rubros'),
          diseno: remoto.diseno,
          tipo: _textoPublico(remoto, 'tipoTienda').isEmpty
              ? _textoPublico(remoto, 'tipo')
              : _textoPublico(remoto, 'tipoTienda'),
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
      final fotosRemotas = await const TiendaPublicaRemota().fotosDe(remoto.id);
      final variantesRemotas =
          await const TiendaPublicaRemota().variantesDe(remoto.id);
      productos = [
        for (final producto in publicados)
          if (producto.stock > 0 && producto.precioVenta > 0)
            _ProductoPublico(
              clave: 'remoto:${producto.id}',
              remotoId: producto.id,
              nombre: producto.nombre,
              precioVenta: producto.precioVenta,
              stock: producto.stock,
              descripcion: producto.descripcion,
              categorias: producto.categorias,
              categoria: producto.categorias.join(' · '),
              variantes: [
                for (final variante in variantesRemotas)
                  if (variante.productoId == producto.id &&
                      variante.nombre.trim().isNotEmpty)
                    _VariantePublica(
                      id: variante.id,
                      etiqueta: variante.nombre.trim(),
                      stock: _stockVariante(variante.stock, producto.stock),
                      precio: variante.precioVenta,
                    ),
              ],
              galeria: [
                for (final url in producto.fotos) _FotoGaleria(url: url),
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
              final porCategoria = a.categoria
                  .toLowerCase()
                  .compareTo(b.categoria.toLowerCase());
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
    final busqueda = _busqueda.text.trim().toLowerCase();
    return [
      for (final producto in _productos)
        if ((filtro.isEmpty ||
                producto.categorias
                    .any((nombre) => nombre.toLowerCase() == filtro)) &&
            (busqueda.isEmpty ||
                producto.nombre.toLowerCase().contains(busqueda) ||
                producto.descripcion.toLowerCase().contains(busqueda) ||
                producto.categorias
                    .any((nombre) => nombre.toLowerCase().contains(busqueda)) ||
                producto.variantes.any(
                  (variante) =>
                      variante.etiqueta.toLowerCase().contains(busqueda),
                )))
          producto,
    ];
  }

  List<_SeccionCatalogo> get _secciones {
    final productos = _visibles;
    if (productos.isEmpty) return const [];
    final categorias = _categoriasDisponibles;
    if (categorias.isEmpty) {
      return [_SeccionCatalogo('', productos)];
    }
    final filtro = _filtroCategoria.trim().toLowerCase();
    final secciones = <_SeccionCatalogo>[];
    for (final nombre in categorias) {
      if (filtro.isNotEmpty && nombre.toLowerCase() != filtro) continue;
      final grupo = [
        for (final producto in productos)
          if (producto.categorias
              .any((item) => item.toLowerCase() == nombre.toLowerCase()))
            producto,
      ]..sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );
      if (grupo.isEmpty) continue;
      secciones.add(_SeccionCatalogo(nombre, grupo));
    }
    if (filtro.isEmpty) {
      final sueltos = [
        for (final producto in productos)
          if (producto.categorias.isEmpty) producto,
      ];
      if (sueltos.isNotEmpty) {
        secciones.add(_SeccionCatalogo('Sin categoría', sueltos));
      }
    }
    if (secciones.isEmpty) {
      return [_SeccionCatalogo('', productos)];
    }
    return secciones;
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
        moneda: guardado.moneda,
        pais: guardado.pais,
        apariencia: guardado.apariencia,
        logoUrl: guardado.logoUrl,
        aliasCobro: guardado.aliasCobro,
        facebookUrl: guardado.facebookUrl,
        instagramUrl: guardado.instagramUrl,
        mapsUrl: guardado.mapsUrl,
        latitud: guardado.latitud,
        longitud: guardado.longitud,
        horario: guardado.horario,
        rubros: _rubrosLocales(guardado),
        diseno: guardado.diseno,
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
    final siguiente = (_cantidadDe(producto) + cambio).clamp(0, producto.stock);
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
              varianteId: variante.id,
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
      await _pedirEnLaNube(negocio, lineas);
      return;
    }

    final datos = await _datosParaElPedido(negocio);
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
              precioVenta: linea.variante.isEmpty ? null : linea.precioUnitario,
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
          moneda: negocio.moneda,
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

  /// Primero la cuenta y, si el cliente sigue, el nombre y el WhatsApp.
  Future<_DatosCompradorPublico?> _datosParaElPedido(
    _NegocioPublicado negocio,
  ) async {
    final cuenta = await showDialog<SesionCuentaPedido>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DialogoCuentaPedido(),
    );
    if (cuenta == null || !mounted) return null;

    final datos = await showDialog<_DatosCompradorPublico>(
      context: context,
      builder: (context) => _DatosCompradorDialog(
        pais: paisPorCodigo(negocio.pais),
        aliasCobro: negocio.aliasCobro,
        nombreInicial: cuenta.nombre,
        aviso: cuenta.aviso,
      ),
    );
    if (datos == null || !mounted) return null;
    if (cuenta.conCuenta) {
      try {
        await recordarNombreDePedido(
          correo: cuenta.correo,
          nombre: datos.nombre,
        );
      } catch (_) {}
    }
    return datos;
  }

  Future<void> _pedirEnLaNube(
    _NegocioPublicado negocio,
    List<_LineaPublica> lineas,
  ) async {
    final datos = await _datosParaElPedido(negocio);
    if (datos == null || !mounted) return;
    setState(() => _abriendoWhatsApp = true);
    try {
      final pedidas = [
        for (final linea in lineas)
          if ((linea.producto.remotoId ?? '').isNotEmpty)
            {
              'producto_id': linea.producto.remotoId,
              'cantidad': linea.cantidad,
              if (linea.varianteId.trim().isNotEmpty)
                'variante_id': linea.varianteId.trim(),
            },
      ];
      if (pedidas.length != lineas.length) {
        throw StateError(
            'Hay un producto que no se puede pedir desde la página.');
      }
      final pedidoId = await const TiendaPublicaRemota().crearPedido(
        slug: _slug,
        nombre: datos.nombre,
        telefono: datos.telefono ?? '',
        lineas: pedidas,
      );
      final avisoComprobante = await _subirComprobante(
        negocioId: negocio.id,
        pedidoId: pedidoId,
        comprobante: datos.comprobante,
      );
      final corto = pedidoId.length <= 8 ? pedidoId : pedidoId.substring(0, 8);
      final abierto = await _abrirEnlace(
        Uri(
          scheme: 'https',
          host: 'wa.me',
          path: '/${negocio.whatsapp.replaceAll(RegExp(r'\D'), '')}',
          queryParameters: {
            'text': _mensajeWhatsApp(
              negocio,
              lineas,
              referencia: corto,
            ),
          },
        ),
      );
      if (!mounted) return;
      setState(() {
        _cantidades.clear();
        _abriendoWhatsApp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            avisoComprobante ??
                (abierto
                    ? 'El pedido quedó registrado. También se abrió WhatsApp.'
                    : 'El pedido quedó registrado. Abrí la app para verlo en Pedidos por la página web.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _abriendoWhatsApp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mensajePublico(error))),
      );
    }
  }

  Future<String?> _subirComprobante({
    required String negocioId,
    required String pedidoId,
    required String? comprobante,
  }) async {
    final texto = comprobante?.trim() ?? '';
    if (texto.isEmpty || negocioId.trim().isEmpty) return null;
    try {
      await const TiendaPublicaRemota().subirComprobante(
        negocioId: negocioId,
        pedidoId: pedidoId,
        bytes: base64Decode(texto),
      );
      return null;
    } catch (_) {
      return 'El pedido quedó registrado, pero el comprobante no se pudo adjuntar.';
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
        for (final item
            in doc.fichas[id]?.variantes ?? const <VarianteLocal>[]) {
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

  Future<bool> _abrirEnlace(Uri enlace) => _abrirEnlacePublico(enlace);

  String _mensajeWhatsApp(
    _NegocioPublicado negocio,
    List<_LineaPublica> lineas, {
    String referencia = '',
  }) {
    final buffer = StringBuffer()
      ..writeln('Hola, quiero hacer un pedido en ${negocio.nombre}.')
      ..writeln('Tienda: $_slug');
    if (referencia.isNotEmpty) {
      buffer.writeln('Pedido: $referencia');
    }
    buffer.writeln();
    for (final linea in lineas) {
      buffer.writeln(
        '${linea.nombreVisible} x ${linea.cantidad} — '
        '${monedaTienda(linea.precioUnitario, negocio.moneda)} c/u — '
        '${monedaTienda(linea.subtotal, negocio.moneda)}',
      );
    }
    buffer
      ..writeln()
      ..write(
        'Total: ${monedaTienda(lineas.fold<double>(0, (total, linea) => total + linea.subtotal), negocio.moneda)}',
      );
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando || _negocio == null) {
      return Scaffold(
        backgroundColor: AppColors.fondoClaro,
        body: FondoGexi(
          child: SafeArea(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primario),
                  )
                : const _PaginaNoDisponible(),
          ),
        ),
      );
    }
    final negocio = _negocio!;
    final presentacion = presentacionDeTienda(
      apariencia: negocio.apariencia,
      rubros: negocio.rubros,
      tipoTienda: negocio.tipo,
      diseno: negocio.diseno,
    );
    final cromo = cromoDePresentacion(presentacion);
    final cuerpo = SafeArea(child: _tienda(negocio, presentacion, cromo));
    if (presentacion.fondoGexi) {
      return Scaffold(
        backgroundColor: AppColors.fondoClaro,
        body: FondoGexi(child: cuerpo),
      );
    }
    return Scaffold(
      backgroundColor: cromo.fondo,
      body: ColoredBox(color: cromo.fondo, child: cuerpo),
    );
  }

  Widget _buscador(CromoVidriera cromo) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cromo.linea),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: TextField(
        controller: _busqueda,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        style: TextStyle(color: cromo.texto),
        cursorColor: cromo.acento,
        decoration: InputDecoration(
          hintText: 'Buscar producto',
          hintStyle: TextStyle(color: cromo.textoSuave),
          prefixIcon: Icon(Icons.search_rounded, color: cromo.acento),
          filled: true,
          fillColor: cromo.tarjeta,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: borde,
          enabledBorder: borde,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: cromo.acento, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _filtrosCategoria(CromoVidriera cromo) {
    final categorias = _categoriasDisponibles;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: categorias.length + 1,
        separatorBuilder: (context, indice) => const SizedBox(width: 8),
        itemBuilder: (context, indice) {
          final nombre = indice == 0 ? '' : categorias[indice - 1];
          final elegido = nombre.isEmpty
              ? _filtroCategoria.isEmpty
              : _filtroCategoria.toLowerCase() == nombre.toLowerCase();
          return FilterChip(
            label: Text(nombre.isEmpty ? 'Todas' : nombre),
            selected: elegido,
            showCheckmark: false,
            selectedColor: cromo.acento.withValues(alpha: 0.14),
            backgroundColor: cromo.tarjeta,
            side: BorderSide(
              color: elegido ? cromo.acento : cromo.linea,
            ),
            labelStyle: TextStyle(
              color: elegido ? cromo.acento : cromo.texto,
              fontWeight: FontWeight.w800,
            ),
            onSelected: (_) => setState(() {
              if (nombre.isEmpty) {
                _filtroCategoria = '';
              } else {
                _filtroCategoria = elegido ? '' : nombre;
              }
            }),
          );
        },
      ),
    );
  }

  Widget _tienda(
    _NegocioPublicado negocio,
    PresentacionVidriera presentacion,
    CromoVidriera cromo,
  ) {
    final lineas = _lineas;
    final total =
        lineas.fold<double>(0, (suma, linea) => suma + linea.subtotal);
    final secciones = [
      for (final seccion in _secciones)
        SeccionVidriera(
          seccion.titulo,
          [for (final producto in seccion.productos) _itemDe(producto)],
        ),
    ];
    final pedido = PedidoItemVidriera(
      cantidadDe: (item) {
        final producto = _productoDe(item.clave);
        return producto == null ? 0 : _cantidadDe(producto);
      },
      cantidadVariante: (item, etiqueta) {
        final producto = _productoDe(item.clave);
        return producto == null ? 0 : _cantidadVariante(producto, etiqueta);
      },
      onCambiar: (item, delta) {
        final producto = _productoDe(item.clave);
        if (producto != null) _cambiarCantidad(producto, delta);
      },
      onVariante: (item, etiqueta, delta) {
        final producto = _productoDe(item.clave);
        if (producto != null) _cambiarVariante(producto, etiqueta, delta);
      },
    );
    final anchoMaximo = presentacion.plantillaId == 'perfumes' ? 820.0 : 980.0;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final lateral = constraints.maxWidth > anchoMaximo
                  ? (constraints.maxWidth - anchoMaximo) / 2
                  : 0.0;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: lateral),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Encabezado(
                        negocio: negocio,
                        apariencia: negocio.apariencia,
                        presentacion: presentacion,
                        cromo: cromo,
                      ),
                    ),
                    if (presentacion.mostrarBanner)
                      SliverToBoxAdapter(
                        child: BannerVidriera(
                          presentacion: presentacion,
                          cromo: cromo,
                        ),
                      ),
                    if (presentacion.mostrarBuscador)
                      SliverToBoxAdapter(child: _buscador(cromo)),
                    if (presentacion.mostrarFiltros &&
                        _categoriasDisponibles.isNotEmpty)
                      SliverToBoxAdapter(child: _filtrosCategoria(cromo)),
                    if (_productos.isEmpty)
                      SliverToBoxAdapter(
                        child: _EstadoCatalogo(
                          mensaje: _mensajeCatalogo ??
                              'Todavía no hay productos disponibles.',
                          cromo: cromo,
                        ),
                      )
                    else if (secciones.isEmpty)
                      SliverToBoxAdapter(
                        child: _EstadoCatalogo(
                          mensaje: _busqueda.text.trim().isEmpty
                              ? 'No hay productos en esta categoría.'
                              : 'No hay productos con esa búsqueda.',
                          cromo: cromo,
                        ),
                      )
                    else
                      ...sliversVidriera(
                        secciones: secciones,
                        presentacion: presentacion,
                        cromo: cromo,
                        moneda: negocio.moneda,
                        pedido: pedido,
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                ),
              );
            },
          ),
        ),
        if (_productos.isNotEmpty)
          _BarraPedido(
            moneda: negocio.moneda,
            total: total,
            unidades:
                lineas.fold<int>(0, (suma, linea) => suma + linea.cantidad),
            abriendo: _abriendoWhatsApp,
            aceptaDatos: _aceptaDatos,
            onAceptar: (valor) => setState(() => _aceptaDatos = valor),
            onPressed: lineas.isEmpty ? null : _pedirPorWhatsApp,
            apariencia: negocio.apariencia,
            cromo: cromo,
          ),
      ],
    );
  }

  _ProductoPublico? _productoDe(String clave) {
    for (final producto in _productos) {
      if (producto.clave == clave) return producto;
    }
    return null;
  }

  ItemVidriera _itemDe(_ProductoPublico producto) {
    return ItemVidriera(
      clave: producto.clave,
      nombre: producto.nombre,
      descripcion: producto.descripcion,
      precio: producto.precioVenta,
      stock: producto.stock,
      categorias: producto.categorias,
      fotos: [
        for (final foto in producto.galeria)
          FotoItemVidriera(
            bytes: foto.bytes,
            url: foto.url,
            variante: foto.variante,
          ),
      ],
      variantes: [
        for (final variante in producto.variantes)
          VarianteItemVidriera(
            etiqueta: variante.etiqueta,
            stock: variante.stock,
            precio: variante.precio,
          ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.negocio,
    required this.apariencia,
    required this.presentacion,
    required this.cromo,
  });

  final _NegocioPublicado negocio;
  final AparienciaTienda apariencia;
  final PresentacionVidriera presentacion;
  final CromoVidriera cromo;

  @override
  Widget build(BuildContext context) {
    final horario = negocio.horario.trim();
    final perfumes = presentacion.plantillaId == 'perfumes';
    final nombre = perfumes ? negocio.nombre.toUpperCase() : negocio.nombre;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
          child: Column(
            children: [
              _LogoNegocio(
                nombre: negocio.nombre,
                url: negocio.logoUrl,
                color: cromo.acento,
                radio: apariencia.radio,
              ),
              const SizedBox(height: 16),
              Text(
                nombre,
                textAlign: TextAlign.center,
                style: _estiloNombre(presentacion.plantillaId, cromo),
              ),
              if (negocio.mensaje.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  negocio.mensaje,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cromo.textoSuave,
                    fontSize: 16,
                    height: 1.45,
                    fontStyle: perfumes ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
              if (presentacion.mostrarHorario && horario.isNotEmpty) ...[
                const SizedBox(height: 14),
                _HorarioPublico(
                  texto: horario,
                  cromo: cromo,
                ),
              ],
              _acciones(context),
              const SizedBox(height: 22),
              Text(
                apariencia.frasePortada,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cromo.acento,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: perfumes ? 1.4 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _acciones(BuildContext context) {
    final numero = negocio.whatsapp.replaceAll(RegExp(r'\D'), '');
    final secundarios = <Widget>[
      if (presentacion.mostrarRedes && negocio.facebookUrl.trim().isNotEmpty)
        _BotonEnlace(
          icono: FontAwesomeIcons.facebook,
          etiqueta: 'Facebook',
          cromo: cromo,
          onPressed: () => _abrirDatoPublico(context, negocio.facebookUrl),
        ),
      if (presentacion.mostrarRedes && negocio.instagramUrl.trim().isNotEmpty)
        _BotonEnlace(
          icono: FontAwesomeIcons.instagram,
          etiqueta: 'Instagram',
          cromo: cromo,
          onPressed: () => _abrirDatoPublico(context, negocio.instagramUrl),
        ),
      if (presentacion.mostrarRedes && negocio.mapsUrl.trim().isNotEmpty)
        _BotonEnlace(
          icono: FontAwesomeIcons.locationDot,
          etiqueta: 'Cómo llegar',
          cromo: cromo,
          onPressed: () => _abrirDatoPublico(
            context,
            negocio.mapsUrl,
            maps: true,
            lat: negocio.latitud,
            lng: negocio.longitud,
          ),
        ),
    ];
    final muestraWhatsapp = presentacion.mostrarWhatsapp && numero.isNotEmpty;
    if (!muestraWhatsapp && secundarios.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          if (muestraWhatsapp)
            _BotonEnlace(
              icono: FontAwesomeIcons.whatsapp,
              etiqueta: 'WhatsApp',
              cromo: cromo,
              relleno: true,
              onPressed: () => _abrirDatoPublico(
                context,
                Uri(
                  scheme: 'https',
                  host: 'wa.me',
                  path: '/$numero',
                  queryParameters: {
                    'text':
                        'Hola, te escribo desde la tienda de ${negocio.nombre}.',
                  },
                ).toString(),
              ),
            ),
          if (secundarios.isNotEmpty) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final enColumna =
                    secundarios.length == 1 || constraints.maxWidth < 520;
                if (enColumna) {
                  return Column(
                    children: [
                      for (var i = 0; i < secundarios.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        secundarios[i],
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < secundarios.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: secundarios[i]),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle _estiloNombre(String plantilla, CromoVidriera cromo) {
  final base = TextStyle(color: cromo.texto, height: 1.08);
  switch (plantilla) {
    case 'perfumes':
      return base.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w300,
        letterSpacing: 4,
      );
    case 'ropa':
      return base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
      );
    case 'cosmeticos':
      return base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
      );
    case 'tecnologia':
      return base.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );
    case 'menu':
      return base.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
      );
    case 'servicios':
      return base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      );
    default:
      return base.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
      );
  }
}

class _BotonEnlace extends StatelessWidget {
  const _BotonEnlace({
    required this.icono,
    required this.etiqueta,
    required this.cromo,
    required this.onPressed,
    this.relleno = false,
  });

  final IconData icono;
  final String etiqueta;
  final CromoVidriera cromo;
  final VoidCallback onPressed;
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cromo.radio),
    );
    const texto = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);
    if (relleno) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: FaIcon(icono, size: 18),
        label: Text(etiqueta),
        style: FilledButton.styleFrom(
          backgroundColor: cromo.acento,
          foregroundColor: cromo.sobreAcento,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: forma,
          textStyle: texto,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: FaIcon(icono, size: 18),
      label: Text(etiqueta),
      style: OutlinedButton.styleFrom(
        foregroundColor: cromo.acento,
        backgroundColor: cromo.tarjeta,
        side: BorderSide(color: cromo.acento.withValues(alpha: 0.4)),
        minimumSize: const Size(double.infinity, 52),
        shape: forma,
        textStyle: texto,
      ),
    );
  }
}

class _HorarioPublico extends StatelessWidget {
  const _HorarioPublico({
    required this.texto,
    required this.cromo,
  });

  final String texto;
  final CromoVidriera cromo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cromo.tarjeta,
        borderRadius: BorderRadius.circular(cromo.radio),
        border: Border.all(color: cromo.acento.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: cromo.acento, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: cromo.texto,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _BarraPedido extends StatelessWidget {
  const _BarraPedido({
    required this.moneda,
    required this.total,
    required this.unidades,
    required this.abriendo,
    required this.aceptaDatos,
    required this.onAceptar,
    required this.onPressed,
    required this.apariencia,
    required this.cromo,
  });

  final String moneda;
  final double total;
  final int unidades;
  final bool abriendo;
  final bool aceptaDatos;
  final ValueChanged<bool> onAceptar;
  final VoidCallback? onPressed;
  final AparienciaTienda apariencia;
  final CromoVidriera cromo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cromo.tarjeta,
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
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return cromo.acento;
                      }
                      return null;
                    }),
                    onChanged: (valor) => onAceptar(valor ?? false),
                    title: Text(
                      'Acepto que mis datos se usen solo para gestionar este pedido.',
                      style: TextStyle(color: cromo.texto, fontSize: 13),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final angosto = constraints.maxWidth < 560;
                      final resumen = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            unidades == 1
                                ? '1 unidad'
                                : '$unidades unidades',
                            style: TextStyle(
                              color: cromo.textoSuave,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            monedaTienda(total, moneda),
                            style: TextStyle(
                              color: cromo.texto,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      );
                      final boton = ElevatedButton.icon(
                        onPressed: abriendo ? null : onPressed,
                        icon: abriendo
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cromo.sobreAcento,
                                ),
                              )
                            : const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 18,
                              ),
                        label: Text(apariencia.etiquetaPedido),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cromo.acento,
                          foregroundColor: cromo.sobreAcento,
                          disabledBackgroundColor:
                              cromo.oscuro ? cromo.linea : AppColors.linea,
                          disabledForegroundColor: cromo.textoSuave,
                          elevation: 0,
                          minimumSize: Size(angosto ? double.infinity : 64, 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(apariencia.radio),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                      if (angosto) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            resumen,
                            const SizedBox(height: 12),
                            boton,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: resumen),
                          const SizedBox(width: 12),
                          boton,
                        ],
                      );
                    },
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
  const _EstadoCatalogo({required this.mensaje, required this.cromo});

  final String mensaje;
  final CromoVidriera cromo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cromo.tarjeta,
            borderRadius: BorderRadius.circular(18),
            border: cromo.oscuro ? Border.all(color: cromo.linea) : null,
            boxShadow: cromo.oscuro ? null : AppColors.sombraTarjeta,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: cromo.acento,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cromo.textoSuave,
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
    this.id = '',
    this.tipo = 'Catálogo',
    this.moneda = monedaPorDefecto,
    this.pais = '',
    this.apariencia = const AparienciaTienda(),
    this.logoUrl = '',
    this.aliasCobro = '',
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.mapsUrl = '',
    this.latitud,
    this.longitud,
    this.horario = '',
    this.rubros = const [],
    this.diseno = const DisenoTienda(),
  });

  final String id;
  final String nombre;
  final String mensaje;
  final String whatsapp;
  final String tipo;
  final String moneda;
  final String pais;
  final AparienciaTienda apariencia;
  final String logoUrl;
  final String aliasCobro;
  final String facebookUrl;
  final String instagramUrl;
  final String mapsUrl;
  final double? latitud;
  final double? longitud;
  final String horario;
  final List<String> rubros;
  final DisenoTienda diseno;
}

class _SeccionCatalogo {
  const _SeccionCatalogo(this.titulo, this.productos);

  final String titulo;
  final List<_ProductoPublico> productos;
}


class _LogoNegocio extends StatelessWidget {
  const _LogoNegocio({
    required this.nombre,
    required this.url,
    required this.color,
    required this.radio,
  });

  final String nombre;
  final String url;
  final Color color;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final inicial =
        nombre.trim().isEmpty ? 'G' : nombre.trim()[0].toUpperCase();
    final marca = Container(
      width: 128,
      height: 128,
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.12),
      child: Text(
        inicial,
        style: TextStyle(
          color: color,
          fontSize: 52,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final contenido = url.trim().isEmpty
        ? marca
        : Image.network(
            url,
            width: 128,
            height: 128,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => marca,
          );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radio + 6),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 3),
        boxShadow: AppColors.sombraTarjeta,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radio),
        child: contenido,
      ),
    );
  }
}

class _VariantePublica {
  const _VariantePublica({
    required this.etiqueta,
    required this.stock,
    required this.precio,
    this.id = '',
  });

  final String id;
  final String etiqueta;
  final int stock;
  final double precio;
}

int _stockVariante(int variante, int producto) {
  final propia = variante < 0 ? 0 : variante;
  final tope = producto < 0 ? 0 : producto;
  return propia < tope ? propia : tope;
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
    this.remotoId,
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
  final String? remotoId;
  final List<_VariantePublica> variantes;
  final String descripcion;
  final List<_FotoGaleria> galeria;
}


class _LineaPublica {
  const _LineaPublica({
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    this.variante = '',
    this.varianteId = '',
  });

  final _ProductoPublico producto;
  final int cantidad;
  final double precioUnitario;
  final String variante;
  final String varianteId;

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
  const _DatosCompradorDialog({
    this.pais,
    this.aliasCobro = '',
    this.nombreInicial = '',
    this.aviso = '',
  });

  final PaisLatam? pais;
  final String aliasCobro;
  final String nombreInicial;
  final String aviso;

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
  bool _aliasCopiado = false;

  @override
  void initState() {
    super.initState();
    final inicial = widget.nombreInicial.trim();
    if (inicial.isNotEmpty) _nombre.text = inicial;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _copiarAlias() async {
    final texto = widget.aliasCobro.trim();
    if (texto.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    setState(() => _aliasCopiado = true);
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
    final telefono = telefonoConPrefijo(_telefono.text, widget.pais);
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
              if (widget.aviso.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.limaBrillo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.aviso.trim(),
                    style: const TextStyle(
                      color: AppColors.texto,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Confirmá tu nombre y tu WhatsApp. El nombre es obligatorio. El WhatsApp y el comprobante son opcionales.',
                style: TextStyle(color: AppColors.textoSuave, height: 1.35),
              ),
              if (widget.aliasCobro.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Copiá este dato para transferir y, si querés, adjuntá el comprobante.',
                  style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.limaBrillo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          widget.aliasCobro.trim(),
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _copiarAlias,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(_aliasCopiado ? 'Copiado' : 'Copiar'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombre,
                autofocus: widget.nombreInicial.trim().isEmpty,
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
                decoration: InputDecoration(
                  labelText: 'WhatsApp (opcional)',
                  prefixText:
                      widget.pais == null ? null : '${widget.pais!.prefijo} ',
                  hintText: widget.pais?.ejemplo ?? 'Tu número de WhatsApp',
                  helperText: widget.pais == null
                      ? null
                      : '${widget.pais!.nombre}: característica ${widget.pais!.prefijo}.',
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
                    errorBuilder: (context, error, stackTrace) => const Text(
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

List<String> _rubrosLocales(NegocioLocal guardado) {
  if (guardado.rubros.isNotEmpty) return guardado.rubros;
  final plantilla = guardado.plantilla.trim();
  if (plantilla.isEmpty) return const [];
  return [
    for (final parte in plantilla.split('+'))
      if (parte.trim().isNotEmpty) parte.trim(),
  ];
}

/// Lee un campo que otro módulo puede sumar después, sin romper si todavía no está.
Object? _campoPublico(Object origen, String campo) {
  final dinamico = origen as dynamic;
  switch (campo) {
    case 'rubros':
      return dinamico.rubros;
    case 'tipo':
      return dinamico.tipo;
    case 'tipoTienda':
      return dinamico.tipoTienda;
    default:
      return null;
  }
}

List<String> _textosPublicos(Object origen, String campo) {
  try {
    final valor = _campoPublico(origen, campo);
    if (valor is Iterable) {
      return [
        for (final item in valor)
          if ('$item'.trim().isNotEmpty) '$item'.trim(),
      ];
    }
  } catch (_) {
    return const [];
  }
  return const [];
}

String _textoPublico(Object origen, String campo) {
  try {
    return _campoPublico(origen, campo)?.toString().trim() ?? '';
  } catch (_) {
    return '';
  }
}

String _mensajePublico(Object error) {
  if (error is StateError && error.message.isNotEmpty) return error.message;
  if (error is ArgumentError) {
    final mensaje = error.message;
    if (mensaje is String && mensaje.isNotEmpty) return mensaje;
  }
  final texto = error.toString();
  const avisos = [
    'Ingresá tu nombre.',
    'El pedido necesita al menos un producto.',
    'La tienda no está publicada.',
    'Un producto del pedido ya no está disponible.',
    'No hay stock suficiente.',
    'Hay un producto del pedido que no es válido.',
    'Esa variante ya no está disponible.',
  ];
  for (final aviso in avisos) {
    if (texto.contains(aviso)) return aviso;
  }
  return 'No se pudo guardar el pedido. Probá de nuevo.';
}

/// Solo abre http o https. Una dirección de Maps se convierte en una búsqueda.
Future<void> _abrirDatoPublico(
  BuildContext context,
  String texto, {
  bool maps = false,
  double? lat,
  double? lng,
}) async {
  final enlace = maps ? _enlaceMaps(texto, lat: lat, lng: lng) : _enlaceHttp(texto);
  if (enlace == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ese enlace no se puede abrir.')),
    );
    return;
  }
  final abierto = await _abrirEnlacePublico(enlace);
  if (!abierto && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el enlace.')),
    );
  }
}

Future<bool> _abrirEnlacePublico(Uri enlace) async {
  if (enlace.scheme != 'http' && enlace.scheme != 'https') return false;
  if (enlace.host.isEmpty) return false;
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

/// Devuelve un http(s) con host. Si falta el esquema y parece un dominio, usa https.
Uri? _enlaceHttp(String texto) {
  var limpio = texto.trim();
  if (limpio.isEmpty || limpio.startsWith('//')) return null;
  if (!limpio.contains('://')) {
    final pareceDominio = !limpio.contains(RegExp(r'\s')) &&
        RegExp(
          r'^[A-Za-z0-9.-]+\.[A-Za-z]{2,}([/?#].*)?$',
        ).hasMatch(limpio);
    if (!pareceDominio) return null;
    limpio = 'https://$limpio';
  }
  final uri = Uri.tryParse(limpio);
  if (uri == null) return null;
  final esquema = uri.scheme.toLowerCase();
  if (esquema != 'http' && esquema != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}

/// Con coordenadas abre Google Maps en ese punto. Si no hay, busca la dirección.
Uri? _enlaceMaps(String texto, {double? lat, double? lng}) {
  if (lat != null &&
      lng != null &&
      !(lat == 0 && lng == 0) &&
      lat.abs() <= 90 &&
      lng.abs() <= 180) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
    });
  }
  final directo = _enlaceHttp(texto);
  if (directo != null) return directo;
  final direccion = texto.trim();
  if (direccion.isEmpty || direccion.contains('://')) return null;
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': direccion,
  });
}
