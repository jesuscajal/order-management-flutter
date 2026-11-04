import 'package:flutter/material.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/capital_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

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

  @override
  void initState() {
    super.initState();
    _contado.addListener(_alEscribirContado);
    if (widget.database != null) {
      _cargando = true;
      _cargar();
    }
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
          'Se anota $verbo de ${CapitalRepository.textoMonto(ajuste.monto)} con la descripción "${TotalesCierreCaja.descripcionAjuste}". No se borra ningún movimiento.\n\n$aviso',
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
              'Cierre de caja: ${TiposCapital.etiqueta(ajuste.tipo)} ${CapitalRepository.textoMonto(ajuste.monto)}',
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

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text('Cierre de caja')),
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
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(
                      'Hoy, ${_fecha(DateTime.now())}. Es una consulta: no borra movimientos.',
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_cargando && _movimientos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      if (_error != null) ...[
                        Text(_error!,
                            style: const TextStyle(color: AppColors.alerta)),
                        const SizedBox(height: 12),
                      ],
                      _Tarjeta(
                        titulo: 'Totales de hoy',
                        child: Column(
                          children: [
                            _Linea('Entradas', totales.entradas),
                            _Linea('Salidas', totales.salidas),
                            _Linea('Cobros', totales.cobros),
                            _Linea('A cobrar', totales.aCobrar),
                            _Linea('A pagar', totales.aPagar),
                            const SizedBox(height: 8),
                            const Text(
                              'Entradas: tipo entrada, aporte y venta cobrada. Salidas: salida, retiro, gasto y pago de deuda. Cobros: cobros y devoluciones. A cobrar y a pagar son lo cargado hoy, no el saldo de siempre.',
                              style: TextStyle(
                                color: AppColors.textoSuave,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Tarjeta(
                        titulo: 'Efectivo',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Linea('Entradas en efectivo',
                                totales.entradasEfectivo),
                            _Linea('Entradas por transferencia',
                                totales.ingresosTransferencia),
                            _Linea('Entradas por otro medio',
                                totales.ingresosOtro),
                            _Linea(
                                'Salidas en efectivo', totales.salidasEfectivo),
                            const SizedBox(height: 8),
                            const Text(
                              'La diferencia compara el efectivo contado con las entradas en efectivo. No resta las salidas. Cuenta como efectivo lo que empieza con Efectivo y lo que no dice Transferencia ni Otro. Incluye entradas, aportes, ventas cobradas y cobros en efectivo.',
                              style: TextStyle(
                                color: AppColors.textoSuave,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
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
                            if (invalido) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Ingresá un monto válido, cero o mayor.',
                                style: TextStyle(color: AppColors.alerta),
                              ),
                            ],
                            if (diferencia != null) ...[
                              const SizedBox(height: 12),
                              _Linea(
                                'Diferencia',
                                diferencia / 100,
                                color: diferencia == 0
                                    ? AppColors.texto
                                    : diferencia > 0
                                        ? AppColors.verde
                                        : AppColors.alerta,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                diferencia == 0
                                    ? 'Coincide con las entradas en efectivo.'
                                    : diferencia > 0
                                        ? 'Sobra respecto de las entradas en efectivo.'
                                        : 'Falta respecto de las entradas en efectivo.',
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (ajuste != null) ...[
                              const SizedBox(height: 16),
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
                      const SizedBox(height: 12),
                      _Tarjeta(
                        titulo: 'Movimientos de hoy',
                        child: deHoy.isEmpty
                            ? const Text(
                                'Hoy no hay movimientos de capital.',
                                style: TextStyle(color: AppColors.textoSuave),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < deHoy.length; i++) ...[
                                    if (i > 0) const Divider(height: 16),
                                    _MovimientoTile(movimiento: deHoy[i]),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              ),
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

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.etiqueta, this.valor, {this.color});

  final String etiqueta;
  final double valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          const SizedBox(width: 12),
          Text(
            CapitalRepository.textoMonto(valor),
            style: color == null ? estilo : estilo?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.movimiento});

  final MovimientoCapitalRegistro movimiento;

  @override
  Widget build(BuildContext context) {
    final efectivo =
        TotalesCierreCaja.descripcionEsEfectivo(movimiento.descripcion);
    final nota = movimiento.descripcion?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                TiposCapital.etiqueta(movimiento.tipo),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              CapitalRepository.textoMonto(movimiento.monto),
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          (nota == null || nota.isEmpty)
              ? movimiento.persona
              : '$nota · ${movimiento.persona}',
          style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
        ),
        Text(
          efectivo ? 'Efectivo' : 'No es efectivo',
          style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
        ),
      ],
    );
  }
}
