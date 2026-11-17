import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart' show AppDatabase;
import '../data/cobro_local.dart';
import '../data/pedido_repository.dart';
import '../data/vidriera_local.dart';
import '../models/pedido_estado.dart';
import '../models/producto_pedido.dart';
import '../services/avisos/avisos_pedido_tienda.dart';
import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../utils/moneda.dart';

/// pendiente y pendiente de pago comparten el ámbar; pagado usa el verde
/// de completado, confirmado el azul de en curso, entregado el verde y
/// cancelado el rojo de alerta. `en proceso` se lee como confirmado.
Color colorPedidoEstado(String raw) {
  switch (PedidoEstados.leer(raw)) {
    case PedidoEstado.pendiente:
    case PedidoEstado.pendienteDePago:
      return AppColors.pendiente;
    case PedidoEstado.pagado:
      return AppColors.completado;
    case PedidoEstado.confirmado:
      return AppColors.enCurso;
    case PedidoEstado.entregado:
      return AppColors.verde;
    case PedidoEstado.cancelado:
      return AppColors.alerta;
    case null:
      return AppColors.textoSuave;
  }
}

mixin _ConMoneda<T extends StatefulWidget> on State<T> {
  String _codigoMoneda = monedaPorDefecto;

  Future<void> _leerMoneda() async {
    final codigo = await monedaDelNegocio();
    if (!mounted || codigo == _codigoMoneda) return;
    setState(() => _codigoMoneda = codigo);
  }
}

/// Sin [database] se mantiene la demo en memoria.
/// Con [database] los pedidos se leen y escriben en SQLite.
class PedidosScreen extends StatefulWidget {
  final AppDatabase? database;

  const PedidosScreen({super.key, this.database});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidoVista {
  const _PedidoVista({
    required this.id,
    required this.clienteNombre,
    required this.fecha,
    required this.estado,
    required this.montoSenado,
    required this.productos,
    required this.historial,
    this.medioPago = '',
    this.fiado = false,
    this.descuentoMonto = 0,
    this.descuentoTipo = '',
    this.descuentoValor = 0,
    this.origen = 'local',
    this.vendidoPor = '',
    this.cobradoPor = '',
  });

  final int id;
  final String clienteNombre;
  final DateTime fecha;
  final String estado;
  final double montoSenado;
  final List<ProductoPedido> productos;
  final List<_CambioVista> historial;
  final String medioPago;
  final bool fiado;
  final double descuentoMonto;
  final String descuentoTipo;
  final double descuentoValor;
  final String origen;
  final String vendidoPor;
  final String cobradoPor;

  bool get esDeLaWeb => origen.trim().toLowerCase() == 'tienda';

  double get subtotal => calcularMontoTotal([
        for (final producto in productos)
          (precioVenta: producto.precio, cantidad: producto.cantidad),
      ]);

  double get total {
    final neto = subtotal - (descuentoMonto < 0 ? 0 : descuentoMonto);
    return neto < 0 ? 0 : neto;
  }

  _PedidoVista copiar({
    String? estado,
    double? montoSenado,
    List<_CambioVista>? historial,
  }) {
    return _PedidoVista(
      id: id,
      clienteNombre: clienteNombre,
      fecha: fecha,
      estado: estado ?? this.estado,
      montoSenado: montoSenado ?? this.montoSenado,
      productos: productos,
      historial: historial ?? this.historial,
      medioPago: medioPago,
      fiado: fiado,
      descuentoMonto: descuentoMonto,
      descuentoTipo: descuentoTipo,
      descuentoValor: descuentoValor,
      origen: origen,
      vendidoPor: vendidoPor,
      cobradoPor: cobradoPor,
    );
  }
}

class _CambioVista {
  const _CambioVista({
    required this.anterior,
    required this.nuevo,
    required this.fecha,
  });

  final String anterior;
  final String nuevo;
  final DateTime fecha;
}

class _LineaUi {
  const _LineaUi({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    this.unidad = '',
    this.variante = '',
  });

  final int? productoId;
  final String nombre;
  final int cantidad;
  final double precio;
  final String unidad;
  final String variante;

  double get subtotal => precio * cantidad;

  String get titulo {
    final extras = <String>[
      if (variante.isNotEmpty) variante,
      if (unidad.isNotEmpty) unidad,
    ];
    final detalle = extras.isEmpty ? '' : ' · ${extras.join(' · ')}';
    return '$nombre$detalle x$cantidad';
  }
}

class _BorradorPedido {
  const _BorradorPedido({
    required this.clienteId,
    required this.clienteNombre,
    required this.montoSenado,
    required this.lineas,
    this.medioPago = '',
    this.fiado = false,
    this.diaCobro,
    this.descuentoTipo = '',
    this.descuentoValor = 0,
    this.descuentoMonto = 0,
  });

  final int? clienteId;
  final String clienteNombre;
  final double montoSenado;
  final List<_LineaUi> lineas;
  final String medioPago;
  final bool fiado;
  final DateTime? diaCobro;
  final String descuentoTipo;
  final double descuentoValor;
  final double descuentoMonto;
}

class _PedidosScreenState extends State<PedidosScreen> with _ConMoneda {
  PedidoRepository? _repo;
  List<_PedidoVista> _pedidos = [];
  bool _cargando = true;
  String? _error;
  String _filtro = 'todos';
  String _canal = 'manual';
  String _consulta = '';
  Map<int, String> _fotos = {};
  StreamSubscription<void>? _llegadas;

  @override
  void initState() {
    super.initState();
    _leerMoneda();
    _vincular(widget.database, notificar: false);
    _llegadas = AvisosPedidoTienda.alLlegar.listen((_) {
      if (!mounted) return;
      _cargar();
    });
  }

  @override
  void dispose() {
    _llegadas?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(PedidosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      _vincular(widget.database, notificar: true);
    }
  }

  void _vincular(AppDatabase? database, {required bool notificar}) {
    void aplicar() {
      _error = null;
      if (database == null) {
        _repo = null;
        _pedidos = _demo();
        _cargando = false;
        return;
      }
      _repo = PedidoRepository(database);
      _pedidos = [];
      _cargando = true;
    }

    if (notificar) {
      setState(aplicar);
    } else {
      aplicar();
    }
    if (database != null) _cargar();
  }

  List<_PedidoVista> _demo() {
    final ahora = DateTime.now();
    return [
      _PedidoVista(
        id: 1,
        clienteNombre: 'Kevin',
        fecha: ahora.subtract(const Duration(days: 1)),
        estado: PedidoEstado.pendienteDePago.texto,
        montoSenado: 10,
        productos: const [
          ProductoPedido(nombre: 'Powerbank', cantidad: 2, precio: 15),
          ProductoPedido(nombre: 'Cable USB', cantidad: 5, precio: 2),
        ],
        historial: const [],
      ),
      _PedidoVista(
        id: 2,
        clienteNombre: 'Nildo',
        fecha: ahora,
        estado: PedidoEstado.pagado.texto,
        montoSenado: 20,
        productos: const [
          ProductoPedido(nombre: 'Cargador rápido', cantidad: 1, precio: 20),
        ],
        historial: const [],
      ),
    ];
  }

