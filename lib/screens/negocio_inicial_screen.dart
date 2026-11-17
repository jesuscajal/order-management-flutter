import 'package:flutter/material.dart';

import '../backend/negocio_remoto.dart';
import '../backend/sesion_remota.dart';
import '../data/apariencia_tienda.dart';
import '../services/negocio_local.dart';
import '../services/propuesta_ia.dart';
import '../services/sesion_google.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';
import '../widgets/logo_gexi.dart';

class CrearNegocioScreen extends StatefulWidget {
  const CrearNegocioScreen({
    super.key,
    required this.alEmpezar,
    required this.duenoEmail,
    required this.alUnirse,
  });

  final void Function(String whatsapp) alEmpezar;
  final ValueChanged<NegocioLocal> alUnirse;
  final String duenoEmail;

  @override
  State<CrearNegocioScreen> createState() => _CrearNegocioScreenState();
}

class _CrearNegocioScreenState extends State<CrearNegocioScreen> {
  final _codigoEmpleado = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _whatsapp = TextEditingController();
  bool _guardando = false;
  String _paso = 'eleccion';
  String? _error;

  @override
  void dispose() {
    _codigoEmpleado.dispose();
    _nombre.dispose();
    _apellido.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  String? _validarNombre() {
    if (_nombre.text.trim().isEmpty) return 'Ingresá tu nombre.';
    if (_apellido.text.trim().isEmpty) return 'Ingresá tu apellido.';
    return null;
  }

  String _nombreCompleto() =>
      '${_nombre.text.trim()} ${_apellido.text.trim()}';

  String? _validarWhatsapp() {
    final digitos = _whatsapp.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length < 8) return 'Ingresá el WhatsApp del negocio.';
    return null;
  }

  String _whatsappListo() {
    final compacto = _whatsapp.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    final digitos = compacto.replaceAll(RegExp(r'\D'), '');
    if (compacto.startsWith('+') || digitos.startsWith('54')) return '+$digitos';
    return '+54$digitos';
  }

  Future<void> _guardarPersona() async {
    final completo = _nombreCompleto();
    await AuthGoogle.instancia.entrarConCorreo(widget.duenoEmail, nombre: completo);
    await const SesionRemota().guardarPerfil(
      nombre: _nombre.text.trim(),
      apellido: _apellido.text.trim(),
      whatsapp: _paso == 'dueno' ? _whatsappListo() : '',
    );
  }

