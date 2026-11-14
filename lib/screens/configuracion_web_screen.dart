import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/elegir_foto.dart';

import '../data/apariencia_tienda.dart';
import '../data/diseno_tienda.dart';
import '../data/funciones_asistente.dart';
import '../data/paises_latam.dart';
import '../services/propuesta_ia.dart';
import '../backend/negocio_remoto.dart';
import '../backend/tienda_publica_remota.dart';
import '../data/app_database.dart';
import '../services/negocio_local.dart';
import '../services/subdominio_tienda.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';
import '../widgets/buscador_lugar.dart';
import '../widgets/selector_color_marca.dart';
import 'tienda_publica_screen.dart';

class ConfiguracionWebScreen extends StatefulWidget {
  const ConfiguracionWebScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<ConfiguracionWebScreen> createState() => _ConfiguracionWebScreenState();
}

class _ConfiguracionWebScreenState extends State<ConfiguracionWebScreen> {
  final _slug = TextEditingController();
  final _whatsapp = TextEditingController();
  final _alias = TextEditingController();
  final _mensaje = TextEditingController();
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();
  final _maps = TextEditingController();
  double? _lat;
  double? _lng;
  final _pedidoDiseno = TextEditingController();
  final _banner = TextEditingController();
  final _bannerFoco = FocusNode();
  final _store = NegocioStore();
  AparienciaTienda _apariencia = const AparienciaTienda();
  DisenoTienda _presentacion = const DisenoTienda();
  FuncionesAsistente _funciones = const FuncionesAsistente();
  bool _bannerSucio = false;
  Future<void> _colaDiseno = Future<void>.value();
  bool _ajustando = false;

  NegocioLocal? _negocio;
  bool _tiendaActiva = false;
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoLogo = false;
  bool _intentoPublicar = false;
  bool _slugConCodigo = false;

  @override
  void initState() {
    super.initState();
    _slug.addListener(_actualizarVista);
    _whatsapp.addListener(_actualizarVista);
    _bannerFoco.addListener(_alSalirDelBanner);
    _cargar();
  }

  @override
  void dispose() {
    _slug
      ..removeListener(_actualizarVista)
      ..dispose();
    _whatsapp
      ..removeListener(_actualizarVista)
      ..dispose();
    _alias.dispose();
    _mensaje.dispose();
    _facebook.dispose();
    _instagram.dispose();
    _maps.dispose();
    _pedidoDiseno.dispose();
    _bannerFoco
      ..removeListener(_alSalirDelBanner)
      ..dispose();
    _banner.dispose();
    super.dispose();
  }

  void _actualizarVista() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar() async {
    final negocio = await _store.leer();
    if (!mounted) return;
    if (negocio != null) {
      _negocio = negocio;
      final propuesto = negocio.slug.isEmpty
          ? SubdominioTienda.sugerirSlug(negocio.nombre)
          : negocio.slug;
      try {
        final libre = await _direccionLibre(negocio, propuesto);
        _slugConCodigo = libre != propuesto;
        _slug.text = libre;
      } catch (_) {
        _slug.text = propuesto;
      }
      _whatsapp.text = telefonoLocal(
        negocio.whatsapp,
        paisPorCodigo(negocio.pais),
      );
      _mensaje.text = negocio.mensajePublico;
      _alias.text = negocio.aliasCobro;
      _facebook.text = negocio.facebookUrl;
      _instagram.text = negocio.instagramUrl;
      _maps.text = negocio.mapsUrl;
      _lat = negocio.latitud;
      _lng = negocio.longitud;
      _tiendaActiva = negocio.tiendaActiva;
      _apariencia = negocio.apariencia;
      _presentacion = negocio.diseno;
      _funciones = negocio.funciones;
      _banner.text = _presentacion.bannerTexto;
      _bannerSucio = false;
    }
    if (!mounted) return;
    setState(() => _cargando = false);
  }