  Future<void> _cargar() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final pedidos = await repo.listarPedidos();
      final metas = await const AmpliacionLocal().cargar();
      final vidriera = await const VidrieraLocal().cargar();
      if (!mounted) return;
      setState(() {
        _pedidos = [
          for (final pedido in pedidos)
            _vistaDe(pedido, metas.pedidos[pedido.id]),
        ];
        _fotos = {
          for (final pedido in pedidos)
            pedido.id: _fotoDe(pedido, vidriera),
        };
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

  _PedidoVista _vistaDe(PedidoResumen pedido, MetaPedido? meta) {
    final productos = _productosVisibles(pedido, meta);
    final subtotal = calcularMontoTotal([
      for (final producto in productos)
        (precioVenta: producto.precio, cantidad: producto.cantidad),
    ]);
    return _PedidoVista(
      id: pedido.id,
      clienteNombre: pedido.clienteNombre,
      fecha: pedido.fecha,
      estado: pedido.estado,
      montoSenado: pedido.montoSenado,
      productos: productos,
      historial: [
        for (final cambio in pedido.historial)
          _CambioVista(
            anterior: cambio.estadoAnterior,
            nuevo: cambio.estadoNuevo,
            fecha: cambio.fechaCambio,
          ),
      ],
      medioPago: meta?.medioPago ?? '',
      fiado: meta?.fiado ?? false,
      descuentoMonto: meta?.descuentoSobre(subtotal) ?? 0,
      descuentoTipo: meta?.descuentoTipo ?? '',
      descuentoValor: meta?.descuentoValor ?? 0,
      origen: meta?.origen ?? 'local',
      vendidoPor: meta?.autor ?? '',
      cobradoPor: meta?.cobradoPor ?? '',
    );
  }

  List<ProductoPedido> _productosVisibles(
    PedidoResumen pedido,
    MetaPedido? meta,
  ) {
    final detalladas = meta?.lineas ?? const <LineaMeta>[];
    if (detalladas.isEmpty) {
      return [
        for (final item in pedido.items)
          ProductoPedido(
            nombre: item.nombre,
            cantidad: item.cantidad,
            precio: meta?.precioDe(item.productoId) ?? item.precioVenta,
          ),
      ];
    }
    final nombres = {
      for (final item in pedido.items) item.productoId: item.nombre,
    };
    final cubiertos = <int, int>{};
    final productos = <ProductoPedido>[];
    for (final linea in detalladas) {
      cubiertos.update(
        linea.productoId,
        (actual) => actual + linea.cantidad,
        ifAbsent: () => linea.cantidad,
      );
      productos.add(
        ProductoPedido(
          nombre: _nombreConDetalle(
            nombres[linea.productoId] ?? 'Producto ${linea.productoId}',
            linea,
          ),
          cantidad: linea.cantidad,
          precio: linea.precio,
        ),
      );
    }
    for (final item in pedido.items) {
      final resto = item.cantidad - (cubiertos[item.productoId] ?? 0);
      if (resto <= 0) continue;
      productos.add(
        ProductoPedido(
          nombre: item.nombre,
          cantidad: resto,
          precio: meta?.precioDe(item.productoId) ?? item.precioVenta,
        ),
      );
    }
    return productos;
  }

  String _fotoDe(PedidoResumen pedido, Map<int, DatoVidriera> vidriera) {
    for (final item in pedido.items) {
      final dato = vidriera[item.productoId];
      if (dato == null) continue;
      for (final foto in dato.galeria) {
        if (foto.base64.isNotEmpty) return foto.base64;
      }
      if (dato.fotoBase64.isNotEmpty) return dato.fotoBase64;
    }
    return '';
  }

  bool _pasaCanal(_PedidoVista pedido) {
    return _canal == 'web' ? pedido.esDeLaWeb : !pedido.esDeLaWeb;
  }

  bool _pasaFiltro(_PedidoVista pedido) {
    final leido = PedidoEstados.leer(pedido.estado);
    switch (_filtro) {
      case 'pendientes':
        return leido == PedidoEstado.pendiente ||
            leido == PedidoEstado.pendienteDePago;
      case 'en_proceso':
        return leido == PedidoEstado.confirmado;
      case 'entregados':
        return leido == PedidoEstado.entregado;
      case 'pagados':
        return leido == PedidoEstado.pagado;
      case 'cancelados':
        return leido == PedidoEstado.cancelado;
      default:
        return true;
    }
  }

  List<_PedidoVista> get _filtrados {
    final consulta = _consulta.trim().toLowerCase();
    final lista = _pedidos.where((pedido) {
      if (!_pasaCanal(pedido) || !_pasaFiltro(pedido)) return false;
      if (consulta.isEmpty) return true;
      final numero = 'p-${pedido.id.toString().padLeft(5, '0')}';
      final productos = pedido.productos.map((item) => item.nombre).join(' ');
      final texto = '${pedido.clienteNombre} $numero ${pedido.id} $productos'
          .toLowerCase();
      return texto.contains(consulta);
    }).toList();
    lista.sort((a, b) {
      final porFecha = b.fecha.compareTo(a.fecha);
      if (porFecha != 0) return porFecha;
      return b.id.compareTo(a.id);
    });
    return lista;
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<_PedidoVista> _cambiar(
    _PedidoVista pedido,
    PedidoEstado destino,
  ) async {
    if (!PedidoEstados.puedePasar(pedido.estado, destino)) {
      throw StateError('Esa transición no está permitida.');
    }
    final repo = _repo;
    if (repo == null) {
      final actualizado = pedido.copiar(
        estado: destino.texto,
        historial: [
          _CambioVista(
            anterior: pedido.estado,
            nuevo: destino.texto,
            fecha: DateTime.now(),
          ),
          ...pedido.historial,
        ],
      );
      if (!mounted) return actualizado;
      setState(() {
        final index = _pedidos.indexWhere((item) => item.id == pedido.id);
        if (index >= 0) _pedidos[index] = actualizado;
      });
      return actualizado;
    }

    await repo.cambiarEstado(pedido.id, destino.texto);
    if (!mounted) return pedido;
    await _cargar();
    if (!mounted) return pedido;
    for (final item in _pedidos) {
      if (item.id == pedido.id) return item;
    }
    throw StateError('El pedido no existe.');
  }

  Future<void> _nuevoPedido({bool ventaDirecta = false}) async {
    final repo = _repo;
    var clientes = const <ClientePedido>[];
    var productos = const <ProductoPedidoOpcion>[];
    var fichas = const <int, FichaProducto>{};
    var tomadas = const <int, Set<String>>{};
    if (repo != null) {
      try {
        clientes = await repo.listarClientes();
        productos = await repo.listarProductos();
        final doc = await const AmpliacionLocal().cargar();
        final pedidos = await repo.listarPedidos();
        fichas = doc.fichas;
        tomadas = const AmpliacionLocal().unidadesEnPedidos(doc, [
          for (final pedido in pedidos)
            if (PedidoEstados.leer(pedido.estado) != PedidoEstado.cancelado)
              pedido.id,
        ]);
      } catch (_) {
        if (!mounted) return;
        const mensaje = 'No se pudieron cargar clientes y productos.';
        setState(() => _error = mensaje);
        _avisar(mensaje);
        return;
      }
    }
    if (!mounted) return;

    final borrador = await showDialog<_BorradorPedido>(
      context: context,
      builder: (context) => _NuevoPedidoDialog(
        clientes: clientes,
        productos: productos,
        fichas: fichas,
        unidadesTomadas: tomadas,
        ventaDirecta: ventaDirecta,
      ),
    );
    if (borrador == null || !mounted) return;

    if (repo == null) {
      _guardarEnMemoria(borrador);
      return;
    }

    try {
      final id = await repo.crearPedido(
        clienteId: borrador.clienteId,
        clienteNombre:
            borrador.clienteId == null ? borrador.clienteNombre : null,
        montoSenado: borrador.montoSenado,
        descuento: borrador.descuentoMonto,
        medioPago: borrador.medioPago,
        fiado: borrador.fiado,
        lineas: [
          for (final linea in borrador.lineas)
            LineaPedidoBorrador(
              productoId: linea.productoId,
              nombreNuevo: linea.productoId == null ? linea.nombre : null,
              precioVenta: linea.precio,
              cantidad: linea.cantidad,
              pisarPrecioCatalogo: linea.variante.isEmpty,
            ),
        ],
      );
      final precios = <int, double>{};
      final detalladas = <LineaMeta>[];
      for (final linea in borrador.lineas) {
        final productoId = linea.productoId;
        if (productoId == null) continue;
        precios[productoId] = linea.precio;
        if (linea.unidad.isEmpty && linea.variante.isEmpty) continue;
        detalladas.add(
          LineaMeta(
            productoId: productoId,
            cantidad: linea.cantidad,
            precio: linea.precio,
            unidad: linea.unidad,
            variante: linea.variante,
          ),
        );
      }
      await const AmpliacionLocal().marcarPedido(
        pedidoId: id,
        origen: ventaDirecta ? 'venta' : 'local',
        precios: precios,
        lineas: detalladas,
        medioPago: borrador.medioPago,
        fiado: borrador.fiado,
        descuentoTipo: borrador.descuentoTipo,
        descuentoValor: borrador.descuentoValor,
        descuentoMonto: borrador.descuentoMonto,
      );
      if (borrador.montoSenado > 0) {
        await const AmpliacionLocal().anotarCobro(id);
      }
      if (borrador.fiado &&
          borrador.diaCobro != null &&
          borrador.clienteNombre.trim().isNotEmpty) {
        await const CobroLocal().guardar(
          persona: borrador.clienteNombre,
          fecha: borrador.diaCobro,
        );
      }
      if (ventaDirecta) {
        await repo.cambiarEstado(id, PedidoEstado.confirmado.texto);
      }
    } catch (error) {
      if (!mounted) return;
      final mensaje = _mensajeDe(error);
      setState(() => _error = mensaje);
      _avisar(mensaje);
      await _cargar();
      return;
    }

    if (!mounted) return;
    await _cargar();
  }

  void _guardarEnMemoria(_BorradorPedido borrador) {
    try {
      final subtotal = calcularMontoTotal([
        for (final linea in borrador.lineas)
          (precioVenta: linea.precio, cantidad: linea.cantidad),
      ]);
      final descuento = borrador.descuentoMonto < 0 ? 0.0 : borrador.descuentoMonto;
      if (descuento > subtotal + 0.009) {
        throw ArgumentError('El descuento no puede superar el total.');
      }
      final neto = subtotal - descuento;
      final estado = PedidoEstados.estadoInicial(
        sena: borrador.montoSenado,
        total: neto < 0 ? 0 : neto,
      );
      final id = _siguienteId();
      setState(() {
        _pedidos.add(
          _PedidoVista(
            id: id,
            clienteNombre: borrador.clienteNombre,
            fecha: DateTime.now(),
            estado: estado,
            montoSenado: borrador.montoSenado,
            productos: [
              for (final linea in borrador.lineas)
                ProductoPedido(
                  nombre: linea.nombre,
                  cantidad: linea.cantidad,
                  precio: linea.precio,
                ),
            ],
            historial: const [],
            medioPago: borrador.medioPago,
            fiado: borrador.fiado,
            descuentoMonto: descuento,
            descuentoTipo: borrador.descuentoTipo,
            descuentoValor: borrador.descuentoValor,
            origen: 'local',
          ),
        );
        _error = null;
      });
    } catch (error) {
      final mensaje = _mensajeDe(error);
      setState(() => _error = mensaje);
      _avisar(mensaje);
    }
  }

  int _siguienteId() {
    var maximo = 0;
    for (final pedido in _pedidos) {
      if (pedido.id > maximo) maximo = pedido.id;
    }
    return maximo + 1;
  }

  Future<void> _abrirDetalle(_PedidoVista pedido) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _DetalleDialog(
        pedido: pedido,
        conStock: _repo != null,
        onCambiar: (destino) => _cambiar(pedido, destino),
        onPagar: (pago) => _registrarPago(pedido, pago),
      ),
    );
  }

  Future<_PedidoVista> _registrarPago(_PedidoVista pedido, double pago) async {
    final repo = _repo;
    if (repo == null) {
      final nuevoMonto = pedido.montoSenado + pago;
      final leido = PedidoEstados.leer(pedido.estado);
      var estado = pedido.estado;
      if (nuevoMonto + 0.001 >= pedido.total &&
          (leido == PedidoEstado.pendiente ||
              leido == PedidoEstado.pendienteDePago)) {
        estado = PedidoEstado.pagado.texto;
      } else if (pedido.montoSenado <= 0 &&
          nuevoMonto + 0.001 < pedido.total &&
          leido == PedidoEstado.pendiente) {
        estado = PedidoEstado.pendienteDePago.texto;
      }
      final actualizado = pedido.copiar(
        estado: estado,
        montoSenado: nuevoMonto,
        historial: estado == pedido.estado
            ? pedido.historial
            : [
                _CambioVista(
                  anterior: pedido.estado,
                  nuevo: estado,
                  fecha: DateTime.now(),
                ),
                ...pedido.historial,
              ],
      );
      if (!mounted) return actualizado;
      setState(() {
        final index = _pedidos.indexWhere((item) => item.id == pedido.id);
        if (index >= 0) _pedidos[index] = actualizado;
      });
      return actualizado;
    }

    await repo.registrarSena(pedidoId: pedido.id, pago: pago);
    await const AmpliacionLocal().anotarCobro(pedido.id);
    if (!mounted) return pedido;
    await _cargar();
    if (!mounted) return pedido;
    for (final item in _pedidos) {
      if (item.id == pedido.id) return item;
    }
    return pedido;
  }

  Future<void> _cancelarDesdeLista(_PedidoVista pedido) async {
    final confirma = await _preguntarCancelar(context);
    if (!confirma || !mounted) return;
    try {
      await _cambiar(pedido, PedidoEstado.cancelado);
      if (!mounted) return;
      _avisar('Quedó cancelado. El historial se conserva.');
    } catch (error) {
      if (!mounted) return;
      final mensaje = _mensajeDe(error);
      setState(() => _error = mensaje);
      _avisar(mensaje);
    }
  }

  Iterable<_PedidoVista> get _delCanal =>
      _pedidos.where(_pasaCanal);

  int get _pedidosHoy {
    final ahora = DateTime.now();
    return _delCanal.where((pedido) {
      final fecha = pedido.fecha;
      return fecha.year == ahora.year &&
          fecha.month == ahora.month &&
          fecha.day == ahora.day;
    }).length;
  }

  int get _pendientes {
    return _delCanal.where((pedido) {
      final leido = PedidoEstados.leer(pedido.estado);
      return leido == PedidoEstado.pendiente ||
          leido == PedidoEstado.pendienteDePago;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'venta-directa',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF16A34A),
            elevation: 2,
            onPressed: () => _nuevoPedido(ventaDirecta: true),
            tooltip: 'Venta directa',
            child: const Icon(Icons.point_of_sale),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'nuevo-pedido',
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            elevation: 3,
            onPressed: _nuevoPedido,
            icon: const Icon(Icons.add),
            label: const Text(
              'Nuevo pedido',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  Text(
                    'Pedidos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gestiona y da seguimiento a tus pedidos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                style: const TextStyle(color: AppColors.texto, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Buscar pedido, cliente o producto...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFF22C55E)),
                  ),
                ),
                onChanged: (valor) => setState(() => _consulta = valor),
              ),
            ),
            const SizedBox(height: 12),
            _canales(),
            const SizedBox(height: 10),
            _filtros(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _ResumenDia(
                      icono: Icons.shopping_cart_outlined,
                      color: const Color(0xFF22C55E),
                      fondo: const Color(0xFFE8F8EE),
                      titulo: 'Pedidos hoy',
                      valor: _pedidosHoy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResumenDia(
                      icono: Icons.assignment_outlined,
                      color: const Color(0xFF3B82F6),
                      fondo: const Color(0xFFE8F1FE),
                      titulo: 'Pendientes',
                      valor: _pendientes,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.alerta),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF22C55E),
                onRefresh: _cargar,
                child: _contenido(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canales() {
    const opciones = [
      ('manual', 'Pedidos manuales'),
      ('web', 'Pedidos por la página web'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < opciones.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _CanalPedido(
                titulo: opciones[i].$2,
                activo: _canal == opciones[i].$1,
                onTap: () => setState(() => _canal = opciones[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filtros() {
    const opciones = [
      ('todos', 'Todos'),
      ('pendientes', 'Pendientes'),
      ('en_proceso', 'En proceso'),
      ('entregados', 'Entregados'),
      ('pagados', 'Pagados'),
      ('cancelados', 'Cancelados'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: opciones.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opcion = opciones[index].$1;
          final etiqueta = opciones[index].$2;
          final activo = _filtro == opcion;
          return ChoiceChip(
            label: Text(etiqueta),
            selected: activo,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelStyle: TextStyle(
              color: activo ? Colors.white : const Color(0xFF4B5563),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            selectedColor: const Color(0xFF22C55E),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: activo ? const Color(0xFF22C55E) : const Color(0xFFE5E7EB),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) => setState(() => _filtro = opcion),
          );
        },
      ),
    );
  }

  Widget _contenido() {
    if (_cargando && _pedidos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final pedidos = _filtrados;
    if (pedidos.isEmpty) {
      final vacioDelCanal = _delCanal.isEmpty;
      final mensaje = _pedidos.isEmpty
          ? (_error == null
              ? 'Todavía no hay pedidos.\nTocá Nuevo pedido para cargar uno.'
              : 'Probá de nuevo deslizando hacia abajo.')
          : vacioDelCanal
              ? (_canal == 'web'
                  ? 'Todavía no hay pedidos por la página web.'
                  : 'Todavía no hay pedidos manuales.')
              : 'Ningún pedido coincide con ese filtro.';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 72),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textoSuave),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: [for (final pedido in pedidos) _tarjeta(pedido)],
    );
  }

  Widget _tarjeta(_PedidoVista pedido) {
    final color = colorPedidoEstado(pedido.estado);
    final resumen = pedido.productos.isEmpty
        ? 'Sin productos'
        : pedido.productos
            .map((producto) => '${producto.nombre} (${producto.cantidad})')
            .join(', ');
    final numero = pedido.id.toString().padLeft(5, '0');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F3A5A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _abrirDetalle(pedido),
          onLongPress: () {
            final puedeCancelar = PedidoEstados.siguientesDe(pedido.estado)
                .contains(PedidoEstado.cancelado);
            if (puedeCancelar) _cancelarDesdeLista(pedido);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniaturaPedido(foto: _fotos[pedido.id] ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Pedido #P-$numero',
                              style: const TextStyle(
                                color: AppColors.textoSuave,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _etiquetaTarjeta(pedido.estado),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pedido.clienteNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resumen,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.textoSuave,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _fechaLista(pedido.fecha),
                              style: const TextStyle(
                                color: AppColors.textoSuave,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            formatearMoneda(pedido.total, _codigoMoneda),
                            style: const TextStyle(
                              color: AppColors.texto,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (pedido.fiado ||
                          pedido.medioPago.isNotEmpty ||
                          pedido.montoSenado > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              if (pedido.montoSenado > 0)
                                'Seña ${formatearMoneda(pedido.montoSenado, _codigoMoneda)}',
                              if (pedido.medioPago.isNotEmpty)
                                MetaPedido.etiquetaMedio(pedido.medioPago),
                              if (pedido.fiado) 'Fiado',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.textoSuave,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CanalPedido extends StatelessWidget {
  const _CanalPedido({
    required this.titulo,
    required this.activo,
    required this.onTap,
  });

  final String titulo;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? const Color(0xFF22C55E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activo ? const Color(0xFF22C55E) : const Color(0xFFE5E7EB),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: activo ? Colors.white : const Color(0xFF4B5563),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResumenDia extends StatelessWidget {
  const _ResumenDia({
    required this.icono,
    required this.color,
    required this.fondo,
    required this.titulo,
    required this.valor,
  });

  final IconData icono;
  final Color color;
  final Color fondo;
  final String titulo;
  final int valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F3A5A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$valor',
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniaturaPedido extends StatelessWidget {
  const _MiniaturaPedido({required this.foto});

  final String foto;

  @override
  Widget build(BuildContext context) {
    final bytes = bytesDeFotoVidriera(foto);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 64,
        child: bytes == null
            ? const ColoredBox(
                color: Color(0xFFF3F4F6),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF9CA3AF),
                ),
              )
            : Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final color = colorPedidoEstado(estado);
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(PedidoEstados.etiqueta(estado)),
      backgroundColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _NuevoPedidoDialog extends StatefulWidget {
  const _NuevoPedidoDialog({
    required this.clientes,
    required this.productos,
    this.fichas = const {},
    this.unidadesTomadas = const {},
    this.ventaDirecta = false,
  });

  final List<ClientePedido> clientes;
  final List<ProductoPedidoOpcion> productos;
  final Map<int, FichaProducto> fichas;
  final Map<int, Set<String>> unidadesTomadas;
  final bool ventaDirecta;

  @override
  State<_NuevoPedidoDialog> createState() => _NuevoPedidoDialogState();
}

class _NuevoPedidoDialogState extends State<_NuevoPedidoDialog>
    with _ConMoneda {
  final _nombreClienteCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _senaCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  final List<_LineaUi> _lineas = [];
  int? _clienteId;
  int? _productoId;
  String _variante = '';
  String _unidad = '';
  bool _modoNuevo = true;
  bool _pagoCompleto = false;
  bool _fiado = false;
  String _medioPago = '';
  DateTime? _diaCobro;
  String _descuentoModo = 'monto';
  String? _error;

  double get _bruto => calcularMontoTotal([
        for (final linea in _lineas)
          (precioVenta: linea.precio, cantidad: linea.cantidad),
      ]);

  double? _descuentoIngresado() {
    final texto = _descuentoCtrl.text.trim();
    if (texto.isEmpty) return 0;
    return _parseMonto(texto);
  }

  String? _errorDescuento() {
    final texto = _descuentoCtrl.text.trim();
    if (texto.isEmpty) return null;
    final valor = _parseMonto(texto);
    if (valor == null) return 'El descuento no es un número válido.';
    if (valor < 0) return 'El descuento no puede ser negativo.';
    if (_descuentoModo == 'porcentaje' && valor > 100.009) {
      return 'El porcentaje no puede pasar de 100.';
    }
    if (_descuentoModo == 'monto' && valor > _bruto + 0.009) {
      return 'El descuento no puede superar el total.';
    }
    return null;
  }

  double get _descuentoMonto {
    if (_errorDescuento() != null) return 0;
    final texto = _descuentoCtrl.text.trim();
    if (texto.isEmpty) return 0;
    return descuentoEnDinero(
      bruto: _bruto,
      tipo: _descuentoModo,
      valor: _descuentoIngresado() ?? 0,
    );
  }

  double get _total {
    final neto = _bruto - _descuentoMonto;
    return neto < 0 ? 0 : neto;
  }

  @override
  void initState() {
    super.initState();
    _leerMoneda();
    if (widget.clientes.isNotEmpty) {
      _clienteId = widget.clientes.first.id;
    }
    if (widget.productos.isNotEmpty) {
      _modoNuevo = false;
      _productoId = widget.productos.first.id;
      _aplicarPrecioDeProducto();
    }
    _senaCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _descuentoCtrl.addListener(() {
      _syncSena();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nombreClienteCtrl.dispose();
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _cantidadCtrl.dispose();
    _senaCtrl.dispose();
    _descuentoCtrl.dispose();
    super.dispose();
  }

  FichaProducto? get _ficha {
    final id = _productoId;
    if (id == null || _modoNuevo) return null;
    return widget.fichas[id];
  }

  List<VarianteLocal> get _variantes =>
      _ficha?.variantes.where((variante) => variante.etiqueta.isNotEmpty).toList() ??
      const [];

  bool get _controlaStock => _ficha?.controlaStock ?? true;

  bool get _pideVariante => _controlaStock && _variantes.isNotEmpty;

  bool get _pideUnidad =>
      _controlaStock &&
      (_ficha?.unidades.any((unidad) => unidad.codigo.isNotEmpty) ?? false);

  void _aplicarPrecioDeProducto() {
    for (final producto in widget.productos) {
      if (producto.id == _productoId) {
        _precioCtrl.text = producto.precioVenta.toStringAsFixed(2);
        _aplicarPrecioDeVariante();
        return;
      }
    }
  }

  void _aplicarPrecioDeVariante() {
    if (_variante.isEmpty) return;
    for (final variante in _variantes) {
      if (variante.etiqueta != _variante) continue;
      final propio = variante.precio;
      if (propio == null) return;
      _precioCtrl.text = propio.toStringAsFixed(2);
      return;
    }
  }

  List<UnidadSerie> _unidadesElegibles(int productoId) {
    final ficha = widget.fichas[productoId];
    if (ficha == null) return const [];
    final tomadas = widget.unidadesTomadas[productoId] ?? const <String>{};
    final enPedido = <String>{
      for (final linea in _lineas)
        if (linea.productoId == productoId && linea.unidad.isNotEmpty)
          linea.unidad.toLowerCase(),
    };
    return [
      for (final unidad in ficha.unidades)
        if (unidad.codigo.isNotEmpty &&
            unidad.estado == 'disponible' &&
            !tomadas.contains(unidad.codigo.toLowerCase()) &&
            !enPedido.contains(unidad.codigo.toLowerCase()))
          unidad,
    ];
  }

  VarianteLocal? _varianteElegida() {
    for (final variante in _variantes) {
      if (variante.etiqueta == _variante) return variante;
    }
    return null;
  }

  bool _misma(_LineaUi a, _LineaUi b) {
    if (a.unidad.isNotEmpty || b.unidad.isNotEmpty) return false;
    if (a.variante.toLowerCase() != b.variante.toLowerCase()) return false;
    if (a.productoId != null && b.productoId != null) {
      return a.productoId == b.productoId;
    }
    return a.nombre.trim().toLowerCase() == b.nombre.trim().toLowerCase();
  }

  void _sumar(_LineaUi linea) {
    if (linea.unidad.isNotEmpty) {
      _lineas.add(linea);
      return;
    }
    final index = _lineas.indexWhere((actual) => _misma(actual, linea));
    if (index >= 0) {
      final previa = _lineas[index];
      _lineas[index] = _LineaUi(
        productoId: previa.productoId ?? linea.productoId,
        nombre: previa.nombre,
        cantidad: previa.cantidad + linea.cantidad,
        precio: linea.precio,
        variante: previa.variante,
      );
    } else {
      _lineas.add(linea);
    }
  }

  void _syncSena() {
    if (_pagoCompleto) {
      _senaCtrl.text = _total.toStringAsFixed(2);
    }
  }

  double? _senaActual() {
    if (_pagoCompleto) return _total;
    final texto = _senaCtrl.text.trim();
    if (texto.isEmpty) return 0;
    return _parseMonto(texto);
  }

  String _estadoPrevisto() {
    final sena = _senaActual();
    if (sena == null) return 'La seña no es un número válido.';
    try {
      return PedidoEstados.etiqueta(
        PedidoEstados.estadoInicial(sena: sena, total: _total),
      );
    } on ArgumentError catch (error) {
      final mensaje = error.message;
      if (mensaje is String && mensaje.isNotEmpty) return mensaje;
      return 'Revisá la seña.';
    }
  }

  void _agregar() {
    final cantidadIngresada = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    final cantidad = !_modoNuevo && _pideUnidad ? 1 : cantidadIngresada;
    final precio = _parseMonto(_precioCtrl.text);
    if (cantidad <= 0 || precio == null || precio < 0) {
      setState(() {
        _error = 'Completá una cantidad mayor a cero y el precio.';
      });
      return;
    }

    if (_modoNuevo || widget.productos.isEmpty) {
      final nombre = _nombreCtrl.text.trim();
      if (nombre.isEmpty) {
        setState(() => _error = 'Escribí el nombre del producto.');
        return;
      }
      ProductoPedidoOpcion? existente;
      for (final item in widget.productos) {
        if (item.nombre.trim().toLowerCase() == nombre.toLowerCase()) {
          existente = item;
          break;
        }
      }
      final fichaExistente = existente == null ? null : widget.fichas[existente.id];
      final tieneDetalle = fichaExistente != null &&
          fichaExistente.controlaStock &&
          (fichaExistente.unidades.any((unidad) => unidad.codigo.isNotEmpty) ||
              fichaExistente.variantes.any((variante) => variante.etiqueta.isNotEmpty));
      if (tieneDetalle) {
        setState(() {
          _error =
              'Ese producto tiene unidades o variantes. Elegilo en Existente para marcar cuál se vende.';
        });
        return;
      }
      _sumar(
        _LineaUi(
          productoId: existente?.id,
          nombre: existente?.nombre ?? nombre,
          cantidad: cantidad,
          precio: precio,
        ),
      );
      _nombreCtrl.clear();
      _precioCtrl.clear();
    } else {
      ProductoPedidoOpcion? producto;
      for (final item in widget.productos) {
        if (item.id == _productoId) producto = item;
      }
      if (producto == null) {
        setState(() => _error = 'Elegí un producto.');
        return;
      }
      final detalle = _validarDetalle(producto.id, cantidad);
      if (detalle != null) {
        setState(() => _error = detalle);
        return;
      }
      final unidad = _pideUnidad ? _unidad : '';
      final variante = _pideVariante ? _variante : '';
      _sumar(
        _LineaUi(
          productoId: producto.id,
          nombre: producto.nombre,
          cantidad: unidad.isEmpty ? cantidad : 1,
          precio: precio,
          unidad: unidad,
          variante: variante,
        ),
      );
      if (unidad.isNotEmpty) _unidad = '';
    }

    _cantidadCtrl.text = '1';
    setState(() => _error = null);
    _syncSena();
  }

  String? _validarDetalle(int productoId, int cantidad) {
    final ficha = widget.fichas[productoId];
    if (ficha == null) return null;
    if (_pideVariante) {
      if (_variante.isEmpty) return 'Elegí la variante.';
      final variante = _varianteElegida();
      if (variante == null) return 'Esa variante ya no está.';
      final enPedido = _lineas
          .where(
            (linea) =>
                linea.productoId == productoId &&
                linea.variante.toLowerCase() == variante.etiqueta.toLowerCase(),
          )
          .fold<int>(0, (suma, linea) => suma + linea.cantidad);
      final pedida = _pideUnidad ? 1 : cantidad;
      if (variante.stock <= 0 || pedida + enPedido > variante.stock) {
        return 'No hay stock suficiente de ${variante.etiqueta}. Hay ${variante.stock}.';
      }
    }
    if (_pideUnidad) {
      if (_unidad.isEmpty) return 'Elegí la unidad disponible.';
      final elegibles = _unidadesElegibles(productoId);
      final ok = elegibles.any(
        (unidad) => unidad.codigo.toLowerCase() == _unidad.toLowerCase(),
      );
      if (!ok) {
        return 'Esa unidad no está disponible o ya está en otro pedido.';
      }
    }
    return null;
  }

  void _quitar(int index) {
    setState(() {
      _lineas.removeAt(index);
      _error = null;
    });
    _syncSena();
  }

  Future<void> _elegirDiaCobro() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _diaCobro ?? hoy,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 3, hoy.month, hoy.day),
      helpText: 'Día de cobro',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _diaCobro = DateTime(elegida.year, elegida.month, elegida.day);
    });
  }

  void _guardar() {
    final nombreLibre = _nombreClienteCtrl.text.trim();
    final int? clienteId;
    final String clienteNombre;
    if (nombreLibre.isNotEmpty) {
      clienteId = null;
      clienteNombre = nombreLibre;
    } else if (_clienteId != null) {
      clienteId = _clienteId;
      String nombre = '';
      for (final cliente in widget.clientes) {
        if (cliente.id == _clienteId) nombre = cliente.nombre;
      }
      clienteNombre = nombre;
    } else {
      setState(() {
        _error = widget.clientes.isEmpty
            ? 'Escribí el nombre del cliente.'
            : 'Elegí un cliente o escribí su nombre.';
      });
      return;
    }
    if (clienteId == null && clienteNombre.isEmpty) {
      setState(() => _error = 'Escribí el nombre del cliente.');
      return;
    }
    if (_lineas.isEmpty) {
      setState(() => _error = 'Agregá al menos un producto.');
      return;
    }

    final errorDescuento = _errorDescuento();
    if (errorDescuento != null) {
      setState(() => _error = errorDescuento);
      return;
    }
    final valorDescuento = _descuentoIngresado() ?? 0;
    final descuento = _descuentoCtrl.text.trim().isEmpty
        ? 0.0
        : descuentoEnDinero(
            bruto: _bruto,
            tipo: _descuentoModo,
            valor: valorDescuento,
          );

    final sena = _senaActual();
    if (sena == null) {
      setState(() => _error = 'La seña no es un número válido.');
      return;
    }
    if (sena < 0) {
      setState(() => _error = 'La seña no puede ser negativa.');
      return;
    }
    if (sena > _total + 0.009) {
      setState(() => _error = 'La seña no puede ser mayor al total.');
      return;
    }
    if (_medioPago.isEmpty && !_fiado) {
      setState(() {
        _error = 'Elegí efectivo, transferencia, otro o fiado.';
      });
      return;
    }

    Navigator.pop(
      context,
      _BorradorPedido(
        clienteId: clienteId,
        clienteNombre: clienteNombre,
        montoSenado: sena,
        lineas: List<_LineaUi>.of(_lineas),
        medioPago: _medioPago,
        fiado: _fiado,
        diaCobro: _fiado ? _diaCobro : null,
        descuentoTipo: descuento > 0 ? _descuentoModo : '',
        descuentoValor: descuento > 0 ? valorDescuento : 0,
        descuentoMonto: descuento,
      ),
    );
  }

  Widget _selectorVariante() {
    final vistas = <String>{};
    final opciones = [
      for (final variante in _variantes)
        if (vistas.add(variante.etiqueta)) variante,
    ];
    return DropdownButton<String>(
      isExpanded: true,
      value: opciones.any((variante) => variante.etiqueta == _variante)
          ? _variante
          : null,
      hint: const Text(
        'Elegí la variante',
        style: TextStyle(color: AppColors.textoSuave),
      ),
      items: [
        for (final variante in opciones)
          DropdownMenuItem(
            value: variante.etiqueta,
            child: Text(
              variante.stock <= 0
                  ? '${variante.etiqueta} · agotada'
                  : variante.precio == null
                      ? '${variante.etiqueta} · stock ${variante.stock}'
                      : '${variante.etiqueta} · stock ${variante.stock} · ${formatearMoneda(variante.precio!, _codigoMoneda)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.texto),
            ),
          ),
      ],
      onChanged: (valor) {
        setState(() {
          _variante = valor ?? '';
          _error = null;
          _aplicarPrecioDeVariante();
        });
      },
    );
  }

  Widget _selectorUnidad() {
    final productoId = _productoId;
    final elegibles =
        productoId == null ? const <UnidadSerie>[] : _unidadesElegibles(productoId);
    if (elegibles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          'No hay unidades disponibles de este producto.',
          style: TextStyle(color: AppColors.alerta),
        ),
      );
    }
    return DropdownButton<String>(
      isExpanded: true,
      value: elegibles.any((unidad) => unidad.codigo == _unidad) ? _unidad : null,
      hint: const Text(
        'Elegí la unidad (serie o IMEI)',
        style: TextStyle(color: AppColors.textoSuave),
      ),
      items: [
        for (final unidad in elegibles)
          DropdownMenuItem(
            value: unidad.codigo,
            child: Text(
              unidad.codigo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.texto),
            ),
          ),
      ],
      onChanged: (valor) => setState(() {
        _unidad = valor ?? '';
        _error = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorDescuento = _errorDescuento();
    final previsto = errorDescuento ?? _estadoPrevisto();
    final previstoEsError = errorDescuento != null ||
        previsto.contains('seña') ||
        previsto.contains('Revisá');
    return AlertDialog(
      title: Text(
        widget.ventaDirecta ? 'Venta directa' : 'Nuevo pedido',
        style: const TextStyle(color: AppColors.texto, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.clientes.isNotEmpty)
              DropdownButton<int>(
                isExpanded: true,
                value: _clienteId,
                items: [
                  for (final cliente in widget.clientes)
                    DropdownMenuItem(
                      value: cliente.id,
                      child: Text(
                        cliente.nombre,
                        style: const TextStyle(color: AppColors.texto),
                      ),
                    ),
                ],
                onChanged: (valor) => setState(() => _clienteId = valor),
              ),
            TextField(
              controller: _nombreClienteCtrl,
              style: const TextStyle(color: AppColors.texto),
              decoration: InputDecoration(
                labelText: widget.clientes.isEmpty
                    ? 'Nombre del cliente'
                    : 'O escribí otro nombre',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (widget.clientes.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Si escribís un nombre, se usa ese y no el de la lista.',
                  style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            if (widget.productos.isNotEmpty)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Existente')),
                  ButtonSegment(value: true, label: Text('Nuevo')),
                ],
                selected: {_modoNuevo},
                onSelectionChanged: (seleccion) {
                  setState(() {
                    _modoNuevo = seleccion.first;
                    _variante = '';
                    _unidad = '';
                    if (_modoNuevo) {
                      _precioCtrl.clear();
                    } else {
                      _aplicarPrecioDeProducto();
                    }
                  });
                },
              ),
            if (widget.productos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'No hay productos cargados. Escribí nombre, cantidad y precio.',
                  style: TextStyle(color: AppColors.textoSuave),
                ),
              ),
            const SizedBox(height: 8),
            if (!_modoNuevo && widget.productos.isNotEmpty)
              DropdownButton<int>(
                isExpanded: true,
                value: _productoId,
                items: [
                  for (final producto in widget.productos)
                    DropdownMenuItem(
                      value: producto.id,
                      child: Text(
                        producto.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.texto),
                      ),
                    ),
                ],
                onChanged: (valor) {
                  setState(() {
                    _productoId = valor;
                    _variante = '';
                    _unidad = '';
                    _aplicarPrecioDeProducto();
                  });
                },
              ),
            if (!_modoNuevo && _pideVariante) _selectorVariante(),
            if (!_modoNuevo && _pideUnidad) _selectorUnidad(),
            if (_modoNuevo || widget.productos.isEmpty)
              TextField(
                controller: _nombreCtrl,
                style: const TextStyle(color: AppColors.texto),
                decoration: const InputDecoration(labelText: 'Producto'),
              ),
            TextField(
              controller: _precioCtrl,
              style: const TextStyle(color: AppColors.texto),
              decoration: InputDecoration(labelText: 'Precio ($_codigoMoneda)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            Row(
              children: [
                if (_modoNuevo || !_pideUnidad) ...[
                  SizedBox(
                    width: 88,
                    child: TextField(
                      controller: _cantidadCtrl,
                      style: const TextStyle(color: AppColors.texto),
                      decoration: const InputDecoration(labelText: 'Cant.'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Expanded(
                    child: Text(
                      'Esta unidad se vende de a una.',
                      style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _agregar,
                  icon: const Icon(Icons.add, color: AppColors.primario),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            for (var i = 0; i < _lineas.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  _lineas[i].titulo,
                  style: const TextStyle(color: AppColors.texto),
                ),
                subtitle: Text(
                  '${formatearMoneda(_lineas[i].precio, _codigoMoneda)} c/u · ${formatearMoneda(_lineas[i].subtotal, _codigoMoneda)}',
                  style: const TextStyle(color: AppColors.textoSuave),
                ),
                trailing: IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.alerta),
                  onPressed: () => _quitar(i),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Descuento',
              style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Baja el total de esta venta. El precio del producto queda igual.',
              style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'monto', label: Text('Monto')),
                ButtonSegment(value: 'porcentaje', label: Text('%')),
              ],
              selected: {_descuentoModo},
              onSelectionChanged: (seleccion) {
                setState(() {
                  _descuentoModo = seleccion.first;
                  _error = null;
                });
                _syncSena();
              },
            ),
            TextField(
              controller: _descuentoCtrl,
              style: const TextStyle(color: AppColors.texto),
              decoration: InputDecoration(
                labelText: _descuentoModo == 'porcentaje'
                    ? 'Porcentaje'
                    : 'Descuento ($_codigoMoneda)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_descuentoMonto > 0.009) ...[
              Text(
                'Subtotal ${formatearMoneda(_bruto, _codigoMoneda)}',
                style: const TextStyle(color: AppColors.textoSuave),
              ),
              Text(
                _descuentoModo == 'porcentaje'
                    ? 'Descuento ${_descuentoCtrl.text.trim()}% · ${formatearMoneda(_descuentoMonto, _codigoMoneda)}'
                    : 'Descuento ${formatearMoneda(_descuentoMonto, _codigoMoneda)}',
                style: const TextStyle(color: AppColors.texto),
              ),
            ],
            Text(
              'Total ${formatearMoneda(_total, _codigoMoneda)}',
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'La seña se muestra aparte y no se resta del total.',
              style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Medio de pago',
              style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final medio in MetaPedido.medios)
                  ChoiceChip(
                    label: Text(MetaPedido.etiquetaMedio(medio)),
                    selected: _medioPago == medio,
                    onSelected: (activo) => setState(() {
                      _medioPago = activo ? medio : '';
                    }),
                  ),
              ],
            ),
            CheckboxListTile(
              value: _fiado,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primario,
              title: const Text(
                'Fiado',
                style: TextStyle(color: AppColors.texto),
              ),
              subtitle: const Text(
                'La seña puede quedar en 0. El saldo se anota para cobrar, sin duplicar la deuda.',
                style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
              ),
              onChanged: (valor) {
                setState(() {
                  _fiado = valor ?? false;
                  if (_fiado && _pagoCompleto) {
                    _pagoCompleto = false;
                    _senaCtrl.text = '';
                  }
                  if (!_fiado) _diaCobro = null;
                  _error = null;
                });
              },
            ),
            if (_fiado)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _elegirDiaCobro,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _diaCobro == null
                        ? 'Día de cobro'
                        : 'Cobrar el ${_diaCobro!.day}/${_diaCobro!.month}/${_diaCobro!.year}',
                  ),
                ),
              ),
            CheckboxListTile(
              value: _pagoCompleto,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primario,
              title: const Text(
                'Pago completo',
                style: TextStyle(color: AppColors.texto),
              ),
              onChanged: (valor) {
                setState(() {
                  _pagoCompleto = valor ?? false;
                  if (_pagoCompleto) _fiado = false;
                });
                _syncSena();
              },
            ),
            if (!_pagoCompleto)
              TextField(
                controller: _senaCtrl,
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(labelText: 'Seña ($_codigoMoneda)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Seña ${formatearMoneda(_total, _codigoMoneda)}',
                  style: const TextStyle(color: AppColors.texto),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              previstoEsError ? previsto : 'Va a quedar como: $previsto',
              style: TextStyle(
                color:
                    previstoEsError ? AppColors.alerta : AppColors.textoSuave,
                fontWeight: FontWeight.w600,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: _botonEstadio,
          onPressed: _guardar,
          child: Text(widget.ventaDirecta ? 'Guardar venta' : 'Guardar'),
        ),
      ],
    );
  }
}

class _DetalleDialog extends StatefulWidget {
  const _DetalleDialog({
    required this.pedido,
    required this.conStock,
    required this.onCambiar,
    required this.onPagar,
  });

  final _PedidoVista pedido;
  final bool conStock;
  final Future<_PedidoVista> Function(PedidoEstado destino) onCambiar;
  final Future<_PedidoVista> Function(double pago) onPagar;

  @override
  State<_DetalleDialog> createState() => _DetalleDialogState();
}

class _DetalleDialogState extends State<_DetalleDialog> with _ConMoneda {
  late _PedidoVista _pedido = widget.pedido;
  MetaPedido? _meta;
  bool _ocupado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _leerMoneda();
    _leerComprobante();
  }

  Future<void> _leerComprobante() async {
    final doc = await const AmpliacionLocal().cargar();
    if (!mounted) return;
    setState(() => _meta = doc.pedidos[_pedido.id]);
  }

  bool get _cerrado {
    final estado = PedidoEstados.leer(_pedido.estado);
    return estado == PedidoEstado.entregado || estado == PedidoEstado.cancelado;
  }

  Future<void> _adjuntar() async {
    if (_ocupado || _cerrado) return;
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 45,
      );
      if (archivo == null) return;
      final texto = base64Encode(await archivo.readAsBytes());
      final meta = await const AmpliacionLocal().guardarComprobante(
        pedidoId: _pedido.id,
        base64: texto,
        estado: 'pendiente',
      );
      if (!mounted) return;
      setState(() => _meta = meta);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _mensajeDe(error));
    }
  }

  Future<void> _resolverComprobante(String estado) async {
    final actual = _meta;
    if (actual == null || actual.comprobante.isEmpty || _ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final meta = await const AmpliacionLocal().guardarComprobante(
        pedidoId: _pedido.id,
        base64: actual.comprobante,
        estado: estado,
      );
      if (!mounted) return;
      setState(() => _meta = meta);
      if (estado == 'aceptado' &&
          PedidoEstados.puedePasar(_pedido.estado, PedidoEstado.pagado)) {
        final nuevo = await widget.onCambiar(PedidoEstado.pagado);
        if (!mounted) return;
        setState(() => _pedido = nuevo);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _mensajeDe(error));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _elegir(PedidoEstado destino) async {
    if (_ocupado) return;
    if (destino == PedidoEstado.cancelado) {
      final confirma = await _preguntarCancelar(context);
      if (!confirma || !mounted) return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final nuevo = await widget.onCambiar(destino);
      if (!mounted) return;
      setState(() {
        _pedido = nuevo;
        _ocupado = false;
      });
      if (destino == PedidoEstado.cancelado && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quedó cancelado. El historial se conserva.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = _mensajeDe(error);
      });
    }
  }

  Future<void> _cobrar() async {
    if (_ocupado) return;
    final resta = _pedido.total - _pedido.montoSenado;
    final campo = TextEditingController();
    final pago = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar pago'),
        content: TextField(
          controller: campo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto',
            helperText: 'Resta ${formatearMoneda(resta, _codigoMoneda)}. No puede superarlo.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final valor = leerMontoEscrito(campo.text);
              Navigator.pop(dialogContext, valor);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    campo.dispose();
    if (pago == null || !mounted) return;
    if (pago <= 0 || pago - resta > 0.009) {
      setState(() => _error = 'Ingresá un pago mayor a cero y hasta lo que resta.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final nuevo = await widget.onPagar(pago);
      if (!mounted) return;
      setState(() {
        _pedido = nuevo;
        _ocupado = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = _mensajeDe(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final opciones = PedidoEstados.siguientesDe(_pedido.estado);
    final resta = _pedido.total - _pedido.montoSenado;
    final avisaStock =
        widget.conStock && opciones.any((estado) => estado.reservaStock);
    return AlertDialog(
      title: const Text(
        'Detalle del pedido',
        style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pedido.clienteNombre,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fechaCorta(_pedido.fecha),
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            _EstadoChip(estado: _pedido.estado),
            const SizedBox(height: 8),
            if (_pedido.descuentoMonto > 0.009) ...[
              Text(
                'Subtotal ${formatearMoneda(_pedido.subtotal, _codigoMoneda)}',
                style: const TextStyle(color: AppColors.textoSuave),
              ),
              Text(
                _etiquetaDescuento(_pedido, _codigoMoneda),
                style: const TextStyle(color: AppColors.texto),
              ),
            ],
            Text(
              'Total ${formatearMoneda(_pedido.total, _codigoMoneda)}',
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_pedido.medioPago.isNotEmpty)
              Text(
                'Medio de pago: ${MetaPedido.etiquetaMedio(_pedido.medioPago)}',
                style: const TextStyle(color: AppColors.texto),
              ),
            Text(
              'Seña ${formatearMoneda(_pedido.montoSenado, _codigoMoneda)}',
              style: const TextStyle(color: AppColors.texto),
            ),
            if (_pedido.vendidoPor.isNotEmpty)
              Text(
                'Vendió ${_pedido.vendidoPor}',
                style: const TextStyle(color: AppColors.textoSuave),
              ),
            if (_pedido.cobradoPor.isNotEmpty)
              Text(
                'Cobró ${_pedido.cobradoPor}',
                style: const TextStyle(color: AppColors.textoSuave),
              ),
            if (_pedido.fiado)
              Text(
                resta > 0.009
                    ? 'Quedó fiada. El saldo se anota para cobrar.'
                    : 'Quedó fiada.',
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (resta > 0.009) ...[
              Text(
                'Resta ${formatearMoneda(resta, _codigoMoneda)}',
                style: const TextStyle(color: AppColors.textoSuave),
              ),
              if (PedidoEstados.leer(_pedido.estado) != PedidoEstado.cancelado)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _ocupado ? null : _cobrar,
                    child: const Text('Registrar pago'),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Comprobante',
              style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if (_meta != null && _meta!.comprobante.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(_meta!.comprobante),
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Text(
                    'No se pudo mostrar la imagen.',
                    style: TextStyle(color: AppColors.alerta),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _meta!.comprobanteEstado.isEmpty
                    ? 'Pendiente de revisión'
                    : 'Estado: ${_meta!.comprobanteEstado}',
                style: const TextStyle(color: AppColors.textoSuave),
              ),
              if (!_cerrado && _meta!.comprobanteEstado != 'aceptado')
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _ocupado ? null : () => _resolverComprobante('aceptado'),
                      child: const Text('Aceptar'),
                    ),
                    TextButton(
                      onPressed: _ocupado ? null : () => _resolverComprobante('rechazado'),
                      child: const Text('Rechazar'),
                    ),
                  ],
                ),
            ],
            if (!_cerrado)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _ocupado ? null : _adjuntar,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Adjuntar comprobante'),
                ),
              ),
            const SizedBox(height: 12),
            if (opciones.isEmpty)
              const Text(
                'Este pedido no tiene más acciones.',
                style: TextStyle(color: AppColors.textoSuave),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final destino in opciones)
                    ActionChip(
                      label: Text(destino.accion),
                      onPressed: _ocupado ? null : () => _elegir(destino),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: colorPedidoEstado(destino.texto)
                          .withValues(alpha: 0.14),
                      side: BorderSide(
                        color: colorPedidoEstado(destino.texto)
                            .withValues(alpha: 0.45),
                      ),
                      labelStyle: TextStyle(
                        color: colorPedidoEstado(destino.texto),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            if (avisaStock) ...[
              const SizedBox(height: 8),
              const Text(
                'Al confirmar o entregar se descuenta stock de lo que controla stock: primero el de Yo y, si no alcanza, el de Nildo. Si hay una unidad, pasa a vendida. Si hay una variante, se descuenta esa variante. Un servicio que no controla stock no descuenta ni pide unidades. Si falta stock de lo que sí controla, el estado no cambia.',
                style: TextStyle(color: AppColors.textoSuave, height: 1.3),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Productos',
              style: TextStyle(
                  color: AppColors.texto, fontWeight: FontWeight.w800),
            ),
            if (_pedido.productos.isEmpty)
              const Text(
                'Sin productos',
                style: TextStyle(color: AppColors.textoSuave),
              ),
            for (final producto in _pedido.productos)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${producto.nombre} x${producto.cantidad} · ${formatearMoneda(producto.precio, _codigoMoneda)} c/u · ${formatearMoneda(producto.subtotal, _codigoMoneda)}',
                  style: const TextStyle(color: AppColors.texto),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Historial',
              style: TextStyle(
                  color: AppColors.texto, fontWeight: FontWeight.w800),
            ),
            if (_pedido.historial.isEmpty)
              const Text(
                'Sin cambios de estado.',
                style: TextStyle(color: AppColors.textoSuave),
              ),
            for (final cambio in _pedido.historial)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_fechaHora(cambio.fecha)}: ${PedidoEstados.etiqueta(cambio.anterior)} → ${PedidoEstados.etiqueta(cambio.nuevo)}',
                  style: const TextStyle(color: AppColors.textoSuave),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

final ButtonStyle _botonEstadio = ElevatedButton.styleFrom(
  backgroundColor: AppColors.primario,
  foregroundColor: Colors.white,
  elevation: 0,
  shape: const StadiumBorder(),
  textStyle: const TextStyle(fontWeight: FontWeight.w700),
);

Future<bool> _preguntarCancelar(BuildContext context) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(
        'Cancelar pedido',
        style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w800),
      ),
      content: const Text(
        '¿Cancelás este pedido? Queda marcado como cancelado y el historial se conserva.',
        style: TextStyle(color: AppColors.texto),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Volver'),
        ),
        ElevatedButton(
          style: _botonEstadio,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Sí, cancelar'),
        ),
      ],
    ),
  );
  return resultado == true;
}

double? _parseMonto(String raw) => leerMontoEscrito(raw);

String _etiquetaTarjeta(String raw) {
  if (PedidoEstados.leer(raw) == PedidoEstado.confirmado) return 'En proceso';
  return PedidoEstados.etiqueta(raw);
}

String _fechaLista(DateTime fecha) {
  const meses = [
    'ene.',
    'feb.',
    'mar.',
    'abr.',
    'may.',
    'jun.',
    'jul.',
    'ago.',
    'sep.',
    'oct.',
    'nov.',
    'dic.',
  ];
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  final resto = '${fecha.day} de ${meses[fecha.month - 1]} ${fecha.year}';
  if (dia == hoy) return 'Hoy, $resto';
  if (dia == hoy.subtract(const Duration(days: 1))) return 'Ayer, $resto';
  return resto;
}

String _fechaCorta(DateTime fecha) =>
    '${fecha.day}/${fecha.month}/${fecha.year}';

String _fechaHora(DateTime fecha) {
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '${_fechaCorta(fecha)} $hora:$minuto';
}

String _nombreConDetalle(String nombre, LineaMeta linea) {
  final extras = <String>[
    if (linea.variante.isNotEmpty) linea.variante,
    if (linea.unidad.isNotEmpty) linea.unidad,
  ];
  if (extras.isEmpty) return nombre;
  return '$nombre · ${extras.join(' · ')}';
}

String _etiquetaDescuento(_PedidoVista pedido, String codigo) {
  if (pedido.descuentoTipo == 'porcentaje' && pedido.descuentoValor > 0) {
    final pct = pedido.descuentoValor;
    final texto = pct == pct.roundToDouble()
        ? pct.toStringAsFixed(0)
        : pct.toStringAsFixed(2);
    return 'Descuento $texto% (${formatearMoneda(pedido.descuentoMonto, codigo)})';
  }
  return 'Descuento ${formatearMoneda(pedido.descuentoMonto, codigo)}';
}

String _mensajeDe(Object error) {
  if (error is StateError && error.message.isNotEmpty) return error.message;
  if (error is ArgumentError) {
    final mensaje = error.message;
    if (mensaje is String && mensaje.isNotEmpty) return mensaje;
  }
  return 'No se pudo completar la acción.';
}