  Future<void> _entrarConCodigo() async {
    if (_guardando) return;
    final falta = _validarNombre();
    if (falta != null) {
      setState(() => _error = falta);
      return;
    }
    final escrito = _codigoEmpleado.text.trim();
    if (escrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá el código que te pasó quien administra.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      NegocioLocal negocio;
      try {
        negocio = await NegocioStore().unirEmpleado(
          codigo: escrito,
          email: widget.duenoEmail,
          nombre: _nombreCompleto(),
        );
      } on StateError catch (error) {
        if (!error.message.contains('este dispositivo')) rethrow;
        final remoto = await const NegocioRemoto().reclamarCodigo(escrito);
        if (remoto == null) {
          throw StateError('No encontramos ese código de empleado.');
        }
        await NegocioStore().guardarLocal(remoto);
        negocio = await NegocioStore().unirEmpleado(
          codigo: escrito,
          email: widget.duenoEmail,
          nombre: _nombreCompleto(),
        );
      }
      await _guardarPersona();
      if (!mounted) return;
      widget.alUnirse(negocio);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      final texto = error.toString().toLowerCase();
      final mensaje = texto.contains('otra cuenta')
          ? 'Ese código ya lo usa otra cuenta.'
          : texto.contains('no encontramos') || texto.contains('no es válido')
              ? 'No encontramos ese código de empleado.'
              : 'No se pudo entrar con ese código. Quien administra tiene que guardar el equipo de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (_paso == 'empleado') return _empleado(tema);
    if (_paso == 'dueno') return _dueno(tema);
    return _eleccion(tema);
  }

  Widget _eleccion(ThemeData tema) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: FondoGexi(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: LogoGexi(ancho: 168)),
                const SizedBox(height: 28),
                Text(
                  '¿Cómo entrás?',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si el negocio es tuyo, lo creás. Si trabajás en uno, entrá con el código que te dio quien administra.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => setState(() {
                    _paso = 'dueno';
                    _error = null;
                  }),
                  child: const Text('Crear mi negocio'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _paso = 'empleado'),
                  child: const Text('Soy empleado'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dueno(ThemeData tema) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tu cuenta'),
      ),
      body: FondoGexi(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              'Como el negocio es tuyo, necesitamos tu nombre y el WhatsApp donde te escriben los clientes.',
              style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apellido,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Apellido'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '11 2345-6789',
                prefixText: '+54 ',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.alerta)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final falta = _validarNombre() ?? _validarWhatsapp();
                if (falta != null) {
                  setState(() => _error = falta);
                  return;
                }
                await _guardarPersona();
                if (!mounted) return;
                widget.alEmpezar(_whatsappListo());
              },
              child: const Text('Continuar'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _paso = 'eleccion';
                _error = null;
              }),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empleado(ThemeData tema) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Soy empleado'),
      ),
      body: FondoGexi(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              'Ingresá tu nombre y el código que te pasó quien administra. Las ventas y los cobros que hagas quedan a tu nombre.',
              style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nombre,
              enabled: !_guardando,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apellido,
              enabled: !_guardando,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Apellido'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codigoEmpleado,
              enabled: !_guardando,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código de empleado',
                hintText: 'AB12CD',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.alerta)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _entrarConCodigo,
              child: Text(_guardando ? 'Entrando...' : 'Entrar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _guardando ? null : () => setState(() => _paso = 'eleccion'),
              child: const Text('Volver'),
            ),
          ],
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
  bool _consultandoIa = true;
  List<String>? _atributosIa;
  AparienciaTienda? _aparienciaIa;
  String _notaIa = '';

  @override
  void initState() {
    super.initState();
    _detectados = PropuestaRubro.detectarIds(widget.negocio.descripcion);
    _elegidos.addAll(_detectados);
    _consultarIa();
  }

  AparienciaTienda get _apariencia {
    final guardada = _aparienciaIa;
    if (guardada != null) return guardada;
    final ids = _elegidos.toSet();
    return AparienciaTienda.paraRubros(
      gastronomiaSola:
          ids.length == 1 && ids.contains(CatalogoRubros.gastronomia.id),
      indumentaria: ids.contains(CatalogoRubros.indumentaria.id),
      tecnologia: ids.contains(CatalogoRubros.tecnologia.id),
    );
  }

  Future<void> _consultarIa() async {
    final propuesta =
        await const PropuestaIa().desdeDescripcion(widget.negocio.descripcion);
    if (!mounted) return;
    setState(() {
      _consultandoIa = false;
      if (propuesta == null) {
        _notaIa = '';
        return;
      }
      _elegidos
        ..clear()
        ..addAll(propuesta.rubros);
      _atributosIa = propuesta.atributos;
      _aparienciaIa = propuesta.apariencia;
      _notaIa = 'La IA leyó tu descripción y propuso estos rubros. Podés corregirlos.';
    });
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
      _atributosIa = null;
      _aparienciaIa = null;
    });
  }

  String _datosProducto() {
    final datos = _atributosIa ?? _propuesta.atributos;
    if (datos.isEmpty) return 'nombre y precio';
    return datos.join(', ');
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
        apariencia: _apariencia,
        atributos: _atributosIa,
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
                      _consultandoIa
                          ? 'La IA está leyendo tu descripción para proponer el rubro y los datos de cada producto.'
                          : (_notaIa.isEmpty ? _textoDeteccion() : _notaIa),
                      style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                    if (!_consultandoIa &&
                        (_atributosIa ?? _propuesta.atributos).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'En cada producto vas a cargar: ${_datosProducto()}.',
                        style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
                      ),
                    ],
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
