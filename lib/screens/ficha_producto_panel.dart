import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/ampliacion_local.dart';
import '../data/vidriera_local.dart';
import '../services/asistente/foto_catalogo_asistente.dart';
import '../services/negocio_local.dart';
import '../services/openai_chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/elegir_foto.dart';
import '../utils/moneda.dart';

/// Categoría, atributos, serie y variantes de un producto (RF 2.3, 2.4 y 2.6).
class FichaProductoPanel extends StatefulWidget {
  const FichaProductoPanel({
    super.key,
    required this.productoId,
    required this.nombre,
  });

  final int productoId;
  final String nombre;

  @override
  State<FichaProductoPanel> createState() => _FichaProductoPanelState();
}

class _FichaProductoPanelState extends State<FichaProductoPanel> {
  List<String> _categorias = const [];
  List<String> _elegidas = const [];
  List<String> _atributos = const [];
  final Map<String, TextEditingController> _valores = {};
  bool _controla = true;
  bool _visible = true;
  final _umbral = TextEditingController(text: '2');
  List<UnidadSerie> _unidades = [];
  List<VarianteLocal> _variantes = [];
  final _descripcion = TextEditingController();
  List<FotoVidriera> _fotos = [];
  bool _leyendoFoto = false;
  bool _generando = false;
  bool _listo = false;
  bool _guardando = false;
  String? _error;

  bool get _pideSerie => _atributos.any((nombre) {
        final texto = nombre.toLowerCase();
        return texto.contains('serie') || texto.contains('imei');
      });

