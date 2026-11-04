import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

/// Personas del negocio, guardadas en el dispositivo. Máximo cinco, además del dueño.
class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key});

  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
  final _store = NegocioStore();
  List<MiembroEquipo> _equipo = const [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final negocio = await _store.leer();
    if (!mounted) return;
    final equipo = negocio?.equipo ?? const <MiembroEquipo>[];
    final faltaCodigo = equipo.any((miembro) => miembro.codigo.isEmpty);
    if (faltaCodigo && negocio != null) {
      final actualizado = await _store.guardarEquipo(equipo);
      if (!mounted) return;
      setState(() {
        _equipo = actualizado?.equipo ?? equipo;
        _cargando = false;
      });
      return;
    }
    setState(() {
      _equipo = equipo;
      _cargando = false;
    });
  }

  Future<void> _guardar(List<MiembroEquipo> equipo) async {
    setState(() => _guardando = true);
    try {
      final actualizado = await _store.guardarEquipo(equipo);
      if (!mounted) return;
      setState(() {
        _equipo = actualizado?.equipo ?? equipo;
        _guardando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _agregar() async {
    if (_equipo.length >= NegocioLocal.cupoEquipo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El equipo ya tiene cinco personas.')),
      );
      return;
    }
    final nombreCtrl = TextEditingController();
    var rol = 'vendedor';
    final acepto = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Nueva persona'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')),
                  DropdownMenuItem(
                    value: 'administrador',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (valor) {
                  if (valor == null) return;
                  setLocal(() => rol = valor);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    final nombre = nombreCtrl.text.trim();
    nombreCtrl.dispose();
    if (acepto != true || nombre.isEmpty || !mounted) return;
    await _guardar([
      ..._equipo,
      MiembroEquipo(nombre: nombre, rol: rol),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        title: const Text('Equipo'),
        actions: [
          IconButton(
            tooltip: 'Agregar persona',
            onPressed: _guardando ? null : _agregar,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: FondoGexi(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  const Text(
                    'Hasta ${NegocioLocal.cupoEquipo} personas, además de quien creó el negocio. '
                    'Cada una entra con su código de empleado, en este dispositivo.',
                    style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  if (_equipo.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Todavía no sumaste a nadie.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textoSuave),
                      ),
                    )
                  else
                    for (var i = 0; i < _equipo.length; i++)
                      _tarjeta(i, _equipo[i]),
                ],
              ),
      ),
    );
  }

  Widget _tarjeta(int indice, MiembroEquipo miembro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppColors.tarjeta,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    miembro.nombre,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: _guardando
                      ? null
                      : () {
                          final copia = [..._equipo]..removeAt(indice);
                          _guardar(copia);
                        },
                  icon: const Icon(Icons.close, color: AppColors.alerta),
                ),
              ],
            ),
            Text(
              miembro.codigo.isEmpty
                  ? 'Sin código'
                  : 'Código de empleado ${miembro.codigo}',
              style: const TextStyle(
                color: AppColors.lima,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (miembro.email.isNotEmpty)
              Text(
                'En uso por ${miembro.email}',
                style: const TextStyle(color: AppColors.textoSuave),
              ),
            if (miembro.codigo.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: miembro.codigo));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado.')),
                    );
                  },
                  child: const Text('Copiar código'),
                ),
              ),
            DropdownButton<String>(
              value: miembro.rol,
              items: const [
                DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')),
                DropdownMenuItem(
                  value: 'administrador',
                  child: Text('Administrador'),
                ),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) {
                      if (valor == null) return;
                      final copia = [..._equipo];
                      copia[indice] = miembro.copiar(rol: valor);
                      _guardar(copia);
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(miembro.activo ? 'Activo' : 'Inactivo'),
              value: miembro.activo,
              onChanged: _guardando
                  ? null
                  : (valor) {
                      final copia = [..._equipo];
                      copia[indice] = miembro.copiar(activo: valor);
                      _guardar(copia);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
