import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/capital_repository.dart';
import '../data/cobro_local.dart';
import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../models/movimiento_capital.dart';

/// Seguimiento de deudas por persona (RF-020 y RF-022).
///
/// [database] es opcional para que `const DeudoresScreen()` siga compilando.
/// Si es null, se usan los ejemplos en memoria. Para persistir, main tiene
/// que construir `DeudoresScreen(database: database)` con la misma base que
/// la pantalla de capital.
class DeudoresScreen extends StatefulWidget {
  const DeudoresScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<DeudoresScreen> createState() => _DeudoresScreenState();
}

class _DeudoresScreenState extends State<DeudoresScreen> {
  List<MovimientoCapital> _movimientos = [];
  Map<String, DatoCobro> _cobros = {};
  bool _soloVencidos = false;
  bool _cargando = false;
  String? _avisandoClave;

  @override
  void initState() {
    super.initState();
    if (widget.database == null) {
      _movimientos = [
        MovimientoCapital.crear(
          persona: 'Juan Pérez',
          monto: 1000,
          tipo: TipoMovimiento.prestamo,
          descripcion: 'Préstamo inicial',
        ),
        MovimientoCapital.crear(
          persona: 'Juan Pérez',
          monto: 500,
          tipo: TipoMovimiento.devolucion,
          descripcion: 'Primera devolución',
        ),
        MovimientoCapital.crear(
          persona: 'María García',
          monto: 2000,
          tipo: TipoMovimiento.prestamo,
          descripcion: 'Préstamo para negocio',
        ),
      ];
    } else {
      _cargando = true;
      _cargar();
    }
    _cargarCobros();
  }