  bool get _pideVariantes => _atributos.any((nombre) {
        final texto = nombre.toLowerCase();
        return texto == 'talle' ||
            texto == 'color' ||
            texto == 'variante' ||
            texto == 'tamaño';
      });

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final campo in _valores.values) {
      campo.dispose();
    }
    _umbral.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final negocio = await NegocioStore().leer();
    final doc = await const AmpliacionLocal().cargar();
    final vidriera = await const VidrieraLocal().de(widget.productoId);
    if (!mounted) return;
    final ficha = doc.fichas[widget.productoId] ?? const FichaProducto();
    final atributos = negocio?.atributos ?? const <String>[];
    for (final nombre in atributos) {
      final limpio = nombre.trim().toLowerCase();
      if (limpio == 'nombre' || limpio == 'precio') continue;
      _valores[nombre] = TextEditingController(
        text: ficha.atributos[nombre] ?? '',
      );
    }
    final disponibles = negocio?.categorias ?? const <String>[];
    setState(() {
      _categorias = disponibles;
      _atributos = _valores.keys.toList();
      _elegidas = [
        for (final nombre in ficha.todas)
          if (disponibles.any(
            (item) => item.toLowerCase() == nombre.toLowerCase(),
          ))
            disponibles.firstWhere(
              (item) => item.toLowerCase() == nombre.toLowerCase(),
            ),
      ];
      _controla = ficha.controlaStock;
      _visible = ficha.visibleEnTienda;
      _umbral.text = '${ficha.umbral}';
      _unidades = [...ficha.unidades];
      _variantes = [...ficha.variantes];
      _descripcion.text = vidriera.descripcion;
      _fotos = [...vidriera.galeria];
      _listo = true;
    });
  }

  Future<void> _guardar() async {
    final umbral = int.tryParse(_umbral.text.trim());
    if (umbral == null || umbral < 0) {
      setState(() => _error = 'El mínimo de stock tiene que ser cero o más.');
      return;
    }
    if (_fotos.length > topeCantidadFotos) {
      setState(() => _error = mensajeGaleriaLlena);
      return;
    }
    for (final foto in _fotos) {
      final rechazoFoto = motivoRechazoFoto(foto.base64);
      if (rechazoFoto != null) {
        setState(() => _error = rechazoFoto);
        return;
      }
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await const AmpliacionLocal().guardarFicha(
        widget.productoId,
        FichaProducto(
          categoria: _elegidas.isEmpty ? '' : _elegidas.first,
          categorias: _elegidas,
          atributos: {
            for (final entrada in _valores.entries) entrada.key: entrada.value.text.trim(),
          },
          controlaStock: _controla,
          visibleEnTienda: _visible,
          umbral: umbral,
          unidades: _unidades.where((unidad) => unidad.codigo.isNotEmpty).toList(),
          variantes: _variantes.where((variante) => variante.etiqueta.isNotEmpty).toList(),
        ),
      );
      final variantesVivas = {
        for (final variante in _variantes)
          if (variante.etiqueta.trim().isNotEmpty)
            variante.etiqueta.trim().toLowerCase(),
      };
      await const VidrieraLocal().guardar(
        productoId: widget.productoId,
        descripcion: _descripcion.text,
        fotoBase64: '',
        fotos: [
          for (final foto in _fotos)
            if (foto.variante.trim().isEmpty ||
                variantesVivas.contains(foto.variante.trim().toLowerCase()))
              foto,
        ],
      );
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardé la ficha del producto.')),
      );
    } on VidrieraRechazada catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error.mensaje;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = '$error';
      });
    }
  }

  Future<void> _nuevaUnidad() async {
    final campo = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Número de serie'),
        content: TextField(
          controller: campo,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'IMEI o serie'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, campo.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    campo.dispose();
    if (codigo == null || codigo.isEmpty || !mounted) return;
    final repetido = _unidades.any(
      (unidad) => unidad.codigo.toLowerCase() == codigo.toLowerCase(),
    );
    if (repetido) {
      setState(() => _error = 'Ese número de serie ya está cargado.');
      return;
    }
    setState(() {
      _error = null;
      _unidades = [..._unidades, UnidadSerie(codigo: codigo)];
    });
  }

  Future<void> _nuevaVariante() async {
    final etiqueta = TextEditingController();
    final stock = TextEditingController(text: '0');
    final precio = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Variante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: etiqueta,
              decoration: const InputDecoration(labelText: 'Talle, color u otra combinación'),
            ),
            TextField(
              controller: stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock'),
            ),
            TextField(
              controller: precio,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio propio (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Agregar')),
        ],
      ),
    );
    final nombre = etiqueta.text.trim();
    final cantidad = int.tryParse(stock.text.trim()) ?? 0;
    final propio = leerMontoEscrito(precio.text);
    etiqueta.dispose();
    stock.dispose();
    precio.dispose();
    if (ok != true || nombre.isEmpty || !mounted) return;
    setState(() {
      _variantes = [
        ..._variantes,
        VarianteLocal(etiqueta: nombre, stock: cantidad < 0 ? 0 : cantidad, precio: propio),
      ];
    });
  }

  Future<void> _generarFoto() async {
    if (_leyendoFoto || _guardando || _generando) return;
    if (_fotos.length >= topeCantidadFotos) {
      setState(() => _error = mensajeGaleriaLlena);
      return;
    }
    final nombre = widget.nombre.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Falta el nombre del producto para generar la imagen.');
      return;
    }
    setState(() {
      _generando = true;
      _error = null;
    });
    try {
      final jpeg = await FotoCatalogoAsistente().generar(
        nombre: nombre,
        descripcion: _descripcion.text,
      );
      final texto = base64Encode(jpeg);
      final rechazo = motivoRechazoFoto(texto);
      if (!mounted) return;
      if (rechazo != null) {
        setState(() => _error = rechazo);
        return;
      }
      setState(() {
        _fotos = [..._fotos, FotoVidriera(base64: texto)];
      });
    } on ChatIaException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.mensaje);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo generar la imagen.');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _agregarFotos({String variante = ''}) async {
    if (_leyendoFoto || _guardando || _generando) return;
    if (_fotos.length >= topeCantidadFotos) {
      setState(() => _error = mensajeGaleriaLlena);
      return;
    }
    final origen = await preguntarOrigenFoto(context);
    if (origen == null || !mounted) return;
    setState(() {
      _leyendoFoto = true;
      _error = null;
    });
    try {
      final archivos = await elegirFotos(
        origen: origen,
        variasEnGaleria: true,
      );
      if (archivos.isEmpty || !mounted) return;
      final nuevas = <FotoVidriera>[];
      String? aviso;
      for (final archivo in archivos) {
        if (_fotos.length + nuevas.length >= topeCantidadFotos) {
          aviso = mensajeGaleriaLlena;
          break;
        }
        final texto = base64Encode(await archivo.readAsBytes());
        final rechazo = motivoRechazoFoto(texto);
        if (rechazo != null) {
          aviso = rechazo;
          continue;
        }
        nuevas.add(FotoVidriera(base64: texto, variante: variante));
      }
      if (!mounted) return;
      setState(() {
        _fotos = [..._fotos, ...nuevas];
        _error = aviso;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pude abrir la cámara o la galería.');
    } finally {
      if (mounted) setState(() => _leyendoFoto = false);
    }
  }

  void _quitarFoto(int indice) {
    if (indice < 0 || indice >= _fotos.length) return;
    setState(() {
      _fotos = [
        for (var i = 0; i < _fotos.length; i++)
          if (i != indice) _fotos[i],
      ];
      _error = null;
    });
  }

  Widget _miniaturas(String variante) {
    final buscada = variante.trim().toLowerCase();
    final indices = [
      for (var i = 0; i < _fotos.length; i++)
        if (_fotos[i].variante.trim().toLowerCase() == buscada) i,
    ];
    if (indices.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final indice in indices)
          _MiniaturaFoto(
            base64: _fotos[indice].base64,
            onQuitar: (_guardando || _leyendoFoto || _generando)
                ? null
                : () => _quitarFoto(indice),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_listo) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ficha del rubro', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('Categorías', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Un producto puede estar en varias.',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            if (_categorias.isEmpty)
              const Text('Primero creá categorías en el negocio.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final nombre in _categorias)
                    FilterChip(
                      label: Text(nombre),
                      selected: _elegidas.any(
                        (item) => item.toLowerCase() == nombre.toLowerCase(),
                      ),
                      onSelected: (activa) {
                        setState(() {
                          _elegidas = [
                            for (final item in _elegidas)
                              if (item.toLowerCase() != nombre.toLowerCase()) item,
                            if (activa) nombre,
                          ];
                        });
                      },
                    ),
                ],
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Se muestra en la tienda'),
              value: _visible,
              onChanged: (valor) => setState(() => _visible = valor),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Controla stock'),
              subtitle: const Text('Un plato puede venderse aunque no lleve unidades.'),
              value: _controla,
              onChanged: (valor) => setState(() => _controla = valor),
            ),
            TextField(
              controller: _umbral,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Avisar si el stock baja de',
              ),
            ),
            for (final nombre in _atributos) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _valores[nombre],
                decoration: InputDecoration(labelText: nombre),
              ),
            ],
            if (_pideSerie) ...[
              const SizedBox(height: 16),
              Text(
                'Unidades',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_unidades.isEmpty)
                const Text('Todavía no hay números de serie.')
              else
                for (var i = 0; i < _unidades.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_unidades[i].codigo),
                    subtitle: DropdownButton<String>(
                      value: _unidades[i].estado,
                      items: const [
                        DropdownMenuItem(value: 'disponible', child: Text('Disponible')),
                        DropdownMenuItem(value: 'reservada', child: Text('Reservada')),
                        DropdownMenuItem(value: 'vendida', child: Text('Vendida')),
                        DropdownMenuItem(value: 'baja', child: Text('Baja')),
                      ],
                      onChanged: (estado) {
                        if (estado == null) return;
                        setState(() {
                          _unidades[i] = UnidadSerie(
                            codigo: _unidades[i].codigo,
                            estado: estado,
                          );
                        });
                      },
                    ),
                  ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _nuevaUnidad,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Agregar serie'),
                ),
              ),
            ],
            if (_pideVariantes) ...[
              const SizedBox(height: 8),
              Text('Variantes', style: Theme.of(context).textTheme.titleMedium),
              for (final variante in _variantes) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(variante.etiqueta),
                  subtitle: Text(
                    variante.precio == null
                        ? 'Stock ${variante.stock}'
                        : 'Stock ${variante.stock} · ${variante.precio}',
                  ),
                ),
                _miniaturas(variante.etiqueta),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: (_guardando || _leyendoFoto || _generando)
                        ? null
                        : () => _agregarFotos(variante: variante.etiqueta),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text('Foto de ${variante.etiqueta}'),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _nuevaVariante,
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('Agregar variante'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Vidriera', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Podés agregar varias fotos del producto. No se cargan solas.',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descripcion,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: (_guardando || _leyendoFoto || _generando)
                    ? null
                    : _agregarFotos,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_leyendoFoto ? 'Leyendo foto...' : 'Agregar fotos'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: (_guardando || _leyendoFoto || _generando)
                    ? null
                    : _generarFoto,
                icon: Icon(
                  _generando
                      ? Icons.hourglass_top
                      : Icons.auto_awesome_outlined,
                ),
                label: Text(
                  _generando
                      ? 'Generando...'
                      : 'Generar según título y descripción',
                ),
              ),
            ),
            _miniaturas(''),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.alerta)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando...' : 'Guardar ficha'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniaturaFoto extends StatelessWidget {
  const _MiniaturaFoto({required this.base64, required this.onQuitar});

  final String base64;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final bytes = bytesDeFotoVidriera(base64);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: bytes == null
                  ? const ColoredBox(
                      color: AppColors.fondoClaro,
                      child: Icon(Icons.broken_image_outlined),
                    )
                  : Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onQuitar,
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
