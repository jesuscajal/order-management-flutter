import 'package:flutter/material.dart';

import '../data/actividad_local.dart';
import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

class ActividadScreen extends StatefulWidget {
  const ActividadScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends State<ActividadScreen> {
  List<HechoActividad> _hechos = const [];
  bool _cargando = false;
  String? _error;
  String _ambito = '';
  String _actor = '';
  String _periodo = 'todo';

  @override
  void initState() {
    super.initState();
    if (widget.database != null) {
      _cargando = true;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final db = widget.database;
    if (db == null) return;
    try {
      final hechos = await cargarActividad(db);
      final extra = await const AmpliacionLocal().cargar();
      final unidos = [
        ...hechos,
        for (final nota in extra.auditoria)
          HechoActividad(
            fecha: nota.cuando,
            titulo: '${nota.accion} · ${nota.entidad}',
            detalle: nota.detalle,
            actor: nota.actor,
            ambito: nota.entidad,
          ),
      ]..sort((a, b) => b.fecha.compareTo(a.fecha));
      if (!mounted) return;
      setState(() {
        _hechos = unidos.length > 80 ? unidos.sublist(0, 80) : unidos;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No pudimos leer la actividad.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Actividad',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FondoGexi(
        child: widget.database == null
            ? const Center(
                child: Text(
                  'No hay base conectada.',
                  style: TextStyle(color: AppColors.textoSuave),
                ),
              )
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    TextField(
                      onChanged: (valor) => setState(() => _actor = valor),
                      decoration: const InputDecoration(
                        hintText: 'Buscar persona',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final periodo in const ['todo', 'hoy', 'semana'])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_etiquetaPeriodo(periodo)),
                                selected: _periodo == periodo,
                                onSelected: (_) =>
                                    setState(() => _periodo = periodo),
                              ),
                            ),
                          for (final ambito in const [
                            '',
                            'pedido',
                            'stock',
                            'capital',
                            'cliente',
                            'producto',
                            'comprobante',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  ambito.isEmpty ? 'Todo' : _etiquetaAmbito(ambito),
                                ),
                                selected: _ambito == ambito,
                                onSelected: (_) => setState(() => _ambito = ambito),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.alerta),
                      ),
                    if (_cargando && _hechos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (visibles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Todavía no hay movimientos para mostrar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textoSuave),
                        ),
                      )
                    else
                      DecoratedBox(
                        decoration: AppColors.tarjeta,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Column(
                            children: [
                              for (var i = 0; i < visibles.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    indent: 66,
                                    color: AppColors.linea,
                                  ),
                                _fila(visibles[i]),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  String _etiquetaPeriodo(String periodo) {
    return switch (periodo) {
      'hoy' => 'Hoy',
      'semana' => '7 días',
      _ => 'Todas',
    };
  }

  List<HechoActividad> get _visibles {
    final actor = _actor.trim().toLowerCase();
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return [
      for (final hecho in _hechos)
        if ((_ambito.isEmpty || hecho.ambito == _ambito) &&
            (actor.isEmpty || hecho.actor.toLowerCase().contains(actor)) &&
            _entra(hecho.fecha, hoy))
          hecho,
    ];
  }

  bool _entra(DateTime fecha, DateTime hoy) {
    final dia = DateTime(fecha.toLocal().year, fecha.toLocal().month, fecha.toLocal().day);
    switch (_periodo) {
      case 'hoy':
        return dia == hoy;
      case 'semana':
        return !dia.isBefore(hoy.subtract(const Duration(days: 6)));
      default:
        return true;
    }
  }

  Widget _fila(HechoActividad hecho) {
    final local = hecho.fecha.toLocal();
    final hora =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final color = _colorAmbito(hecho.ambito);
    final actor = hecho.actor.trim();
    final detalle = actor.isEmpty || hecho.detalle.contains(actor)
        ? hecho.detalle
        : '$actor · ${hecho.detalle}';
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
            child: Icon(_iconoAmbito(hecho.ambito), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hecho.titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hora,
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _etiquetaAmbito(String ambito) {
  return switch (ambito) {
    'pedido' => 'Pedidos',
    'stock' => 'Stock',
    'capital' => 'Capital',
    'cliente' => 'Clientes',
    'producto' => 'Productos',
    'comprobante' => 'Comprobantes',
    _ => ambito,
  };
}

IconData _iconoAmbito(String ambito) {
  return switch (ambito) {
    'pedido' => Icons.receipt_long_rounded,
    'stock' => Icons.inventory_2_outlined,
    'capital' => Icons.payments_rounded,
    'cliente' => Icons.person_outline_rounded,
    'producto' => Icons.sell_outlined,
    'comprobante' => Icons.image_outlined,
    _ => Icons.history_rounded,
  };
}

Color _colorAmbito(String ambito) {
  return switch (ambito) {
    'pedido' => AppColors.primario,
    'stock' => const Color(0xFFD97706),
    'capital' => AppColors.lima,
    'cliente' => AppColors.teal,
    'comprobante' => AppColors.azulProfundo,
    _ => AppColors.primario,
  };
}