  @override
  void didUpdateWidget(covariant DeudoresScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database && widget.database != null) {
      _cargar(mostrarCarga: true);
    }
  }

  Future<void> _cargar({bool mostrarCarga = false}) async {
    final db = widget.database;
    if (db == null) return;
    if (mostrarCarga) {
      setState(() => _cargando = true);
    }
    try {
      final filas = await CapitalRepository(db).listar();
      if (!mounted) return;
      setState(() {
        _movimientos = [for (final fila in filas) _desdeFila(fila)];
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron leer las deudas.'),
        ),
      );
    }
  }

  Future<void> _cargarCobros() async {
    try {
      final mapa = await const CobroLocal().cargar();
      if (!mounted) return;
      setState(() => _cobros = mapa);
    } catch (_) {
      // Sin preferencias, la deuda se ve igual y el aviso pide el teléfono.
    }
  }

  DatoCobro _dato(ResumenFinancieroPersona deudor) {
    return _cobros[CobroLocal.clavePersona(deudor.persona)] ?? const DatoCobro();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String _fechaTexto(DateTime fecha) {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }

  String _textoAviso({
    required String persona,
    required String negocio,
    required double saldo,
    DateTime? dia,
    int? pedido,
  }) {
    final partes = <String>[
      'Hola $persona.',
      if (negocio.trim().isNotEmpty) 'Te escribe ${negocio.trim()}.',
      'Tu saldo es ${_dinero(saldo)}.',
      if (pedido != null) 'Corresponde al pedido #$pedido.',
      if (dia != null) 'El día de cobro es el ${_fechaTexto(dia)}.',
    ];
    return partes.join(' ');
  }

  Future<DatoCobro?> _persistirCobro(
    ResumenFinancieroPersona deudor, {
    DateTime? fecha,
    String? telefono,
    bool quitarFecha = false,
  }) async {
    try {
      final guardado = await const CobroLocal().guardar(
        persona: deudor.persona,
        fecha: fecha,
        telefono: telefono,
        quitarFecha: quitarFecha,
      );
      if (!mounted) return guardado;
      final clave = CobroLocal.clavePersona(deudor.persona);
      setState(() {
        final copia = Map<String, DatoCobro>.of(_cobros);
        if (guardado.vacio) {
          copia.remove(clave);
        } else {
          copia[clave] = guardado;
        }
        _cobros = copia;
      });
      return guardado;
    } catch (_) {
      if (mounted) _aviso('No se pudo guardar.');
      return null;
    }
  }

  Future<String?> _pedirTelefono(String actual) {
    final campo = TextEditingController(text: actual);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Teléfono'),
        content: TextField(
          controller: campo,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono de WhatsApp',
            hintText: 'Ejemplo: 5491112345678',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, campo.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).whenComplete(campo.dispose);
  }

  Future<void> _elegirDia(ResumenFinancieroPersona deudor) async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year - 1, hoy.month, hoy.day);
    final fin = DateTime(hoy.year + 3, hoy.month, hoy.day);
    var inicial = _dato(deudor).fecha ?? hoy;
    inicial = DateTime(inicial.year, inicial.month, inicial.day);
    if (inicial.isBefore(inicio)) inicial = inicio;
    if (inicial.isAfter(fin)) inicial = fin;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: inicio,
      lastDate: fin,
      helpText: 'Día de cobro',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (elegida == null || !mounted) return;
    await _persistirCobro(
      deudor,
      fecha: DateTime(elegida.year, elegida.month, elegida.day),
    );
  }

  Future<void> _quitarDia(ResumenFinancieroPersona deudor) async {
    await _persistirCobro(deudor, quitarFecha: true);
  }

  Future<void> _editarTelefono(ResumenFinancieroPersona deudor) async {
    final pedido = await _pedirTelefono(_dato(deudor).telefono);
    if (pedido == null || !mounted) return;
    if (pedido.isNotEmpty && _soloDigitos(pedido).isEmpty) {
      _aviso('El teléfono tiene que tener números.');
      return;
    }
    await _persistirCobro(deudor, telefono: pedido);
  }

  String _soloDigitos(String telefono) => telefono.replaceAll(RegExp(r'\D'), '');

  Future<bool> _abrirWhatsApp(Uri enlace) async {
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

  Future<void> _avisarWhatsApp(ResumenFinancieroPersona deudor) async {
    if (_avisandoClave != null) return;
    final clave = CobroLocal.clavePersona(deudor.persona);
    setState(() => _avisandoClave = clave);
    try {
      var dato = _dato(deudor);
      if (_soloDigitos(dato.telefono).isEmpty) {
        final pedido = await _pedirTelefono(dato.telefono);
        if (pedido == null || !mounted) return;
        if (_soloDigitos(pedido).isEmpty) {
          _aviso('Para avisar por WhatsApp hace falta un teléfono.');
          return;
        }
        final guardado = await _persistirCobro(deudor, telefono: pedido);
        if (guardado == null || !mounted) return;
        dato = guardado;
      }
      final digitos = _soloDigitos(dato.telefono);
      if (digitos.isEmpty) {
        _aviso('Para avisar por WhatsApp hace falta un teléfono.');
        return;
      }
      var negocio = '';
      try {
        negocio = (await NegocioStore().leer())?.nombre.trim() ?? '';
      } catch (_) {}
      if (!mounted) return;
      final enlace = Uri(
        scheme: 'https',
        host: 'wa.me',
        path: '/$digitos',
        queryParameters: {
          'text': _textoAviso(
            persona: deudor.persona,
            negocio: negocio,
            saldo: deudor.saldoDeuda,
            dia: dato.fecha,
            pedido: _pedidoDe(deudor.persona),
          ),
        },
      );
      final abierto = await _abrirWhatsApp(enlace);
      if (!mounted) return;
      if (!abierto) _aviso('No se pudo abrir WhatsApp.');
    } finally {
      if (mounted) setState(() => _avisandoClave = null);
    }
  }

  MovimientoCapital _desdeFila(MovimientoCapitalRegistro fila) {
    final descripcion = fila.descripcion?.trim();
    return MovimientoCapital(
      id: fila.id.toString(),
      persona: fila.persona,
      monto: fila.monto.abs(),
      fecha: fila.fecha,
      tipo: _tipoModelo(fila.tipo),
      descripcion: (descripcion == null || descripcion.isEmpty)
          ? TiposCapital.etiqueta(fila.tipo)
          : descripcion,
      tipoGuardado: fila.tipo,
    );
  }

  TipoMovimiento _tipoModelo(String tipo) {
    switch (TiposCapital.normalizar(tipo)) {
      case TiposCapital.salida:
        return TipoMovimiento.egreso;
      case TiposCapital.entrada:
        return TipoMovimiento.ingreso;
      case TiposCapital.devolucion:
        return TipoMovimiento.devolucion;
      case TiposCapital.capitalACobrar:
        return TipoMovimiento.prestamo;
      default:
        return TipoMovimiento.ingreso;
    }
  }

  String _tipoTexto(TipoMovimiento tipo) {
    switch (tipo) {
      case TipoMovimiento.ingreso:
        return TiposCapital.entrada;
      case TipoMovimiento.egreso:
        return TiposCapital.salida;
      case TipoMovimiento.prestamo:
        return TiposCapital.capitalACobrar;
      case TipoMovimiento.devolucion:
        return TiposCapital.devolucion;
    }
  }

  List<ResumenFinancieroPersona> get _resumenFinanciero {
    return CapitalRepository.resumir([
      for (final movimiento in _movimientos)
        MovimientoParaResumen(
          persona: movimiento.persona,
          monto: movimiento.monto,
          tipo: movimiento.tipoGuardado.isEmpty
              ? _tipoTexto(movimiento.tipo)
              : movimiento.tipoGuardado,
        ),
    ]);
  }

  List<ResumenFinancieroPersona> get _deudoresConSaldo {
    return [
      for (final persona in _resumenFinanciero)
        if (CapitalRepository.enCentavos(persona.saldoDeuda) > 0 ||
            CapitalRepository.enCentavos(persona.saldoAPagar) > 0)
          persona,
    ];
  }

  double get _totalGlobalAdeudado {
    return _deudoresConSaldo.fold(0, (suma, persona) => suma + persona.saldoDeuda);
  }

  int? _pedidoDe(String persona) {
    final detalle = _ultimoDetalle(persona) ?? '';
    final match = RegExp(r'pedido #(\d+)', caseSensitive: false).firstMatch(detalle);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  bool _estaVencido(ResumenFinancieroPersona persona) {
    if (CapitalRepository.enCentavos(persona.saldoDeuda) <= 0) return false;
    final fecha = _dato(persona).fecha;
    if (fecha == null) return false;
    final hoy = DateTime.now();
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final limite = DateTime(hoy.year, hoy.month, hoy.day);
    return dia.isBefore(limite);
  }

  String? _ultimoDetalle(String persona) {
    final clave = persona.trim().toLowerCase();
    MovimientoCapital? ultimo;
    for (final movimiento in _movimientos) {
      if (movimiento.persona.trim().toLowerCase() != clave) continue;
      if (ultimo == null || movimiento.fecha.isAfter(ultimo.fecha)) {
        ultimo = movimiento;
      }
    }
    return ultimo?.descripcion;
  }

  String _dinero(double valor) {
    final absoluto = valor.abs().toStringAsFixed(2);
    if (valor < 0) return '-\$$absoluto';
    return '\$$absoluto';
  }

  Future<void> _registrarPago({
    required String persona,
    required double monto,
    required String descripcion,
    required ResultadoPagoParcial previsto,
  }) async {
    final db = widget.database;
    if (db == null) {
      setState(() {
        _movimientos.add(
          MovimientoCapital.crear(
            persona: persona,
            monto: previsto.pago,
            tipo: TipoMovimiento.devolucion,
            descripcion: descripcion,
          ),
        );
      });
      await _mostrarResultadoPago(previsto);
      return;
    }
    try {
      final resultado = await CapitalRepository(db).registrarPagoParcial(
        persona: persona,
        monto: monto,
        descripcion: descripcion,
      );
      if (!mounted) return;
      await _cargar();
      if (!mounted) return;
      await _mostrarResultadoPago(resultado);
    } on PagoParcialInvalido catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo registrar el pago.'),
        ),
      );
    }
  }

  Future<void> _mostrarResultadoPago(ResultadoPagoParcial resultado) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Pago registrado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lineaDialogo('Saldo anterior', _dinero(resultado.saldoAnterior)),
            _lineaDialogo('Pago', _dinero(resultado.pago)),
            _lineaDialogo('Saldo nuevo', _dinero(resultado.saldoNuevo)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoPago(ResumenFinancieroPersona deudor) {
    final controllerMonto = TextEditingController();
    final controllerDescripcion = TextEditingController();
    final saldo = deudor.saldoDeuda;
    String? error;
    ResultadoPagoParcial? vista;
    var yaIntento = false;

    void recalcular(StateSetter setLocal, {required bool mostrarError}) {
      try {
        final monto = CapitalRepository.leerMontoPago(controllerMonto.text);
        final resultado = CapitalRepository.calcularPagoParcial(
          saldo: saldo,
          monto: monto,
        );
        setLocal(() {
          vista = resultado;
          error = null;
        });
      } on PagoParcialInvalido catch (fallo) {
        setLocal(() {
          vista = null;
          error = mostrarError ? fallo.mensaje : null;
        });
      }
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final preview = vista;
            final mensaje = error;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Pago parcial'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deudor.persona,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Podés pagar una parte o todo el saldo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    _lineaDialogo(
                      'Saldo anterior',
                      _dinero(preview?.saldoAnterior ?? saldo),
                    ),
                    _lineaDialogo(
                      'Pago',
                      preview == null ? '—' : _dinero(preview.pago),
                    ),
                    _lineaDialogo(
                      'Saldo nuevo',
                      preview == null ? '—' : _dinero(preview.saldoNuevo),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controllerMonto,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Monto del pago',
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => recalcular(
                        setLocal,
                        mostrarError: yaIntento,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controllerDescripcion,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                      ),
                      maxLines: 2,
                    ),
                    if (mensaje != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        mensaje,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.red,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    yaIntento = true;
                    final ResultadoPagoParcial resultado;
                    try {
                      final monto = CapitalRepository.leerMontoPago(
                        controllerMonto.text,
                      );
                      resultado = CapitalRepository.calcularPagoParcial(
                        saldo: saldo,
                        monto: monto,
                      );
                    } on PagoParcialInvalido catch (fallo) {
                      setLocal(() {
                        vista = null;
                        error = fallo.mensaje;
                      });
                      return;
                    }
                    final descripcion =
                        controllerDescripcion.text.trim().isEmpty
                            ? 'Pago parcial'
                            : controllerDescripcion.text.trim();
                    Navigator.pop(dialogContext);
                    _registrarPago(
                      persona: deudor.persona,
                      monto: resultado.pago,
                      descripcion: descripcion,
                      previsto: resultado,
                    );
                  },
                  child: const Text('Registrar pago'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      controllerMonto.dispose();
      controllerDescripcion.dispose();
    });
  }

  Widget _lineaDialogo(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineaResumen(String etiqueta, String valor, {Color? color}) {
    final estilo = Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: color == null ? estilo : estilo?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaTotal() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: AppColors.tarjeta,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: Theme.of(context).iconTheme.color,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Adeudado',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _dinero(_totalGlobalAdeudado),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumen() {
    final resumen = _resumenFinanciero;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen financiero',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (resumen.isEmpty)
            Text(
              'Sin movimientos',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (var i = 0; i < resumen.length; i++) ...[
              if (i > 0) const Divider(),
              Text(
                resumen[i].persona,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              _lineaResumen(
                'Entradas',
                _dinero(resumen[i].totalEntradas),
              ),
              _lineaResumen(
                'Salidas',
                _dinero(resumen[i].totalSalidas),
              ),
              _lineaResumen(
                'Pagos / devoluciones',
                _dinero(resumen[i].totalPagos),
              ),
              _lineaResumen(
                'Saldo de deuda',
                _dinero(resumen[i].saldoDeuda),
                color: resumen[i].saldoDeuda > 0 ? Colors.red : null,
              ),
            ],
        ],
      ),
    );
  }

  Widget _tarjetaDeudor(ResumenFinancieroPersona deudor) {
    final detalle = _ultimoDetalle(deudor.persona);
    final cobra = CapitalRepository.enCentavos(deudor.saldoDeuda) > 0;
    final dato = _dato(deudor);
    final clave = CobroLocal.clavePersona(deudor.persona);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    deudor.persona,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _dinero(deudor.saldoDeuda),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.red,
                          ),
                    ),
                    if (CapitalRepository.enCentavos(deudor.saldoAPagar) > 0)
                      Text(
                        'A pagar ${_dinero(deudor.saldoAPagar)}',
                        style: const TextStyle(color: AppColors.alerta),
                      ),
                  ],
                ),
              ],
            ),
            if (detalle != null) ...[
              const SizedBox(height: 8),
              Text(
                'Último movimiento: $detalle',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _mostrarDialogoPago(deudor),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Pago parcial'),
              ),
            ),
            if (cobra) ...[
              const SizedBox(height: 12),
              if (_estaVencido(deudor))
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Vencido',
                    style: TextStyle(
                      color: AppColors.alerta,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Text(
                dato.fecha == null
                    ? 'Sin día de cobro'
                    : 'Día de cobro: ${_fechaTexto(dato.fecha!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (dato.telefono.isNotEmpty)
                Text(
                  'Teléfono: ${dato.telefono}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (dato.fecha != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _quitarDia(deudor),
                    child: const Text('Quitar día'),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _elegirDia(deudor),
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    dato.fecha == null ? 'Día de cobro' : 'Cambiar día',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _editarTelefono(deudor),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: Text(
                    dato.telefono.isEmpty ? 'Teléfono' : 'Cambiar teléfono',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _avisandoClave == clave
                      ? null
                      : () => _avisarWhatsApp(deudor),
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                  label: const Text('Avisar por WhatsApp'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deudores = [
      for (final deudor in _deudoresConSaldo)
        if (!_soloVencidos || _estaVencido(deudor)) deudor,
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Deudores',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _tarjetaTotal(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Solo vencidos'),
                      selected: _soloVencidos,
                      onSelected: (valor) => setState(() => _soloVencidos = valor),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _tarjetaResumen(),
                      if (deudores.isEmpty)
                        Text(
                          _soloVencidos
                              ? 'No hay deudas vencidas'
                              : 'No hay deudas pendientes',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        for (final deudor in deudores) _tarjetaDeudor(deudor),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
