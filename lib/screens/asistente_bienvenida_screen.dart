import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../backend/negocio_remoto.dart';
import '../backend/tienda_publica_remota.dart';
import '../data/apariencia_tienda.dart';
import '../data/paises_latam.dart';
import '../services/negocio_local.dart';
import '../services/propuesta_ia.dart';
import '../theme/app_theme.dart';
import '../utils/elegir_foto.dart';
import '../widgets/fondo_gexi.dart';
import '../widgets/selector_color_marca.dart';

/// Alta de una cuenta nueva: los datos del negocio, en un paso por vez.
class AsistenteBienvenidaScreen extends StatefulWidget {
  const AsistenteBienvenidaScreen({
    super.key,
    required this.negocio,
    required this.duenoEmail,
    required this.alActualizar,
    required this.alVolverAlInicio,
  });

  final NegocioLocal? negocio;
  final String duenoEmail;
  final ValueChanged<NegocioLocal> alActualizar;
  final VoidCallback alVolverAlInicio;

  @override
  State<AsistenteBienvenidaScreen> createState() =>
      _AsistenteBienvenidaScreenState();
}

class _AsistenteBienvenidaScreenState extends State<AsistenteBienvenidaScreen> {
  static const _pasos = 8;
  static const _ejemplosHorario = [
    'Lunes a Viernes de 9 a 18 hs',
    'Lunes a Sábado de 9 a 13 y de 17 a 21 hs',
    'Todos los días de 8 a 20 hs',
    'Solo con turno',
  ];

  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _whatsapp = TextEditingController();
  final _horario = TextEditingController();

  NegocioLocal? _negocio;
  late int _paso;
  String _pais = 'AR';
  String _moneda = 'ARS';
  final _elegidos = <String>{};
  AparienciaTienda _apariencia = const AparienciaTienda();
  AparienciaTienda? _aparienciaIa;
  List<String>? _atributosIa;
  Uint8List? _logoBytes;
  bool _guardando = false;
  bool _subiendoLogo = false;
  bool _consultandoIa = false;
  bool _rubroTocado = false;
  bool _colorTocado = false;
  String _descripcionConsultada = '\u0000';

