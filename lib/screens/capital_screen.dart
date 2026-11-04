import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/capital_repository.dart';
import '../theme/app_theme.dart';

/// Movimientos de capital (RF-019, RF-021 y RF-022).
///
/// [database] es opcional para que `const CapitalScreen()` siga compilando.
/// Si es null, la lista queda en memoria. Para persistir, main tiene que
/// construir `CapitalScreen(database: database)`.
class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _FilaMovimiento {
  const _FilaMovimiento({
    required this.fecha,
    required this.descripcion,
    required this.montoTexto,
    required this.montoColor,
    required this.tipo,
  });

  final String fecha;
  final String descripcion;
  final String montoTexto;
  final Color montoColor;
  final String tipo;
}

class _CapitalScreenState extends State<CapitalScreen> {
  final List<String> users = ['Kevin', 'Nildo'];

  List<Map<String, dynamic>> _movimientosMemoria = [];
  List<MovimientoCapitalRegistro> _movimientosDb = [];
  bool _cargando = false;
  String _periodo = 'todo';

  @override
  void initState() {
    super.initState();
    if (widget.database == null) {
      _movimientosMemoria = _ejemplos();
    } else {
      _cargando = true;
      _cargar();
    }
  }

  @override
  void didUpdateWidget(covariant CapitalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database && widget.database != null) {
      _cargar(mostrarCarga: true);
    }
  }

  List<Map<String, dynamic>> _ejemplos() {
    return [
      const {
        'fecha': '24 abr. 2024',
        'descripcion': 'Transferencia a Kevin',
        'monto': -100,
        'tipo': 'Salida',
        'persona': 'Kevin',
      },
      const {
        'fecha': '23 abr. 2024',
        'descripcion': 'Transferencia a Nildo',
        'monto': -50,
        'tipo': 'Salida',
        'persona': 'Nildo',
      },
      const {
        'fecha': '22 abr. 2024',
        'descripcion': 'Aporte de capital',
        'monto': 200,
        'tipo': 'Entrada',
        'persona': 'Kevin',
      },
      const {
        'fecha': '21 abr. 2024',
        'descripcion': 'Pago de TMA S.R.L.',
        'monto': 300,
        'tipo': 'Entrada',
        'persona': 'Nildo',
      },
    ];
  }

  Future<bool> _cargar({bool mostrarCarga = false}) async {
    final db = widget.database;
    if (db == null) return false;
    if (mostrarCarga) {
      setState(() => _cargando = true);
    }
    try {
      final filas = await CapitalRepository(db).listar();
      if (!mounted) return false;
      setState(() {
        _movimientosDb = filas;
        _cargando = false;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron leer los movimientos de capital.'),
        ),
      );
      return false;
    }
  }

  void _addMovimiento(Map<String, dynamic> mov) {
    setState(() {
      _movimientosMemoria.insert(0, mov);
    });
  }

  Future<void> _registrarEnBase({
    required String persona,
    required double monto,
    required String tipo,
    required String descripcion,
  }) async {
    final db = widget.database;
    if (db == null) return;
    try {
      await CapitalRepository(db).registrar(
        persona: persona,
        monto: monto,
        tipo: tipo,
        descripcion: descripcion,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el movimiento.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final actualizo = await _cargar();
    if (actualizo) _avisarGuardado(tipo);
  }

  void _avisarGuardado(String tipo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Listo: ${TiposCapital.etiqueta(tipo)}. El resumen se actualizó.',
        ),
      ),
    );
  }

  List<ResumenFinancieroPersona> get _resumen {
    if (widget.database == null) {
      return CapitalRepository.resumir([
        for (final mov in _movimientosMemoria)
          MovimientoParaResumen(
            persona: mov['persona'] as String,
            monto: (mov['monto'] as num).toDouble(),
            tipo: mov['tipo'] as String,
          ),
      ]);
    }
    return CapitalRepository.resumir([
      for (final mov in _movimientosDb)
        MovimientoParaResumen(
          persona: mov.persona,
          monto: mov.monto,
          tipo: mov.tipo,
        ),
    ]);
  }

  void _showAddMovimientoDialog() {
    final enBase = widget.database != null;
    var personaSeleccionada = users.first;
    var tipo = TiposCapital.entrada;
    var medio = 'Efectivo';
    var mostrarError = false;
    final personaController = TextEditingController();
    final descripcionController = TextEditingController();
    final montoController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Nuevo movimiento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (enBase)
                      TextField(
                        controller: personaController,
                        decoration: const InputDecoration(labelText: 'Persona'),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: personaSeleccionada,
                        isExpanded: true,
                        items: users
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (valor) {
                          if (valor == null) return;
                          setLocal(() => personaSeleccionada = valor);
                        },
                        decoration: const InputDecoration(labelText: 'Persona'),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      isExpanded: true,
                      items: TiposCapital.persistidos
                          .map(
                            (opcion) => DropdownMenuItem(
                              value: opcion,
                              child: Text(TiposCapital.etiqueta(opcion)),
                            ),
                          )
                          .toList(),
                      onChanged: (valor) {
                        if (valor == null) return;
                        setLocal(() => tipo = valor);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TiposCapital.ayuda(tipo),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: medio,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                        DropdownMenuItem(
                          value: 'Transferencia',
                          child: Text('Transferencia'),
                        ),
                        DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                      ],
                      onChanged: (valor) {
                        if (valor == null) return;
                        setLocal(() => medio = valor);
                      },
                      decoration: const InputDecoration(labelText: 'Medio'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descripcionController,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: montoController,
                      decoration:
                          const InputDecoration(labelText: 'Monto (USDT)'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    if (mostrarError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          enBase
                              ? 'Ingresá la persona y un monto mayor a cero.'
                              : 'Ingresá un monto mayor a cero.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.red,
                                  ),
                        ),
                      ),
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
                    final nota = descripcionController.text.trim();
                    final descripcion = nota.isEmpty ? medio : '$medio · $nota';
                    final monto = _parseMonto(montoController.text);
                    if (!enBase) {
                      if (monto == null || monto <= 0) {
                        setLocal(() => mostrarError = true);
                        return;
                      }
                      Navigator.pop(dialogContext);
                      _addMovimiento({
                        'fecha': _fechaTexto(DateTime.now()),
                        'descripcion': descripcion,
                        'monto': monto,
                        'tipo': tipo,
                        'persona': personaSeleccionada,
                      });
                      _avisarGuardado(tipo);
                      return;
                    }
                    final persona = personaController.text.trim();
                    if (persona.isEmpty || monto == null || monto <= 0) {
                      setLocal(() => mostrarError = true);
                      return;
                    }
                    Navigator.pop(dialogContext);
                    _registrarEnBase(
                      persona: persona,
                      monto: monto,
                      tipo: tipo,
                      descripcion: descripcion,
                    );
                  },
                  child: const Text('Añadir'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      personaController.dispose();
      descripcionController.dispose();
      montoController.dispose();
    });
  }

  double? _parseMonto(String raw) {
    final limpio = raw.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    return double.tryParse(limpio);
  }

  String _mes(int m) {
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
    return meses[m];
  }

  String _fechaTexto(DateTime fecha) {
    return '${fecha.day} ${_mes(fecha.month)} ${fecha.year}';
  }

  List<_FilaMovimiento> _filas() {
    if (widget.database == null) {
      return [
        for (final mov in _movimientosMemoria) _filaMemoria(mov),
      ];
    }
    return [
      for (final mov in _movimientosDb)
        if (_entra(mov.fecha)) _filaBase(mov),
    ];
  }

  bool _entra(DateTime fecha) {
    final ahora = DateTime.now();
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    switch (_periodo) {
      case 'hoy':
        return dia == hoy;
      case 'semana':
        return !dia.isBefore(hoy.subtract(const Duration(days: 6)));
      case 'mes':
        return fecha.year == ahora.year && fecha.month == ahora.month;
      default:
        return true;
    }
  }

  _FilaMovimiento _filaMemoria(Map<String, dynamic> mov) {
    final monto = (mov['monto'] as num).toDouble();
    final tipo = TiposCapital.normalizar(mov['tipo'] as String);
    final texto = '${CapitalRepository.textoMonto(monto.abs())} USDT';
    final String montoTexto;
    switch (tipo) {
      case TiposCapital.entrada:
      case TiposCapital.devolucion:
        montoTexto = '+$texto';
      case TiposCapital.salida:
        montoTexto = '-$texto';
      default:
        montoTexto = texto;
    }
    return _FilaMovimiento(
      fecha: mov['fecha'] as String,
      descripcion: mov['descripcion'] as String,
      montoTexto: montoTexto,
      montoColor: _colorMonto(tipo),
      tipo: TiposCapital.etiqueta(tipo),
    );
  }

  _FilaMovimiento _filaBase(MovimientoCapitalRegistro mov) {
    final tipo = TiposCapital.normalizar(mov.tipo);
    final texto = '${CapitalRepository.textoMonto(mov.monto.abs())} USDT';
    final String montoTexto;
    switch (tipo) {
      case TiposCapital.entrada:
      case TiposCapital.devolucion:
        montoTexto = '+$texto';
      case TiposCapital.salida:
        montoTexto = '-$texto';
      default:
        montoTexto = texto;
    }
    final descripcion = mov.descripcion?.trim();
    return _FilaMovimiento(
      fecha: _fechaTexto(mov.fecha),
      descripcion: (descripcion == null || descripcion.isEmpty)
          ? mov.persona
          : '$descripcion · ${mov.persona}',
      montoTexto: montoTexto,
      montoColor: _colorMonto(tipo),
      tipo: TiposCapital.etiqueta(mov.tipo),
    );
  }

  Color _colorMonto(String tipo) {
    switch (tipo) {
      case TiposCapital.salida:
      case TiposCapital.capitalACobrar:
        return Colors.red;
      case TiposCapital.entrada:
      case TiposCapital.devolucion:
        return Colors.green;
      default:
        return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    }
  }

  Widget _lineaResumen(String etiqueta, double valor, {Color? color}) {
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
              '${CapitalRepository.textoMonto(valor)} USDT',
              textAlign: TextAlign.end,
              style: color == null ? estilo : estilo?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloquePersona(ResumenFinancieroPersona resumen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resumen.persona,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        _lineaResumen('Entradas', resumen.totalEntradas),
        _lineaResumen('Salidas', resumen.totalSalidas),
        _lineaResumen('Pagos / devoluciones', resumen.totalPagos),
        _lineaResumen(
          'Saldo a cobrar',
          resumen.saldoDeuda,
          color: resumen.saldoDeuda > 0 ? Colors.red : null,
        ),
        if (resumen.saldoAPagar != 0)
          _lineaResumen(
            'Saldo a pagar',
            resumen.saldoAPagar,
            color: resumen.saldoAPagar > 0 ? Colors.red : null,
          ),
      ],
    );
  }

  Widget _filaTabla(_FilaMovimiento fila) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(fila.fecha, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 3,
            child: Text(fila.descripcion, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(
              fila.montoTexto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fila.montoColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(fila.tipo, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;
    final filas = _filas();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Capital',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppColors.tarjeta,
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
                          _bloquePersona(resumen[i]),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppColors.tarjeta,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Movimientos recientes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final opcion in const [
                            ('todo', 'Todo'),
                            ('hoy', 'Hoy'),
                            ('semana', '7 días'),
                            ('mes', 'Este mes'),
                          ])
                            ChoiceChip(
                              label: Text(opcion.$2),
                              selected: _periodo == opcion.$1,
                              onSelected: (_) =>
                                  setState(() => _periodo = opcion.$1),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Fecha',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Descripción',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Monto',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Tipo',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (filas.isEmpty)
                        Text(
                          'Sin movimientos',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            itemCount: filas.length,
                            itemBuilder: (context, index) {
                              return _filaTabla(filas[index]);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _showAddMovimientoDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '+ Nuevo movimiento',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
