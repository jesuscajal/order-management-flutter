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
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text('Actividad')),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const Text(
                      'Registro de cambios de este dispositivo. Solo se agregan filas nuevas.',
                      style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onChanged: (valor) => setState(() => _actor = valor),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final periodo in const ['todo', 'hoy', 'semana'])
                          ChoiceChip(
                            label: Text(periodo == 'todo'
                                ? 'Todas las fechas'
                                : periodo == 'hoy'
                                    ? 'Hoy'
                                    : '7 días'),
                            selected: _periodo == periodo,
                            onSelected: (_) => setState(() => _periodo = periodo),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final ambito in const ['', 'pedido', 'stock', 'capital', 'producto', 'comprobante'])
                          ChoiceChip(
                            label: Text(ambito.isEmpty ? 'Todo' : ambito),
                            selected: _ambito == ambito,
                            onSelected: (_) => setState(() => _ambito = ambito),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: AppColors.alerta)),
                    if (_cargando && _hechos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_visibles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Todavía no hay movimientos para mostrar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textoSuave),
                        ),
                      )
                    else
                      for (final hecho in _visibles) _tarjeta(hecho),
                  ],
                ),
              ),
      ),
    );
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

  Widget _tarjeta(HechoActividad hecho) {
    final local = hecho.fecha.toLocal();
    final hora =
        '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hora, style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            hecho.titulo,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(hecho.detalle, style: const TextStyle(color: AppColors.texto)),
          if (hecho.actor.isNotEmpty)
            Text(
              hecho.actor,
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