  @override
  void initState() {
    super.initState();
    _negocio = widget.negocio;
    final negocio = _negocio;
    if (negocio != null) {
      _nombre.text = negocio.nombre;
      _descripcion.text = negocio.descripcion;
      _pais = negocio.pais.trim().isEmpty ? 'AR' : negocio.pais;
      _moneda = negocio.moneda.trim().isEmpty ? 'ARS' : negocio.moneda;
      _whatsapp.text = telefonoLocal(negocio.whatsapp, paisPorCodigo(_pais));
      _horario.text = negocio.horario;
      _elegidos.addAll(_idsDeRubros(negocio.rubros));
      _apariencia = negocio.apariencia;
      _colorTocado = negocio.apariencia.acentoHex.isNotEmpty;
    }
    _paso = negocio == null ? 0 : (negocio.configurado ? 4 : 3);
    if (_paso == 3) {
      _consultandoIa = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepararRubros();
      });
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _whatsapp.dispose();
    _horario.dispose();
    super.dispose();
  }

  PaisLatam get _paisActual => paisPorCodigo(_pais) ?? paisesLatam.first;

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _siguiente() async {
    if (_guardando || _subiendoLogo) return;
    switch (_paso) {
      case 0:
        if (_nombre.text.trim().isEmpty) {
          _avisar('Escribí el nombre del negocio.');
          return;
        }
        setState(() => _paso = 1);
      case 1:
        if (_descripcion.text.trim().isEmpty) {
          _avisar('Contanos a qué se dedica.');
          return;
        }
        setState(() => _paso = 2);
      case 2:
        final listo = await _guardarIdentidad();
        if (!listo || !mounted) return;
        setState(() => _paso = 3);
        _prepararRubros();
      case 3:
        final listo = await _confirmarRubros();
        if (!listo || !mounted) return;
        setState(() => _paso = 4);
      case 4:
        final listo = await _guardarWhatsapp();
        if (!listo || !mounted) return;
        setState(() => _paso = 5);
      case 5:
        setState(() => _paso = 6);
      case 6:
        final listo = await _guardarColor();
        if (!listo || !mounted) return;
        setState(() => _paso = 7);
      case 7:
        await _terminar();
    }
  }

  void _volver() {
    if (_guardando || _subiendoLogo) return;
    if (_paso == 0) {
      if (_negocio == null) widget.alVolverAlInicio();
      return;
    }
    setState(() => _paso -= 1);
  }

  Future<bool> _guardarIdentidad() async {
    setState(() => _guardando = true);
    try {
      final pais = _paisActual;
      final negocio = _negocio;
      final NegocioLocal? guardado;
      if (negocio == null) {
        guardado = await NegocioStore().crear(
          nombre: _nombre.text,
          descripcion: _descripcion.text,
          duenoEmail: widget.duenoEmail,
          moneda: _moneda,
          pais: pais.codigo,
          nacionalidad: pais.nacionalidad,
        );
      } else {
        guardado = await NegocioStore().guardarFicha(
          nombre: _nombre.text,
          descripcion: _descripcion.text,
          moneda: _moneda,
          pais: pais.codigo,
          nacionalidad: pais.nacionalidad,
        );
      }
      if (!mounted) return false;
      if (guardado == null) {
        _avisar('No se pudo guardar el negocio.');
        return false;
      }
      _negocio = guardado;
      widget.alActualizar(guardado);
      return true;
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar el negocio.');
      return false;
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _prepararRubros() async {
    final descripcion = _descripcion.text.trim();
    if (_elegidos.isEmpty) {
      _elegidos.addAll(PropuestaRubro.detectarIds(descripcion));
    }
    if (_descripcionConsultada == descripcion) return;
    _descripcionConsultada = descripcion;
    if (mounted) setState(() => _consultandoIa = true);
    final propuesta = await const PropuestaIa().desdeDescripcion(descripcion);
    if (!mounted) return;
    setState(() {
      _consultandoIa = false;
      if (propuesta == null || _rubroTocado) return;
      _elegidos
        ..clear()
        ..addAll(propuesta.rubros);
      _atributosIa = propuesta.atributos;
      _aparienciaIa = propuesta.apariencia;
    });
  }

  void _alternarRubro(String id) {
    setState(() {
      _rubroTocado = true;
      _atributosIa = null;
      _aparienciaIa = null;
      if (_elegidos.contains(id)) {
        _elegidos.remove(id);
      } else {
        _elegidos.add(id);
      }
    });
  }

  AparienciaTienda _aparienciaDeRubros() {
    final ids = _elegidos;
    return AparienciaTienda.paraRubros(
      gastronomiaSola:
          ids.length == 1 && ids.contains(CatalogoRubros.gastronomia.id),
      indumentaria: ids.contains(CatalogoRubros.indumentaria.id),
      tecnologia: ids.contains(CatalogoRubros.tecnologia.id),
    );
  }

  Future<bool> _confirmarRubros() async {
    if (_elegidos.isEmpty) {
      _avisar('Elegí al menos un rubro.');
      return false;
    }
    final negocio = _negocio;
    if (negocio == null) return false;
    setState(() => _guardando = true);
    try {
      final propuesta = PropuestaRubro.desdeIds(_elegidos);
      await NegocioStore().confirmar(
        negocio,
        propuesta,
        duenoEmail: widget.duenoEmail,
        apariencia: _colorTocado
            ? _apariencia
            : (_aparienciaIa ?? _aparienciaDeRubros()),
        atributos: _atributosIa,
        asistenteListo: false,
      );
      final guardado = await NegocioStore().leer();
      if (!mounted) return false;
      if (guardado == null || !guardado.configurado) {
        _avisar('No se pudo guardar la configuración.');
        return false;
      }
      _negocio = guardado;
      _apariencia = guardado.apariencia;
      widget.alActualizar(guardado);
      return true;
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar la configuración.');
      return false;
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<bool> _guardarWhatsapp() async {
    final numero = telefonoConPrefijo(_whatsapp.text, _paisActual);
    if (numero.length < 8) {
      _avisar('Ingresá el WhatsApp del negocio.');
      return false;
    }
    setState(() => _guardando = true);
    try {
      final guardado = await NegocioStore().guardarWhatsapp(numero);
      if (!mounted) return false;
      if (guardado == null) {
        _avisar('No se pudo guardar el WhatsApp.');
        return false;
      }
      _negocio = guardado;
      widget.alActualizar(guardado);
      return true;
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar el WhatsApp.');
      return false;
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<bool> _guardarColor() async {
    setState(() => _guardando = true);
    try {
      final guardado = await NegocioStore().guardarApariencia(_apariencia);
      if (!mounted) return false;
      if (guardado == null) {
        _avisar('No se pudo guardar el color.');
        return false;
      }
      _negocio = guardado;
      _apariencia = guardado.apariencia;
      _colorTocado = true;
      widget.alActualizar(guardado);
      return true;
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar el color.');
      return false;
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirPaleta(String id) async {
    final siguiente = _apariencia.copiar(paleta: id);
    setState(() {
      _apariencia = siguiente;
      _colorTocado = true;
    });
    final guardado = await NegocioStore().guardarApariencia(siguiente);
    if (!mounted || guardado == null) return;
    setState(() => _negocio = guardado);
    widget.alActualizar(guardado);
  }

  Future<void> _guardarAcentoHex(String hex) async {
    final siguiente = _apariencia.copiar(acentoHex: hex);
    setState(() {
      _apariencia = siguiente;
      _colorTocado = true;
    });
    final guardado = await NegocioStore().guardarApariencia(siguiente);
    if (!mounted || guardado == null) return;
    setState(() => _negocio = guardado);
    widget.alActualizar(guardado);
  }

  Future<void> _elegirLogo() async {
    final negocio = _negocio;
    if (negocio == null || _subiendoLogo) return;
    final origen = await preguntarOrigenFoto(context);
    if (origen == null || !mounted) return;
    final archivos = await elegirFotos(
      origen: origen,
      variasEnGaleria: false,
      maxWidth: 800,
      imageQuality: 55,
    );
    if (archivos.isEmpty || !mounted) return;
    final bytes = await archivos.first.readAsBytes();
    if (!mounted) return;
    if (!_esJpegOPng(archivos.first.name, bytes)) {
      _avisar('Usá un JPEG o un PNG.');
      return;
    }
    setState(() => _logoBytes = bytes);
    final id = const NegocioRemoto().idParaSesion(negocio);
    if (id == null) {
      _avisar('Iniciá sesión para subir el logo.');
      return;
    }
    setState(() => _subiendoLogo = true);
    try {
      final url = await const TiendaPublicaRemota().subirLogo(
        negocioId: id,
        bytes: bytes,
      );
      final guardado = await NegocioStore().guardarLogo(url);
      if (!mounted) return;
      if (guardado != null) {
        _negocio = guardado;
        widget.alActualizar(guardado);
      }
    } on StateError catch (error) {
      if (!mounted) return;
      _avisar(error.message);
    } catch (_) {
      if (mounted) _avisar('No se pudo subir el logo.');
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _quitarLogo() async {
    final negocio = _negocio;
    if (negocio == null || _subiendoLogo || negocio.logoUrl.isEmpty) return;
    setState(() => _subiendoLogo = true);
    try {
      final id = const NegocioRemoto().idParaSesion(negocio);
      if (id != null) await const TiendaPublicaRemota().quitarLogo(id);
      final guardado = await NegocioStore().guardarLogo('');
      if (!mounted) return;
      setState(() => _logoBytes = null);
      if (guardado != null) {
        _negocio = guardado;
        widget.alActualizar(guardado);
      }
    } catch (_) {
      if (mounted) _avisar('No se pudo quitar el logo.');
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _terminar() async {
    setState(() => _guardando = true);
    try {
      final guardado = await NegocioStore().guardarHorario(
        _horario.text,
        cerrarAsistente: true,
      );
      if (!mounted) return;
      if (guardado == null || guardado.asistenteListo != true) {
        _avisar('No se pudo guardar el horario.');
        return;
      }
      widget.alActualizar(guardado);
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar el horario.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ultimo = _paso == _pasos - 1;
    final ocupado = _guardando || _subiendoLogo;
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: FondoGexi(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BarraBienvenida(),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ChipPaso(actual: _paso + 1, total: _pasos),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_paso + 1) / _pasos,
                    minHeight: 6,
                    backgroundColor: AppColors.linea,
                    color: AppColors.primario,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                    decoration: AppColors.tarjeta,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        if (_paso != 5) ...[
                          _IconoPaso(
                            icono: _iconoPaso(_paso),
                            color: _paso == 6
                                ? _apariencia.acento
                                : AppColors.primario,
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          _tituloPaso(_paso),
                          style: tema.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_subtituloPaso(_paso) != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _subtituloPaso(_paso)!,
                            style: tema.textTheme.bodyMedium?.copyWith(
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _contenido(tema),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: ocupado || (_paso == 0 && _negocio != null)
                            ? null
                            : _volver,
                        child: const Text('Volver'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: ocupado ? null : _siguiente,
                        child: Text(
                          ocupado
                              ? 'Guardando...'
                              : ultimo
                                  ? 'Empezar'
                                  : 'Siguiente',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(ThemeData tema) {
    switch (_paso) {
      case 0:
        return TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nombre del negocio',
            hintText: 'Novaceltec',
          ),
        );
      case 1:
        return TextField(
          controller: _descripcion,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: '¿A qué se dedica?',
            hintText: 'Vendo celulares, fundas y accesorios',
            alignLabelWithHint: true,
          ),
        );
      case 2:
        return Column(
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('pais-$_pais'),
              initialValue: _pais,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Nacionalidad'),
              items: [
                for (final opcion in paisesLatam)
                  DropdownMenuItem(
                    value: opcion.codigo,
                    child: Text(opcion.etiquetaNacionalidad),
                  ),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) {
                      final elegido = paisPorCodigo(valor);
                      if (elegido == null) return;
                      setState(() {
                        _pais = elegido.codigo;
                        _moneda = elegido.moneda;
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('moneda-$_moneda'),
              initialValue: _moneda,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Moneda'),
              items: [
                for (final opcion in monedasParaElegir())
                  DropdownMenuItem(
                    value: opcion.moneda,
                    child: Text(opcion.etiquetaMoneda),
                  ),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) {
                      if (valor == null) return;
                      setState(() => _moneda = valor);
                    },
            ),
          ],
        );
      case 3:
        final datos =
            _atributosIa ?? PropuestaRubro.desdeIds(_elegidos).atributos;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_consultandoIa)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rubro in CatalogoRubros.todos)
                  FilterChip(
                    label: Text(rubro.nombre),
                    selected: _elegidos.contains(rubro.id),
                    onSelected:
                        _guardando ? null : (_) => _alternarRubro(rubro.id),
                    showCheckmark: true,
                    selectedColor: AppColors.primario,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: _elegidos.contains(rubro.id)
                          ? Colors.white
                          : AppColors.texto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (!_consultandoIa && datos.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'En cada producto: ${datos.join(', ')}.',
                style: tema.textTheme.bodyMedium,
              ),
            ],
          ],
        );
      case 4:
        final pais = _paisActual;
        return TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-]')),
          ],
          decoration: InputDecoration(
            hintText: pais.ejemplo,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _bandera(pais.codigo),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pais.prefijo,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case 5:
        final url = _negocio?.logoUrl ?? '';
        return Column(
          children: [
            _VistaLogo(
              nombre: _nombre.text,
              url: url,
              bytes: _logoBytes,
              color: _apariencia.acento,
              cargando: _subiendoLogo,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _subiendoLogo ? null : _elegirLogo,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_subiendoLogo ? 'Subiendo...' : 'Elegir logo'),
            ),
            if (url.isNotEmpty)
              TextButton(
                onPressed: _subiendoLogo ? null : _quitarLogo,
                child: const Text('Quitar logo'),
              ),
          ],
        );
      case 6:
        return SelectorColorMarca(
          apariencia: _apariencia,
          onPaleta: _elegirPaleta,
          onAcentoHex: _guardarAcentoHex,
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _horario,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Horario de atención',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ejemplo in _ejemplosHorario)
                  FilterChip(
                    label: Text(ejemplo),
                    selected: _horario.text.trim() == ejemplo,
                    onSelected: (_) {
                      _horario.text = ejemplo;
                      setState(() {});
                    },
                    selectedColor: AppColors.limaBrillo,
                    showCheckmark: false,
                    labelStyle: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        );
    }
  }
}

class _BarraBienvenida extends StatelessWidget {
  const _BarraBienvenida();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppColors.degradadoBarra,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        '¡Bienvenido!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _ChipPaso extends StatelessWidget {
  const _ChipPaso({required this.actual, required this.total});

  final int actual;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.limaBrillo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'PASO $actual DE $total',
        style: const TextStyle(
          color: AppColors.primario,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _IconoPaso extends StatelessWidget {
  const _IconoPaso({required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icono, color: color, size: 30),
    );
  }
}

class _VistaLogo extends StatelessWidget {
  const _VistaLogo({
    required this.nombre,
    required this.url,
    required this.bytes,
    required this.color,
    required this.cargando,
  });

  final String nombre;
  final String url;
  final Uint8List? bytes;
  final Color color;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final inicial =
        nombre.trim().isEmpty ? 'G' : nombre.trim()[0].toUpperCase();
    final marca = Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        inicial,
        style: TextStyle(
          color: color,
          fontSize: 42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    Widget imagen = marca;
    final memoria = bytes;
    if (memoria != null && memoria.isNotEmpty) {
      imagen = ClipOval(
        child: Image.memory(
          memoria,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => marca,
        ),
      );
    } else if (url.trim().isNotEmpty) {
      imagen = ClipOval(
        child: Image.network(
          url,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => marca,
        ),
      );
    }
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          imagen,
          if (cargando)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
        ],
      ),
    );
  }
}

IconData _iconoPaso(int paso) {
  switch (paso) {
    case 0:
      return Icons.storefront_rounded;
    case 1:
      return Icons.work_outline_rounded;
    case 2:
      return Icons.public_rounded;
    case 3:
      return Icons.category_rounded;
    case 4:
      return FontAwesomeIcons.whatsapp;
    case 6:
      return Icons.palette_outlined;
    default:
      return Icons.schedule_rounded;
  }
}

String _tituloPaso(int paso) {
  switch (paso) {
    case 0:
      return '¿Cómo se llama tu negocio?';
    case 1:
      return '¿A qué te dedicás?';
    case 2:
      return '¿De dónde es tu negocio?';
    case 3:
      return '¿Qué vendés?';
    case 4:
      return '¿Cuál es tu WhatsApp?';
    case 5:
      return 'Subí el logo';
    case 6:
      return '¿Qué color identifica a tu marca?';
    default:
      return '¿Cuáles son tus horarios de atención?';
  }
}

String? _subtituloPaso(int paso) {
  switch (paso) {
    case 4:
      return 'El número del negocio. Lo podés cambiar después.';
    case 5:
      return 'JPEG o PNG. Es el mismo de tu página.';
    case 6:
      return 'Se usa en los botones y en la tienda.';
    default:
      return null;
  }
}

String _bandera(String codigo) {
  final limpio = codigo.trim().toUpperCase();
  if (limpio.length != 2) return '🇦🇷';
  final a = limpio.codeUnitAt(0);
  final b = limpio.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '🇦🇷';
  return String.fromCharCodes([a + 0x1F1E6 - 0x41, b + 0x1F1E6 - 0x41]);
}

bool _esJpegOPng(String nombre, Uint8List bytes) {
  final bajo = nombre.toLowerCase();
  if (bajo.endsWith('.jpg') ||
      bajo.endsWith('.jpeg') ||
      bajo.endsWith('.png')) {
    return true;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return true;
  }
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

List<String> _idsDeRubros(List<String> guardados) {
  final ids = <String>[];
  for (final texto in guardados) {
    for (final rubro in CatalogoRubros.todos) {
      if (rubro.id == texto || rubro.nombre == texto) {
        if (!ids.contains(rubro.id)) ids.add(rubro.id);
      }
    }
  }
  return ids;
}
