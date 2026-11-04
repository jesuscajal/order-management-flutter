import 'package:flutter/material.dart';

import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';
import '../widgets/logo_gexi.dart';

class CrearNegocioScreen extends StatefulWidget {
  const CrearNegocioScreen({
    super.key,
    required this.alCrear,
    required this.duenoEmail,
    required this.alUnirse,
  });

  final ValueChanged<NegocioLocal> alCrear;
  final ValueChanged<NegocioLocal> alUnirse;
  final String duenoEmail;

  @override
  State<CrearNegocioScreen> createState() => _CrearNegocioScreenState();
}

class _CrearNegocioScreenState extends State<CrearNegocioScreen> {
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    if (_nombre.text.trim().isEmpty || _descripcion.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá el nombre y a qué se dedica el negocio.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final negocio = await NegocioStore().crear(
        nombre: _nombre.text,
        descripcion: _descripcion.text,
        duenoEmail: widget.duenoEmail,
      );
      if (!mounted) return;
      widget.alCrear(negocio);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el negocio.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _entrarConCodigo() async {
    if (_guardando) return;
    final campo = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código de empleado'),
        content: TextField(
          controller: campo,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código',
            helperText: 'Te lo da quien administra el negocio.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, campo.text.trim()),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    final escrito = codigo ?? '';
    campo.dispose();
    if (escrito.isEmpty || !mounted) return;
    setState(() => _guardando = true);
    try {
      final negocio = await NegocioStore().unirEmpleado(
        codigo: escrito,
        email: widget.duenoEmail,
      );
      if (!mounted) return;
      widget.alUnirse(negocio);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo entrar con ese código.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text('Tu negocio')),
      body: FondoGexi(
        child: SizedBox.expand(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const Center(child: LogoGexi(ancho: 128)),
              const SizedBox(height: 8),
              const _Paso(numero: 1),
              const SizedBox(height: 8),
              Text(
                'Contanos el negocio',
                style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Escribí el nombre y, en tus palabras, a qué te dedicás. Si mezclás más de un rubro, en el paso siguiente los vas a ver todos.',
                style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio',
                  hintText: 'Novaceltec',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descripcion,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿A qué se dedica?',
                  hintText: 'Vendo celulares y también fundas y ropa',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _continuar,
                child: Text(_guardando ? 'Guardando...' : 'Ver propuesta'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _guardando ? null : _entrarConCodigo,
                child: const Text('Entrar con código de empleado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfiguracionAsistidaScreen extends StatefulWidget {
  const ConfiguracionAsistidaScreen({
    super.key,
    required this.negocio,
    required this.alConfirmar,
    required this.duenoEmail,
  });

  final NegocioLocal negocio;
  final ValueChanged<NegocioLocal> alConfirmar;
  final String duenoEmail;

  @override
  State<ConfiguracionAsistidaScreen> createState() => _ConfiguracionAsistidaScreenState();
}

class _ConfiguracionAsistidaScreenState extends State<ConfiguracionAsistidaScreen> {
  late final List<String> _detectados;
  final _elegidos = <String>{};
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _detectados = PropuestaRubro.detectarIds(widget.negocio.descripcion);
    _elegidos.addAll(_detectados);
  }

  PropuestaRubro get _propuesta => PropuestaRubro.desdeIds(_elegidos);

  bool get _puedeConfirmar => !_guardando && _elegidos.isNotEmpty;

  void _alternar(String id) {
    if (_guardando) return;
    setState(() {
      if (_elegidos.contains(id)) {
        _elegidos.remove(id);
      } else {
        _elegidos.add(id);
      }
    });
  }

  Future<void> _confirmar() async {
    if (_elegidos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí al menos un rubro para continuar.')),
      );
      return;
    }
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await NegocioStore().confirmar(
        widget.negocio,
        _propuesta,
        duenoEmail: widget.duenoEmail,
      );
      final guardado = await NegocioStore().leer();
      if (!mounted) return;
      if (guardado == null || !guardado.configurado) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la configuración.')),
        );
        return;
      }
      widget.alConfirmar(guardado);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la configuración.')),
      );
    }
  }

  String _textoDeteccion() {
    if (_detectados.isEmpty) {
      return 'No detectamos un rubro en la descripción. Marcá los que correspondan. Si ninguno encaja, elegí ${CatalogoRubros.general.nombre}.';
    }
    final nombres = [
      for (final rubro in CatalogoRubros.enOrden(_detectados)) rubro.nombre,
    ];
    return 'Detectamos ${_enumerar(nombres)}. Tocá para sacar o sumar rubros.';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final elegidos = CatalogoRubros.enOrden(_elegidos);
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text('Configuración')),
      body: FondoGexi(
        child: SizedBox.expand(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              const _Paso(numero: 2),
              const SizedBox(height: 8),
              Text(
                widget.negocio.nombre,
                style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                widget.negocio.descripcion,
                style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 20),
              _Tarjeta(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rubros', style: tema.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      _textoDeteccion(),
                      style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final rubro in CatalogoRubros.todos)
                          _ChipRubro(
                            texto: rubro.nombre,
                            activo: _elegidos.contains(rubro.id),
                            onTap: _guardando ? null : () => _alternar(rubro.id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (elegidos.isEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Elegí al menos un rubro para continuar.',
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 22),
                Text(
                  elegidos.length == 1 ? 'Qué aporta este rubro' : 'Qué aporta cada rubro',
                  style: tema.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final rubro in elegidos) ...[
                  _TarjetaRubro(rubro: rubro),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 10),
                Text('Propuesta final', style: tema.textTheme.titleMedium),
                const SizedBox(height: 10),
                _TarjetaFinal(propuesta: _propuesta),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _puedeConfirmar ? _confirmar : null,
                child: Text(_guardando ? 'Confirmando...' : 'Confirmar y empezar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Paso $numero de 2',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.primario,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppColors.tarjeta,
      child: child,
    );
  }
}

class _ChipRubro extends StatelessWidget {
  const _ChipRubro({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final String texto;
  final bool activo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fondo = activo ? AppColors.primario : Colors.white;
    final tinta = activo ? Colors.white : AppColors.texto;
    return Semantics(
      button: true,
      selected: activo,
      child: Material(
        color: fondo,
        shape: StadiumBorder(
          side: BorderSide(color: activo ? AppColors.primario : AppColors.linea),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activo) ...[
                  const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(
                  texto,
                  style: TextStyle(color: tinta, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaRubro extends StatelessWidget {
  const _TarjetaRubro({required this.rubro});

  final RubroDefinicion rubro;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.limaBrillo,
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconoRubro(rubro.id), color: AppColors.primario, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(rubro.nombre, style: tema.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GrupoChips(titulo: 'Categorías', items: rubro.categorias),
          const SizedBox(height: 12),
          _GrupoChips(
            titulo: 'Atributos',
            items: rubro.atributos,
            tono: _TonoChip.atributo,
          ),
          const SizedBox(height: 12),
          _GrupoChips(
            titulo: 'Tipo de tienda',
            items: [rubro.tipoTienda],
            tono: _TonoChip.tienda,
          ),
        ],
      ),
    );
  }
}

class _TarjetaFinal extends StatelessWidget {
  const _TarjetaFinal({required this.propuesta});

  final PropuestaRubro propuesta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(propuesta.plantilla, style: tema.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            propuesta.nota,
            style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 14),
          _GrupoChips(titulo: 'Categorías', items: propuesta.categorias),
          const SizedBox(height: 12),
          _GrupoChips(
            titulo: 'Atributos',
            items: propuesta.atributos,
            tono: _TonoChip.atributo,
          ),
          const SizedBox(height: 12),
          _GrupoChips(
            titulo: 'Tipo de tienda',
            items: [propuesta.tipoTienda],
            tono: _TonoChip.tienda,
          ),
        ],
      ),
    );
  }
}

class _GrupoChips extends StatelessWidget {
  const _GrupoChips({
    required this.titulo,
    required this.items,
    this.tono = _TonoChip.neutro,
  });

  final String titulo;
  final List<String> items;
  final _TonoChip tono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items) _ChipDato(texto: item, tono: tono),
          ],
        ),
      ],
    );
  }
}

enum _TonoChip { neutro, atributo, tienda }

class _ChipDato extends StatelessWidget {
  const _ChipDato({required this.texto, this.tono = _TonoChip.neutro});

  final String texto;
  final _TonoChip tono;

  @override
  Widget build(BuildContext context) {
    final fondo = switch (tono) {
      _TonoChip.atributo => const Color(0xFFE8F0FF),
      _TonoChip.tienda => AppColors.limaBrillo,
      _TonoChip.neutro => AppColors.limaBrillo,
    };
    final tinta = tono == _TonoChip.tienda ? AppColors.verde : AppColors.texto;
    return Chip(
      label: Text(texto),
      backgroundColor: fondo,
      labelStyle: TextStyle(color: tinta, fontWeight: FontWeight.w700),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

IconData _iconoRubro(String id) {
  switch (id) {
    case 'tecnologia':
      return Icons.smartphone_rounded;
    case 'indumentaria':
      return Icons.checkroom_rounded;
    case 'gastronomia':
      return Icons.restaurant_rounded;
    default:
      return Icons.inventory_2_rounded;
  }
}

String _enumerar(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.single;
  if (items.length == 2) return '${items[0]} y ${items[1]}';
  return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
}
