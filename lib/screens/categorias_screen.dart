import 'package:flutter/material.dart';

import '../data/ampliacion_local.dart';
import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

/// Alta, orden y baja de las categorías del negocio (RF 2.2).
class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final _store = NegocioStore();
  List<String> _categorias = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final negocio = await _store.leer();
    if (!mounted) return;
    setState(() {
      _categorias = negocio == null
          ? []
          : [for (final nombre in negocio.categorias) nombre];
      _cargando = false;
      _error = negocio == null ? 'Primero creá el negocio.' : null;
    });
  }

  Future<void> _persistir(List<String> categorias) async {
    await _store.guardarCatalogo(categorias: categorias);
    await const AmpliacionLocal().anotar(
      accion: 'editar',
      entidad: 'categoria',
      detalle: 'Categorías: ${categorias.join(', ')}',
    );
    if (!mounted) return;
    setState(() => _categorias = categorias);
  }

  Future<void> _pedirNombre({String? actual, required void Function(String) alGuardar}) async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => _NombreCategoriaDialog(
        titulo: actual == null ? 'Nueva categoría' : 'Renombrar',
        inicial: actual ?? '',
      ),
    );
    if (nombre == null || nombre.isEmpty || !mounted) return;
    final repetida = _categorias.any(
      (item) => item.toLowerCase() == nombre.toLowerCase() && item != actual,
    );
    if (repetida) {
      setState(() => _error = 'Ya hay una categoría con ese nombre.');
      return;
    }
    alGuardar(nombre);
  }

  Future<void> _agregar() async {
    await _pedirNombre(alGuardar: (nombre) async {
      try {
        await _persistir([..._categorias, nombre]);
      } catch (error) {
        if (!mounted) return;
        setState(() => _error = '$error');
      }
    });
  }

  Future<void> _renombrar(int indice) async {
    final anterior = _categorias[indice];
    await _pedirNombre(
      actual: anterior,
      alGuardar: (nombre) async {
        final copia = [..._categorias];
        copia[indice] = nombre;
        try {
          await _persistir(copia);
          final doc = await const AmpliacionLocal().cargar();
          for (final entrada in doc.fichas.entries) {
            final actuales = entrada.value.todas;
            if (!actuales.any(
              (item) => item.toLowerCase() == anterior.toLowerCase(),
            )) {
              continue;
            }
            final nuevas = [
              for (final item in actuales)
                if (item.toLowerCase() == anterior.toLowerCase()) nombre else item,
            ];
            await const AmpliacionLocal().guardarFicha(
              entrada.key,
              FichaProducto(
                categoria: nuevas.isEmpty ? '' : nuevas.first,
                categorias: nuevas,
                atributos: entrada.value.atributos,
                controlaStock: entrada.value.controlaStock,
                visibleEnTienda: entrada.value.visibleEnTienda,
                umbral: entrada.value.umbral,
                unidades: entrada.value.unidades,
                variantes: entrada.value.variantes,
              ),
            );
          }
        } catch (error) {
          if (!mounted) return;
          setState(() => _error = '$error');
        }
      },
    );
  }

  Future<void> _borrar(int indice) async {
    final nombre = _categorias[indice];
    final seguro = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar categoría'),
        content: Text('¿Seguro que querés eliminar "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alerta),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (seguro != true || !mounted) return;
    final doc = await const AmpliacionLocal().cargar();
    final usada = doc.fichas.values.any(
      (ficha) => ficha.todas.any(
        (item) => item.toLowerCase() == nombre.toLowerCase(),
      ),
    );
    if (!mounted) return;
    if (usada) {
      setState(() {
        _error = 'Mové los productos de "$nombre" antes de eliminarla.';
      });
      return;
    }
    final copia = [..._categorias]..removeAt(indice);
    try {
      await _persistir(copia);
      if (!mounted) return;
      setState(() => _error = null);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _mover(int indice, int delta) async {
    final destino = indice + delta;
    if (destino < 0 || destino >= _categorias.length) return;
    final copia = [..._categorias];
    final item = copia.removeAt(indice);
    copia.insert(destino, item);
    try {
      await _persistir(copia);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        onPressed: _cargando || _error == 'Primero creá el negocio.' ? null : _agregar,
        child: const Icon(Icons.add),
      ),
      body: FondoGexi(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: [
                  const Text(
                    'El orden de esta lista es el orden de la tienda. No se puede borrar una categoría que todavía tiene productos.',
                    style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.alerta)),
                  ],
                  const SizedBox(height: 12),
                  if (_categorias.isEmpty)
                    const Text(
                      'Todavía no hay categorías.',
                      style: TextStyle(color: AppColors.texto),
                    )
                  else
                    for (var i = 0; i < _categorias.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: AppColors.tarjeta,
                        child: ListTile(
                          title: Text(
                            _categorias[i],
                            style: const TextStyle(
                              color: AppColors.texto,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () => _renombrar(i),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Subir',
                                onPressed: i == 0 ? null : () => _mover(i, -1),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip: 'Bajar',
                                onPressed: i == _categorias.length - 1
                                    ? null
                                    : () => _mover(i, 1),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => _borrar(i),
                                icon: const Icon(Icons.delete_outline, color: AppColors.alerta),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

class _NombreCategoriaDialog extends StatefulWidget {
  const _NombreCategoriaDialog({required this.titulo, required this.inicial});

  final String titulo;
  final String inicial;

  @override
  State<_NombreCategoriaDialog> createState() => _NombreCategoriaDialogState();
}

class _NombreCategoriaDialogState extends State<_NombreCategoriaDialog> {
  late final TextEditingController _campo = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _campo,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nombre'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _campo.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