  String get _slugActual => _slug.text.trim();
  String get _whatsappActual => telefonoConPrefijo(
        _whatsapp.text,
        paisPorCodigo(_negocio?.pais),
      );
  String get _url => SubdominioTienda.urlPublica(_slugActual);
  String? get _errorSlug => SubdominioTienda.validarSlug(_slugActual);
  bool get _whatsappValido => _whatsappActual.length >= 8;

  Future<String> _direccionLibre(NegocioLocal negocio, String propuesto) async {
    final pedido = propuesto.trim().toLowerCase();
    if (pedido.isEmpty) return pedido;
    final id = const NegocioRemoto().idParaSesion(negocio);
    if (id == null) return pedido;
    const remoto = TiendaPublicaRemota();
    final tomado = await remoto.slugLoUsaOtro(slug: pedido, negocioId: id);
    if (!tomado) return pedido;
    final alterno = SubdominioTienda.slugConCodigo(pedido, negocio.codigo);
    if (alterno == pedido ||
        await remoto.slugLoUsaOtro(slug: alterno, negocioId: id)) {
      throw StateError(
        'Esa dirección ya la usa otro negocio. Elegí otro nombre.',
      );
    }
    return alterno;
  }

  Future<void> _copiarUrl() async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dirección copiada')),
    );
  }

  Future<void> _guardar() async {
    if (_guardando || _negocio == null) return;
    setState(() => _intentoPublicar = _tiendaActiva);

    if (_tiendaActiva && (_errorSlug != null || !_whatsappValido)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisá la dirección y el WhatsApp antes de publicar.',
          ),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final avisoCodigo = await _persistirPagina(_tiendaActiva);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            avisoCodigo
                ? 'Ese nombre ya lo usa otro negocio. La dirección quedó con tu código.'
                : _tiendaActiva
                    ? 'Página publicada'
                    : 'Página oculta',
          ),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la página.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarPublicacion(bool valor) async {
    if (_guardando || _negocio == null || valor == _tiendaActiva) return;
    if (valor && (_errorSlug != null || !_whatsappValido)) {
      setState(() => _intentoPublicar = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisá la dirección y el WhatsApp antes de publicar.',
          ),
        ),
      );
      return;
    }

    final anterior = _tiendaActiva;
    setState(() {
      _tiendaActiva = valor;
      _guardando = true;
      if (!valor) _intentoPublicar = false;
    });
    try {
      await _persistirPagina(valor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(valor ? 'Página publicada' : 'Página oculta'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _tiendaActiva = anterior);
      final mensaje = error is StateError && error.message.isNotEmpty
          ? error.message
          : valor
              ? 'No se pudo publicar. La página sigue oculta.'
              : 'No se pudo ocultar. La página sigue publicada.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Guarda en el teléfono y espera a que la página pública quede igual.
  Future<bool> _persistirPagina(bool activa) async {
    if (_bannerSucio) {
      _guardarPresentacion(_presentacion);
    }
    await _colaDiseno.catchError((Object _) {});
    final anterior = _negocio!;
    var avisoCodigo = false;
    final libre = await _direccionLibre(anterior, _slugActual);
    if (libre != _slugActual) {
      _slug.text = libre;
      _slugConCodigo = true;
      avisoCodigo = true;
    }
    final guardado = await _store.guardarPagina(
      slug: _slug.text.trim(),
      tiendaActiva: activa,
      whatsapp: _whatsappActual,
      mensajePublico: _mensaje.text.trim(),
      aliasCobro: _alias.text.trim(),
      facebookUrl: _facebook.text.trim(),
      instagramUrl: _instagram.text.trim(),
      mapsUrl: _maps.text.trim(),
      latitud: _lat,
      longitud: _lng,
    );
    if (guardado == null) {
      throw StateError('No hay un negocio para configurar.');
    }
    _negocio = guardado;
    final negocioId = const NegocioRemoto().idParaSesion(guardado);
    if (negocioId == null) {
      await _restaurarPagina(anterior);
      throw StateError('Iniciá sesión para que el cambio llegue a la página.');
    }
    try {
      await const TiendaPublicaRemota().guardarConfig(
        negocioId: negocioId,
        slug: _slug.text.trim(),
        tiendaActiva: activa,
        whatsapp: _whatsappActual,
        mensajePublico: _mensaje.text.trim(),
        aliasCobro: _alias.text.trim(),
        facebookUrl: _facebook.text.trim(),
        instagramUrl: _instagram.text.trim(),
        mapsUrl: _maps.text.trim(),
        latitud: _lat,
        longitud: _lng,
      );
    } catch (error) {
      await _restaurarPagina(anterior);
      if (error is StateError) rethrow;
      throw StateError('No se pudo guardar la página.');
    }
    return avisoCodigo;
  }

  Future<void> _restaurarPagina(NegocioLocal anterior) async {
    final restaurado = await _store.guardarPagina(
      slug: anterior.slug,
      tiendaActiva: anterior.tiendaActiva,
      whatsapp: anterior.whatsapp,
      mensajePublico: anterior.mensajePublico,
      aliasCobro: anterior.aliasCobro,
      facebookUrl: anterior.facebookUrl,
      instagramUrl: anterior.instagramUrl,
      mapsUrl: anterior.mapsUrl,
      latitud: anterior.latitud,
      longitud: anterior.longitud,
    );
    _negocio = restaurado ?? anterior;
    _tiendaActiva = (_negocio ?? anterior).tiendaActiva;
  }

  Future<void> _guardarFunciones(FuncionesAsistente siguiente) async {
    setState(() => _funciones = siguiente);
    try {
      await _enSerie(() async {
        final guardado = await _store.guardarFunciones(siguiente);
        if (guardado != null) {
          _negocio = guardado;
          _funciones = guardado.funciones;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el asistente.')),
      );
    }
  }

  Future<void> _fijarApariencia(AparienciaTienda siguiente) async {
    setState(() => _apariencia = siguiente);
    try {
      await _enSerie(() async {
        final guardado = await _store.guardarApariencia(siguiente);
        if (guardado != null) _negocio = guardado;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el diseño.')),
      );
    }
  }

  Future<void> _enSerie(Future<void> Function() accion) {
    final pendiente =
        _colaDiseno.catchError((Object _) {}).then((_) => accion());
    _colaDiseno = pendiente;
    return pendiente;
  }

  void _alSalirDelBanner() {
    if (!mounted || _bannerFoco.hasFocus || !_bannerSucio) return;
    _guardarPresentacion(_presentacion.copiar(bannerTexto: _banner.text));
  }

  Future<void> _guardarPresentacion(DisenoTienda siguiente) async {
    final texto = _banner.text.trim();
    final pedido = siguiente.copiar(bannerTexto: texto);
    try {
      pedido.validar();
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    if (!_bannerFoco.hasFocus && _banner.text != texto) {
      _banner.text = texto;
    }
    setState(() => _presentacion = pedido);
    try {
      await _enSerie(() async {
        final guardado = await _store.guardarDiseno(pedido);
        if (guardado != null) _negocio = guardado;
        _bannerSucio = false;
      });
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el diseño.')),
      );
    }
  }

  Future<void> _pedirDiseno() async {
    final pedido = _pedidoDiseno.text.trim();
    if (pedido.isEmpty || _ajustando) return;
    setState(() => _ajustando = true);
    try {
      final siguiente = await const PropuestaIa().ajustarDiseno(
        actual: _apariencia,
        pedido: pedido,
      );
      if (!mounted) return;
      if (siguiente == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ese pedido no entra en las opciones de color, forma, botón o portada.',
            ),
          ),
        );
        return;
      }
      _pedidoDiseno.clear();
      await _fijarApariencia(siguiente);
    } finally {
      if (mounted) setState(() => _ajustando = false);
    }
  }

  Future<void> _elegirLogo() async {
    final negocio = _negocio;
    if (negocio == null || _subiendoLogo || _guardando) return;
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
    final id = const NegocioRemoto().idParaSesion(negocio);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para subir el logo.')),
      );
      return;
    }
    setState(() => _subiendoLogo = true);
    try {
      final url = await const TiendaPublicaRemota().subirLogo(
        negocioId: id,
        bytes: bytes,
      );
      final guardado = await _store.guardarLogo(url);
      if (!mounted) return;
      if (guardado != null) _negocio = guardado;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo guardado')),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo subir el logo.')),
      );
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _quitarLogo() async {
    final negocio = _negocio;
    if (negocio == null || _subiendoLogo || negocio.logoUrl.isEmpty) return;
    final id = const NegocioRemoto().idParaSesion(negocio);
    setState(() => _subiendoLogo = true);
    try {
      if (id != null) {
        await const TiendaPublicaRemota().quitarLogo(id);
      }
      final guardado = await _store.guardarLogo('');
      if (!mounted) return;
      if (guardado != null) _negocio = guardado;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo quitar el logo.')),
      );
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  void _verPagina() {
    if (_errorSlug != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elegí una dirección válida para ver la página.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TiendaPublicaScreen(
          slug: _slugActual,
          database: widget.database,
        ),
      ),
    );
  }

  Widget _seccionAsistente(ThemeData tema) {
    return _Seccion(
      titulo: 'Asistente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estas funciones las usa el asistente del negocio. Si apagás una, no la ofrece.',
            style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            'Se guarda en tu cuenta, junto con el diseño de la página.',
            style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          _interruptorPresentacion(
            titulo: 'Consultar stock',
            detalle:
                'Responde cuánto queda de un producto, con los datos de este dispositivo.',
            valor: _funciones.consultarStock,
            onChanged: (valor) => _guardarFunciones(
              _funciones.copiar(consultarStock: valor),
            ),
          ),
          _interruptorPresentacion(
            titulo: 'Anotar pedido o venta',
            detalle: 'Arma la venta y recién la guarda cuando confirmás.',
            valor: _funciones.anotarVenta,
            onChanged: (valor) => _guardarFunciones(
              _funciones.copiar(anotarVenta: valor),
            ),
          ),
          _interruptorPresentacion(
            titulo: 'Horario y dirección',
            detalle:
                'Dice el horario y la dirección del local si ya los cargaste.',
            valor: _funciones.horarioDireccion,
            onChanged: (valor) => _guardarFunciones(
              _funciones.copiar(horarioDireccion: valor),
            ),
          ),
          _interruptorPresentacion(
            titulo: 'Ventas de hoy',
            detalle: 'Resume lo vendido hoy, sin consultar a la IA.',
            valor: _funciones.ventasHoy,
            onChanged: (valor) => _guardarFunciones(
              _funciones.copiar(ventasHoy: valor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionPresentacion(ThemeData tema) {
    final rubros = _negocio?.rubros ?? const <String>[];
    final sugiere = _nombrePlantilla(
      DisenoTienda.desdeRubros(rubros).plantillaId,
    );
    final intro = rubros.isEmpty
        ? 'Elegí cómo se muestra la tienda. Sin un rubro cargado, te proponemos $sugiere. Podés elegir otra presentación.'
        : rubros.length > 1
            ? 'Elegí cómo se muestra la tienda. Según tus rubros te proponemos $sugiere. Podés elegir otra presentación.'
            : 'Elegí cómo se muestra la tienda. Según tu rubro te proponemos $sugiere. Podés elegir otra presentación.';
    final bloqueada = _guardando;
    return _Seccion(
      titulo: 'Presentación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(intro, style: tema.textTheme.bodySmall?.copyWith(height: 1.35)),
          const SizedBox(height: 8),
          Text(
            'Se guarda en tu cuenta junto con el resto del diseño.',
            style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 14),
          Text('Plantilla', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in DisenoTienda.plantillas)
                ChoiceChip(
                  label: Text(_nombrePlantilla(id)),
                  selected: _presentacion.plantillaId == id,
                  onSelected: bloqueada
                      ? null
                      : (_) => _guardarPresentacion(
                            DisenoTienda.dePlantilla(id).copiar(
                              bannerTexto: _presentacion.bannerTexto,
                            ),
                          ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Fondo', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in DisenoTienda.fondos)
                ChoiceChip(
                  label: Text(_nombreFondo(id)),
                  selected: _presentacion.fondo == id,
                  onSelected: bloqueada
                      ? null
                      : (_) => _guardarPresentacion(
                            _presentacion.copiar(fondo: id),
                          ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Columnas', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final cantidad in const [1, 2, 3])
                ChoiceChip(
                  label: Text('$cantidad'),
                  selected: _presentacion.columnas == cantidad,
                  onSelected: bloqueada
                      ? null
                      : (_) => _guardarPresentacion(
                            _presentacion.copiar(columnas: cantidad),
                          ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cuántas columnas de productos se ven en la tienda.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text('Qué se ve', style: tema.textTheme.titleSmall),
          _interruptorPresentacion(
            titulo: 'Buscador',
            detalle: 'El visitante busca por nombre.',
            valor: _presentacion.mostrarBuscador,
            onChanged: (valor) => _guardarPresentacion(
              _presentacion.copiar(mostrarBuscador: valor),
            ),
          ),
          _interruptorPresentacion(
            titulo: 'Filtros',
            detalle: 'El visitante filtra por categoría.',
            valor: _presentacion.mostrarFiltros,
            onChanged: (valor) => _guardarPresentacion(
              _presentacion.copiar(mostrarFiltros: valor),
            ),
          ),
          _interruptorPresentacion(
            titulo: 'Horario',
            detalle: 'Se ve el horario de atención.',
            valor: _presentacion.mostrarHorario,
            onChanged: (valor) => _guardarPresentacion(
              _presentacion.copiar(mostrarHorario: valor),
            ),
          ),
          _interruptorPresentacion(
            titulo: 'Redes',
            detalle:
                'Se ven Facebook, Instagram y Cómo llegar, si los cargaste.',
            valor: _presentacion.mostrarRedes,
            onChanged: (valor) => _guardarPresentacion(
              _presentacion.copiar(mostrarRedes: valor),
            ),
          ),
          _interruptorPresentacion(
            titulo: 'WhatsApp',
            detalle: 'Se ve el botón para pedir.',
            valor: _presentacion.mostrarWhatsapp,
            onChanged: (valor) => _guardarPresentacion(
              _presentacion.copiar(mostrarWhatsapp: valor),
            ),
          ),
          _interruptorPresentacion(
            titulo: 'Banner',
            detalle: 'Una franja corta arriba de los productos.',
            valor: _presentacion.mostrarBanner,
            onChanged: (valor) => _guardarPresentacion(
              _presentacion.copiar(mostrarBanner: valor),
            ),
          ),
          if (_presentacion.mostrarBanner) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _banner,
              focusNode: _bannerFoco,
              enabled: !bloqueada,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Texto del banner',
                hintText: 'Hoy 2x1 en empanadas',
                helperText: 'Una frase corta, de hasta 120 caracteres.',
              ),
              onChanged: (valor) {
                _bannerSucio = true;
                _presentacion = _presentacion.copiar(bannerTexto: valor);
              },
            ),
            const SizedBox(height: 8),
            Text('Estilo del banner', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in DisenoTienda.estilosBanner)
                  ChoiceChip(
                    label: Text(_nombreEstilo(id)),
                    selected: _presentacion.bannerEstilo == id,
                    onSelected: bloqueada
                        ? null
                        : (_) => _guardarPresentacion(
                              _presentacion.copiar(bannerEstilo: id),
                            ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _interruptorPresentacion({
    required String titulo,
    required String detalle,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(titulo),
      subtitle: Text(detalle),
      value: valor,
      activeTrackColor: AppColors.lima,
      onChanged: _guardando ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildLightTheme(),
      child: Scaffold(
        backgroundColor: AppColors.fondoClaro,
        appBar: AppBar(title: const Text('Tu página web')),
        body: FondoGexi(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _contenido(context),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context) {
    final tema = Theme.of(context);
    if (_negocio == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Primero creá o vinculá un negocio para configurar su página.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 +
            MediaQuery.paddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        Text(
          'Configurá cómo encuentran y contactan a ${_negocio!.nombre}.',
          style: tema.textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 20),
        _Tarjeta(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _tiendaActiva
                      ? AppColors.limaBrillo
                      : const Color(0xFFF1F3F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _tiendaActiva
                      ? Icons.public_rounded
                      : Icons.visibility_off_rounded,
                  color: _tiendaActiva ? AppColors.lima : AppColors.textoSuave,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Página publicada',
                      style: tema.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tiendaActiva
                          ? 'Publicada: tus clientes pueden verla.'
                          : 'Oculta: solo vos podés revisarla.',
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _tiendaActiva,
                activeTrackColor: AppColors.lima,
                onChanged: _guardando ? null : _cambiarPublicacion,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Seccion(
          titulo: 'Dirección',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _slug,
                enabled: !_guardando,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: 'Dirección de tu negocio',
                  hintText: 'novaceltec',
                  prefixIcon: const Icon(Icons.link_rounded),
                  errorText: _intentoPublicar ? _errorSlug : null,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.limaBrillo,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _url,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _copiarUrl,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copiar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _slugConCodigo
                    ? 'Otro negocio ya usa ese nombre, así que se agregó el código único de tu negocio.'
                    : 'Esa es la dirección pública. “Ver mi página” muestra la vista del cliente.',
                style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Seccion(
          titulo: 'Pedidos',
          child: Column(
            children: [
              TextField(
                controller: _whatsapp,
                enabled: !_guardando,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'WhatsApp que recibe los pedidos',
                  hintText:
                      paisPorCodigo(_negocio?.pais)?.ejemplo ?? '11 2345-6789',
                  prefixIcon: const Icon(Icons.chat_rounded),
                  prefixText: paisPorCodigo(_negocio?.pais) == null
                      ? null
                      : '${paisPorCodigo(_negocio?.pais)!.prefijo} ',
                  helperText: paisPorCodigo(_negocio?.pais) == null
                      ? 'Elegí la nacionalidad en Cambiar de moneda.'
                      : '${paisPorCodigo(_negocio?.pais)!.nombre}: característica ${paisPorCodigo(_negocio?.pais)!.prefijo}.',
                  errorText: _intentoPublicar && !_whatsappValido
                      ? 'Ingresá al menos 8 dígitos.'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _alias,
                enabled: !_guardando,
                maxLength: 40,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'CBU, CVU o alias',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                  helperText:
                      'El visitante lo copia al pedir y puede adjuntar el comprobante.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Seccion(
          titulo: 'Redes y ubicación',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Opcional. Si los cargás, en la página aparecen Facebook, Instagram y Cómo llegar.',
                style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _facebook,
                enabled: !_guardando,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 400,
                decoration: const InputDecoration(
                  labelText: 'Enlace de Facebook',
                  hintText: 'https://facebook.com/tunegocio',
                  prefixIcon: Icon(Icons.facebook_rounded),
                  helperText: 'Pegá el enlace completo de la página.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _instagram,
                enabled: !_guardando,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 400,
                decoration: const InputDecoration(
                  labelText: 'Enlace de Instagram',
                  hintText: 'https://instagram.com/tunegocio',
                  prefixIcon: Icon(Icons.camera_alt_outlined),
                  helperText: 'Pegá el enlace completo del perfil.',
                ),
              ),
              const SizedBox(height: 8),
              BuscadorLugar(
                controller: _maps,
                habilitado: !_guardando,
                onElegido: (lugar) {
                  _lat = lugar.lat;
                  _lng = lugar.lng;
                },
                onCambioManual: () {
                  _lat = null;
                  _lng = null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Seccion(
          titulo: 'Portada',
          child: TextField(
            controller: _mensaje,
            enabled: !_guardando,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Mensaje de portada (opcional)',
              hintText: 'Todo lo que necesitás, en un solo lugar.',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Seccion(
          titulo: 'Logo del negocio',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se muestra arriba del nombre en la página. Si no elegís uno, se ve la inicial del negocio.',
                style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _VistaLogo(
                    nombre: _negocio!.nombre,
                    url: _negocio!.logoUrl,
                    color: _apariencia.acento,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _guardando || _subiendoLogo ? null : _elegirLogo,
                          icon: _subiendoLogo
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _subiendoLogo ? 'Subiendo...' : 'Elegir logo',
                          ),
                        ),
                        if (_negocio!.logoUrl.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _guardando || _subiendoLogo
                                ? null
                                : _quitarLogo,
                            child: const Text('Quitar logo'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Seccion(
          titulo: 'Diseño de la página',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elegí entre opciones armadas. El cambio se guarda en tu cuenta y vuelve si cambiás de teléfono.',
                style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 14),
              Text('Color', style: tema.textTheme.titleSmall),
              const SizedBox(height: 8),
              SelectorColorMarca(
                apariencia: _apariencia,
                habilitado: !_guardando,
                permitirHex: true,
                onPaleta: (id) =>
                    _fijarApariencia(_apariencia.copiar(paleta: id)),
                onAcentoHex: (hex) =>
                    _fijarApariencia(_apariencia.copiar(acentoHex: hex)),
              ),
              const SizedBox(height: 14),
              Text('Forma', style: tema.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final id in AparienciaTienda.formas)
                    ChoiceChip(
                      label: Text(AparienciaTienda.nombreForma(id)),
                      selected: _apariencia.forma == id,
                      onSelected: _guardando
                          ? null
                          : (_) =>
                              _fijarApariencia(_apariencia.copiar(forma: id)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Botón del pedido', style: tema.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final id in AparienciaTienda.botones)
                    ChoiceChip(
                      label: Text(id),
                      selected: _apariencia.boton == id,
                      onSelected: _guardando
                          ? null
                          : (_) =>
                              _fijarApariencia(_apariencia.copiar(boton: id)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Portada', style: tema.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final id in AparienciaTienda.portadas)
                    ChoiceChip(
                      label: Text(AparienciaTienda.nombrePortada(id)),
                      selected: _apariencia.portada == id,
                      onSelected: _guardando
                          ? null
                          : (_) =>
                              _fijarApariencia(_apariencia.copiar(portada: id)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pedidoDiseno,
                enabled: !_ajustando && !_guardando,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Pedile un cambio a la IA',
                  hintText: 'Quiero la página negra y el botón Consultar',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _ajustando || _guardando ? null : _pedirDiseno,
                icon: _ajustando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_ajustando ? 'Revisando...' : 'Aplicar sugerencia'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _seccionAsistente(tema),
        const SizedBox(height: 16),
        _seccionPresentacion(tema),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: const Icon(Icons.save_rounded),
          label: Text(_guardando ? 'Guardando...' : 'Guardar'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _guardando ? null : _verPagina,
          icon: const Icon(Icons.storefront_rounded),
          label: const Text('Ver mi página'),
        ),
      ],
    );
  }
}

class _VistaLogo extends StatelessWidget {
  const _VistaLogo({
    required this.nombre,
    required this.url,
    required this.color,
  });

  final String nombre;
  final String url;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final inicial =
        nombre.trim().isEmpty ? 'G' : nombre.trim()[0].toUpperCase();
    final marca = Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        inicial,
        style: TextStyle(
          color: color,
          fontSize: 30,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (url.trim().isEmpty) return marca;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => marca,
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

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

String _nombrePlantilla(String id) {
  switch (id) {
    case 'menu':
      return 'Menú';
    case 'tecnologia':
      return 'Tecnología';
    case 'ropa':
      return 'Ropa';
    case 'cosmeticos':
      return 'Cosméticos';
    case 'servicios':
      return 'Servicios';
    case 'perfumes':
      return 'Perfumes';
    default:
      return 'General';
  }
}

String _nombreFondo(String id) => id == 'oscuro' ? 'Oscuro' : 'Claro';

String _nombreEstilo(String id) {
  switch (id) {
    case 'oferta':
      return 'Oferta';
    case 'novedad':
      return 'Novedad';
    default:
      return 'Simple';
  }
}
