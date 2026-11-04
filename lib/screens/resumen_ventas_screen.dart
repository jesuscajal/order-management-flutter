import 'package:flutter/material.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/resumen_ventas.dart';
import '../models/pedido_estado.dart';
import '../services/negocio_local.dart';
import '../services/sesion_google.dart';
import '../theme/app_theme.dart';

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
      final email = sesion?.email ?? '';
      final admin = negocio == null || _administraVentas(negocio, email);
      final datos = await ResumenVentasConsulta(db).cargar(
        limiteUltimas: 30,
        soloAutor: admin ? null : email,
      );
      if (!mounted) return;
      setState(() {
        _datos = datos;
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
            const SizedBox(height: 10),
            _tarjetaPeriodo(
              titulo: 'Hoy',
              periodo: _datos.hoy,
            ),
            const SizedBox(height: 10),
            _tarjetaPeriodo(
              titulo: 'Últimos 7 días',
              periodo: _datos.ultimos7Dias,
            ),
            const SizedBox(height: 10),
            _tarjetaPeriodo(
              titulo: 'Mes en curso',
              periodo: _datos.mesActual,
            ),
            const SizedBox(height: 24),
            _tituloSeccion('Más vendidos este mes'),
            const SizedBox(height: 10),
            _tarjetaTopProductos(_datos.topProductosMes),
            const SizedBox(height: 24),
            _tituloSeccion('Últimas ventas'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filtroEstado == null,
                  onSelected: (_) => setState(() => _filtroEstado = null),
                ),
                for (final estado in const [
                  PedidoEstado.pendiente,
                  PedidoEstado.pendienteDePago,
                  PedidoEstado.pagado,
                  PedidoEstado.confirmado,
                  PedidoEstado.entregado,
                ])
                  ChoiceChip(
                    label: Text(estado.etiqueta),
                    selected: _filtroEstado == estado,
                    onSelected: (_) => setState(() => _filtroEstado = estado),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Producto o cliente',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (valor) => setState(() => _filtroProducto = valor),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todos los medios'),
                  selected: _filtroMedio.isEmpty,
                  onSelected: (_) => setState(() => _filtroMedio = ''),
                ),
                for (final medio in MetaPedido.medios)
                  ChoiceChip(
                    label: Text(MetaPedido.etiquetaMedio(medio)),
                    selected: _filtroMedio == medio,
                    onSelected: (_) => setState(() => _filtroMedio = medio),
                  ),
                ChoiceChip(
                  label: const Text('Fiado'),
                  selected: _filtroMedio == 'fiado',
                  onSelected: (_) => setState(() => _filtroMedio = 'fiado'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final origen in const ['', 'venta', 'local', 'tienda', 'asistente'])
                  ChoiceChip(
                    label: Text(_etiquetaOrigen(origen)),
                    selected: _filtroOrigen == origen,
                    onSelected: (_) => setState(() => _filtroOrigen = origen),
                  ),
              ],
            ),
            if (_soloAutor != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Ves las ventas que registraste con tu usuario.',
                style: TextStyle(color: AppColors.textoSuave),
              ),
            ],
            const SizedBox(height: 10),
            _tarjetaUltimas(_ventasFiltradas),
          ],
        ],
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.texto,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    );
  }

  Widget _tarjetaPeriodo({
    required String titulo,
    required TotalesPeriodo periodo,
  }) {
    final pedidos = periodo.cantidadPedidos;
    final etiquetaPedidos =
        pedidos == 1 ? '1 pedido' : '$pedidos pedidos';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppColors.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _usd(periodo.monto),
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            etiquetaPedidos,
            style: const TextStyle(color: AppColors.textoSuave),
          ),
          const SizedBox(height: 4),
          Text(
            'Ganancia ${_usd(periodo.ganancia)}',
            style: const TextStyle(
              color: AppColors.primario,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaTopProductos(List<ProductoMasVendido> productos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: AppColors.tarjeta,
      child: productos.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Todavía no hay unidades vendidas este mes.',
                style: TextStyle(color: AppColors.textoSuave),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < productos.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: AppColors.linea),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            AppColors.primario.withValues(alpha: 0.12),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: AppColors.primario,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          productos[i].nombre,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${productos[i].unidades} u.',
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _tarjetaUltimas(List<VentaReciente> ventas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: AppColors.tarjeta,
      child: ventas.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Todavía no hay ventas para mostrar.',
                style: TextStyle(color: AppColors.textoSuave),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < ventas.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: AppColors.linea),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ventas[i].clienteNombre,
                              style: const TextStyle(
                                color: AppColors.texto,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fechaCorta(ventas[i].fecha),
                              style: const TextStyle(
                                color: AppColors.textoSuave,
                              ),
                            ),
                            if (ventas[i].origen.isNotEmpty ||
                                ventas[i].productos.isNotEmpty)
                              Text(
                                [
                                  if (ventas[i].origen.isNotEmpty)
                                    _etiquetaOrigen(ventas[i].origen),
                                  if (ventas[i].productos.isNotEmpty)
                                    ventas[i].productos,
                                ].join(' · '),
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              _usd(ventas[i].montoTotal),
                              style: const TextStyle(
                                color: AppColors.textoSuave,
                                fontSize: 12,
                              ),
                            ),
                            if (ventas[i].medioPago.isNotEmpty ||
                                ventas[i].fiado ||
                                ventas[i].ganancia != null)
                              Text(
                                [
                                  if (ventas[i].medioPago.isNotEmpty)
                                    MetaPedido.etiquetaMedio(ventas[i].medioPago),
                                  if (ventas[i].fiado) 'Fiado',
                                  if (ventas[i].ganancia != null)
                                    'Ganancia ${_usd(ventas[i].ganancia!)}',
                                ].join(' · '),
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _chipEstado(ventas[i].estado),
                    ],
                  ),
                ],
              ],
            ),
    );
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

String _usd(double valor) => 'USD ${valor.toStringAsFixed(2)}';
