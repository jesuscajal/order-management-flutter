import 'package:flutter/material.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/resumen_ventas.dart';
import '../models/pedido_estado.dart';
import '../services/negocio_local.dart';
import '../services/sesion_google.dart';
import '../theme/app_theme.dart';
import '../utils/moneda.dart';

/// Resumen de ventas (RF 3.5).
///
/// [database] es opcional para que `const ResumenVentasScreen()` compile.
/// Sin base no inventamos cifras: mostramos un estado vacío honesto.
class ResumenVentasScreen extends StatefulWidget {
  const ResumenVentasScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<ResumenVentasScreen> createState() => _ResumenVentasScreenState();
}

class _ResumenVentasScreenState extends State<ResumenVentasScreen> {
  ResumenVentasDatos _datos = ResumenVentasDatos.vacio;
  bool _cargando = false;
  String? _error;
  PedidoEstado? _filtroEstado;
  String _filtroOrigen = '';
  String _filtroMedio = '';
  String _filtroProducto = '';
  String? _soloAutor;
  String _codigoMoneda = monedaPorDefecto;

  @override
  void initState() {
    super.initState();
    if (widget.database != null) {
      _cargando = true;
      _cargar();
    }
  }

  @override
  void didUpdateWidget(covariant ResumenVentasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database && widget.database != null) {
      _cargar(mostrarCarga: true);
    }
  }

  Future<void> _cargar({bool mostrarCarga = false}) async {
    final db = widget.database;
    if (db == null) return;
    if (mostrarCarga) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final sesion = await AuthGoogle.instancia.leer();
      final negocio = await NegocioStore().leer();
      final codigo = codigoMoneda(negocio?.moneda);
      final email = sesion?.email ?? '';
      final admin = negocio == null || _administraVentas(negocio, email);
      final datos = await ResumenVentasConsulta(db).cargar(
        limiteUltimas: 30,
        soloAutor: admin ? null : email,
      );
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _codigoMoneda = codigo;
        _soloAutor = admin ? null : email;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos leer el resumen de ventas.';
      });
    }
  }

  int get _filtrosActivos {
    var cantidad = 0;
    if (_filtroEstado != null) cantidad++;
    if (_filtroOrigen.isNotEmpty) cantidad++;
    if (_filtroMedio.isNotEmpty) cantidad++;
    if (_filtroProducto.trim().isNotEmpty) cantidad++;
    return cantidad;
  }

  Future<void> _abrirFiltros() async {
    final busqueda = TextEditingController(text: _filtroProducto);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.fondoClaro,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, actualizar) {
            void aplicar(VoidCallback cambio) {
              setState(cambio);
              actualizar(() {});
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrar ventas',
                      style: TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: busqueda,
                      decoration: const InputDecoration(
                        labelText: 'Producto o cliente',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (valor) =>
                          aplicar(() => _filtroProducto = valor),
                    ),
                    const SizedBox(height: 14),
                    _chips(
                      'Estado',
                      [
                        _opcion('Todas', _filtroEstado == null, () {
                          aplicar(() => _filtroEstado = null);
                        }),
                        for (final estado in const [
                          PedidoEstado.pendiente,
                          PedidoEstado.pendienteDePago,
                          PedidoEstado.pagado,
                          PedidoEstado.confirmado,
                          PedidoEstado.entregado,
                        ])
                          _opcion(estado.etiqueta, _filtroEstado == estado, () {
                            aplicar(() => _filtroEstado = estado);
                          }),
                      ],
                    ),
                    _chips(
                      'Medio',
                      [
                        _opcion('Todos', _filtroMedio.isEmpty, () {
                          aplicar(() => _filtroMedio = '');
                        }),
                        for (final medio in MetaPedido.medios)
                          _opcion(
                            MetaPedido.etiquetaMedio(medio),
                            _filtroMedio == medio,
                            () => aplicar(() => _filtroMedio = medio),
                          ),
                        _opcion('Fiado', _filtroMedio == 'fiado', () {
                          aplicar(() => _filtroMedio = 'fiado');
                        }),
                      ],
                    ),
                    _chips(
                      'Origen',
                      [
                        for (final origen in const [
                          '',
                          'venta',
                          'local',
                          'tienda',
                          'asistente',
                        ])
                          _opcion(
                            _etiquetaOrigen(origen),
                            _filtroOrigen == origen,
                            () => aplicar(() => _filtroOrigen = origen),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    busqueda.dispose();
  }

  Widget _chips(String titulo, List<Widget> opciones) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: opciones),
        ],
      ),
    );
  }

  Widget _opcion(String texto, bool elegido, VoidCallback alElegir) {
    return FilterChip(
      label: Text(texto),
      selected: elegido,
      showCheckmark: false,
      onSelected: (_) => alElegir(),
    );
  }

  List<VentaReciente> get _ventasFiltradas {
    final filtro = _filtroEstado;
    final producto = _filtroProducto.trim().toLowerCase();
    return [
      for (final venta in _datos.ultimasVentas)
        if ((filtro == null || PedidoEstados.leer(venta.estado) == filtro) &&
            (_filtroOrigen.isEmpty || venta.origen == _filtroOrigen) &&
            (_filtroMedio.isEmpty ||
                (_filtroMedio == 'fiado'
                    ? venta.fiado
                    : venta.medioPago == _filtroMedio)) &&
            (producto.isEmpty ||
                venta.productos.toLowerCase().contains(producto) ||
                venta.clienteNombre.toLowerCase().contains(producto)))
          venta,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ventas',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (widget.database != null)
            IconButton(
              tooltip: 'Filtrar',
              onPressed: _abrirFiltros,
              icon: Badge(
                isLabelVisible: _filtrosActivos > 0,
                label: Text('$_filtrosActivos'),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
        ],
      ),
      body: widget.database == null ? _sinBase() : _conBase(),
    );
  }

  Widget _sinBase() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: const [
        Text(
          'Todavía no hay base de datos conectada.\n'
          'Cuando Inicio pase la base, vas a ver acá tus totales y los productos más vendidos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textoSuave, height: 1.45),
        ),
      ],
    );
  }

  Widget _conBase() {
    return RefreshIndicator(
      color: AppColors.primario,
      onRefresh: () => _cargar(mostrarCarga: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.alerta),
              ),
            ),
          if (_cargando && _datos == ResumenVentasDatos.vacio)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _tituloSeccion('Totales'),
            _grupo([
              _filaPeriodo(
                icono: Icons.today_rounded,
                titulo: 'Hoy',
                periodo: _datos.hoy,
                color: AppColors.primario,
              ),
              _filaPeriodo(
                icono: Icons.date_range_rounded,
                titulo: 'Últimos 7 días',
                periodo: _datos.ultimos7Dias,
                color: AppColors.teal,
              ),
              _filaPeriodo(
                icono: Icons.calendar_month_rounded,
                titulo: 'Mes en curso',
                periodo: _datos.mesActual,
                color: AppColors.lima,
              ),
            ]),
            const SizedBox(height: 22),
            _tituloSeccion('Más vendidos este mes'),
            _grupo(_filasTop(_datos.topProductosMes)),
            const SizedBox(height: 22),
            _tituloSeccion('Últimas ventas'),
            if (_soloAutor != null)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Ves las ventas que registraste con tu usuario.',
                  style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
                ),
              ),
            _grupo(_filasVentas(_ventasFiltradas)),
          ],
        ],
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
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

  Widget _grupo(List<Widget> filas) {
    return DecoratedBox(
      decoration: AppColors.tarjeta,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, indent: 68, color: AppColors.linea),
              filas[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _filaPeriodo({
    required IconData icono,
    required String titulo,
    required TotalesPeriodo periodo,
    required Color color,
  }) {
    final pedidos = periodo.cantidadPedidos;
    final etiquetaPedidos = pedidos == 1 ? '1 pedido' : '$pedidos pedidos';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _marca(icono, color),
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
                  '$etiquetaPedidos · Ganancia ${formatearMoneda(periodo.ganancia, _codigoMoneda)}',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              formatearMoneda(periodo.monto, _codigoMoneda),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _marca(IconData icono, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icono, color: color, size: 20),
    );
  }

  List<Widget> _filasTop(List<ProductoMasVendido> productos) {
    if (productos.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            'Todavía no hay unidades vendidas este mes.',
            style: TextStyle(color: AppColors.textoSuave),
          ),
        ),
      ];
    }
    final maximo = productos.first.unidades;
    return [
      for (var i = 0; i < productos.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: i == 0
                    ? AppColors.lima.withValues(alpha: 0.18)
                    : AppColors.primario.withValues(alpha: 0.1),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: i == 0 ? AppColors.verde : AppColors.primario,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productos[i].nombre,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: maximo == 0 ? 0 : productos[i].unidades / maximo,
                        backgroundColor: AppColors.linea,
                        color: i == 0 ? AppColors.lima : AppColors.primario,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${productos[i].unidades} u.',
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _filasVentas(List<VentaReciente> ventas) {
    if (ventas.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            'Todavía no hay ventas para mostrar.',
            style: TextStyle(color: AppColors.textoSuave),
          ),
        ),
      ];
    }
    return [
      for (final venta in ventas)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venta.clienteNombre,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _fechaCorta(venta.fecha),
                        if (venta.origen.isNotEmpty)
                          _etiquetaOrigen(venta.origen),
                        if (venta.productos.isNotEmpty) venta.productos,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 13,
                      ),
                    ),
                    if (venta.medioPago.isNotEmpty ||
                        venta.fiado ||
                        venta.ganancia != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (venta.medioPago.isNotEmpty)
                            MetaPedido.etiquetaMedio(venta.medioPago),
                          if (venta.fiado) 'Fiado',
                          if (venta.ganancia != null)
                            'Ganancia ${formatearMoneda(venta.ganancia!, _codigoMoneda)}',
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatearMoneda(venta.montoTotal, _codigoMoneda),
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _chipEstado(venta.estado),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Widget _chipEstado(String estado) {
    final color = _colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        PedidoEstados.etiqueta(estado),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _etiquetaOrigen(String origen) {
  switch (origen) {
    case 'venta':
      return 'Venta directa';
    case 'local':
      return 'Pedido';
    case 'tienda':
      return 'Tienda';
    case 'asistente':
      return 'Asistente';
    default:
      return 'Todos los orígenes';
  }
}

bool _administraVentas(NegocioLocal negocio, String email) {
  final clave = email.trim().toLowerCase();
  if (clave.isNotEmpty && negocio.duenoEmail.trim().toLowerCase() == clave) {
    return true;
  }
  final miembro = negocio.miembroConEmail(email);
  return miembro != null && miembro.activo && miembro.rol == 'administrador';
}

Color _colorEstado(String raw) {
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

String _fechaCorta(DateTime fecha) {
  final local = fecha.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
