import 'package:flutter/material.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/capital_repository.dart';
import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../utils/moneda.dart';

/// Cierre del día: consulta el capital de hoy y lo compara con el efectivo contado.
///
/// No borra movimientos. El único asiento es el botón opcional, y solo si
/// la diferencia no es cero y la persona lo confirma.
class CierreCajaScreen extends StatefulWidget {
  const CierreCajaScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<CierreCajaScreen> createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  final _contado = TextEditingController();

  List<MovimientoCapitalRegistro> _movimientos = const [];
  bool _cargando = false;
  bool _guardando = false;
  String? _error;
  String _codigoMoneda = monedaPorDefecto;

  @override
  void initState() {
    super.initState();
    _leerMoneda();
    _contado.addListener(_alEscribirContado);
    if (widget.database != null) {
      _cargando = true;
      _cargar();
    }
  }

  Future<void> _leerMoneda() async {
    final codigo = await monedaDelNegocio();
    if (!mounted || codigo == _codigoMoneda) return;
    setState(() => _codigoMoneda = codigo);
  }

  void _alEscribirContado() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _contado.removeListener(_alEscribirContado);
    _contado.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final db = widget.database;
    if (db == null) return;
    try {
      final filas = await CapitalRepository(db).listar();
      if (!mounted) return;
      setState(() {
        _movimientos = filas;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron leer los movimientos de hoy.';
      });
    }
  }

  List<MovimientoCapitalRegistro> get _deHoy {
    final ahora = DateTime.now();
    return [
      for (final movimiento in _movimientos)
        if (TotalesCierreCaja.esMismoDia(movimiento.fecha, ahora)) movimiento,
    ];
  }

  TotalesCierreCaja get _totales => TotalesCierreCaja.de(_movimientos);

  Future<void> _anotar(AjusteCierreCaja ajuste) async {
    final db = widget.database;
    if (db == null || _guardando) return;
    final esEntrada = ajuste.tipo == TiposCapital.entrada;
    final verbo = esEntrada ? 'una entrada' : 'una salida';
    final aviso = esEntrada
        ? 'En el cálculo de hoy esa entrada suma al efectivo.'
        : 'Las entradas en efectivo no cambian, así que la diferencia se sigue viendo. El movimiento queda guardado.';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anotar diferencia'),
        content: Text(
          'Se anota $verbo de ${formatearMoneda(ajuste.monto, _codigoMoneda)} con la descripción "${TotalesCierreCaja.descripcionAjuste}". No se borra ningún movimiento.\n\n$aviso',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Anotar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      final contado = TotalesCierreCaja.leerContado(_contado.text);
      final frescos =
          TotalesCierreCaja.de(await CapitalRepository(db).listar());
      final vigente = contado == null ? null : frescos.ajustePara(contado);
      if (vigente == null ||
          vigente.tipo != ajuste.tipo ||
          CapitalRepository.enCentavos(vigente.monto) !=
              CapitalRepository.enCentavos(ajuste.monto)) {
        if (!mounted) return;
        setState(() => _guardando = false);
        await _cargar();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La diferencia cambió. Revisala antes de anotar.'),
          ),
        );
        return;
      }
      await CapitalRepository(db).registrar(
        persona: TotalesCierreCaja.personaAjuste,
        monto: ajuste.monto,
        tipo: ajuste.tipo,
        descripcion: TotalesCierreCaja.descripcionAjuste,
      );
      try {
        await const AmpliacionLocal().anotar(
          accion: 'alta',
          entidad: 'capital',
          detalle:
              'Cierre de caja: ${TiposCapital.etiqueta(ajuste.tipo)} ${formatearMoneda(ajuste.monto, _codigoMoneda)}',
        );
      } catch (_) {
        // El movimiento ya quedó en capital.
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo anotar la diferencia.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _guardando = false);
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Diferencia anotada. Los movimientos siguen.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totales = _totales;
    final deHoy = _deHoy;
    final contado = TotalesCierreCaja.leerContado(_contado.text);
    final invalido = TotalesCierreCaja.contadoInvalido(_contado.text);
    final diferencia =
        contado == null ? null : totales.diferenciaCentavos(contado);
    final ajuste = contado == null ? null : totales.ajustePara(contado);

    final avisoDiferencia = diferencia == null
        ? null
        : diferencia == 0
            ? 'Coincide con las entradas en efectivo.'
            : diferencia > 0
                ? 'Sobra respecto de las entradas en efectivo.'
                : 'Falta respecto de las entradas en efectivo.';
    final colorDiferencia = diferencia == null || diferencia == 0
        ? AppColors.texto
        : diferencia > 0
            ? AppColors.verde
            : AppColors.alerta;

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Cierre de caja',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: widget.database == null
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
          : RefreshIndicator(
              color: AppColors.primario,
              onRefresh: _cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text(
                      'Hoy, ${_fecha(DateTime.now())}. No borra movimientos.',
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_cargando && _movimientos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.alerta),
                        ),
                      ),
                    _titulo('Del día'),
                    _grupo([
                      _fila(
                        Icons.south_west_rounded,
                        AppColors.verde,
                        'Entradas',
                        totales.entradas,
                      ),
                      _fila(
                        Icons.north_east_rounded,
                        AppColors.alerta,
                        'Salidas',
                        totales.salidas,
                      ),
                      _fila(
                        Icons.payments_outlined,
                        AppColors.primario,
                        'Cobros',
                        totales.cobros,
                      ),
                      _fila(
                        Icons.schedule_rounded,
                        AppColors.pendiente,
                        'A cobrar',
                        totales.aCobrar,
                      ),
                      _fila(
                        Icons.account_balance_wallet_outlined,
                        AppColors.azulProfundo,
                        'A pagar',
                        totales.aPagar,
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _titulo('Efectivo'),
                    _grupo([
                      _fila(
                        Icons.payments_rounded,
                        AppColors.lima,
                        'Entradas en efectivo',
                        totales.entradasEfectivo,
                      ),
                      _fila(
                        Icons.account_balance_outlined,
                        AppColors.primario,
                        'Transferencia',
                        totales.ingresosTransferencia,
                      ),
                      _fila(
                        Icons.more_horiz_rounded,
                        AppColors.textoSuave,
                        'Otro medio',
                        totales.ingresosOtro,
                      ),
                      _fila(
                        Icons.north_east_rounded,
                        AppColors.alerta,
                        'Salidas en efectivo',
                        totales.salidasEfectivo,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: AppColors.tarjeta,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _contado,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Efectivo contado',
                                prefixIcon: Icon(Icons.payments_outlined),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Se compara con las entradas en efectivo. Las salidas no se restan.',
                              style: TextStyle(
                                color: AppColors.textoSuave,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            if (invalido) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Ingresá un monto válido, cero o mayor.',
                                style: TextStyle(color: AppColors.alerta),
                              ),
                            ],
                            if (diferencia != null && avisoDiferencia != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Diferencia',
                                      style: TextStyle(
                                        color: AppColors.texto,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatearMoneda(
                                      diferencia / 100,
                                      _codigoMoneda,
                                    ),
                                    style: TextStyle(
                                      color: colorDiferencia,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                avisoDiferencia,
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (ajuste != null) ...[
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed:
                                    _guardando ? null : () => _anotar(ajuste),
                                child: Text(
                                  _guardando
                                      ? 'Anotando...'
                                      : 'Anotar diferencia',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _titulo('Movimientos de hoy'),
                    _grupo(
                      deHoy.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                child: Text(
                                  'Hoy no hay movimientos de capital.',
                                  style: TextStyle(color: AppColors.textoSuave),
                                ),
                              ),
                            ]
                          : [
                              for (final movimiento in deHoy)
                                _MovimientoTile(
                                  movimiento: movimiento,
                                  moneda: _codigoMoneda,
                                ),
                            ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _titulo(String texto) {
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

  Widget _fila(IconData icono, Color color, String etiqueta, double valor) {
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
            child: Text(
              etiqueta,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              formatearMoneda(valor, _codigoMoneda),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fecha(DateTime fecha) {
    const meses = [
      '',
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
    return '${fecha.day} ${meses[fecha.month]} ${fecha.year}';
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.movimiento, required this.moneda});

  final MovimientoCapitalRegistro movimiento;
  final String moneda;

  @override
  Widget build(BuildContext context) {
    final efectivo =
        TotalesCierreCaja.descripcionEsEfectivo(movimiento.descripcion);
    final nota = movimiento.descripcion?.trim();
    final detalle = (nota == null || nota.isEmpty)
        ? movimiento.persona
        : '$nota · ${movimiento.persona}';
    final color = efectivo ? AppColors.lima : AppColors.primario;
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
            child: Icon(
              efectivo ? Icons.payments_rounded : Icons.swap_horiz_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TiposCapital.etiqueta(movimiento.tipo),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$detalle · ${efectivo ? 'Efectivo' : 'Otro medio'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatearMoneda(movimiento.monto, moneda),
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
