import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/negocio_remoto.dart';
import '../backend/tienda_publica_remota.dart';
import '../data/app_database.dart';
import '../services/negocio_local.dart';
import '../services/subdominio_tienda.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';
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
  final _mensaje = TextEditingController();
  final _store = NegocioStore();

  NegocioLocal? _negocio;
  bool _tiendaActiva = false;
  bool _cargando = true;
  bool _guardando = false;
  bool _intentoPublicar = false;

  @override
  void initState() {
    super.initState();
    _slug.addListener(_actualizarVista);
    _whatsapp.addListener(_actualizarVista);
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
    _mensaje.dispose();
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
      _slug.text = negocio.slug.isEmpty
          ? SubdominioTienda.sugerirSlug(negocio.nombre)
          : negocio.slug;
      _whatsapp.text = negocio.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      _mensaje.text = negocio.mensajePublico;
      _tiendaActiva = negocio.tiendaActiva;
    }
    setState(() => _cargando = false);
  }

  String get _slugActual => _slug.text.trim();
  String get _whatsappActual =>
      _whatsapp.text.replaceAll(RegExp(r'[^0-9]'), '');
  String get _url => SubdominioTienda.urlPublica(_slugActual);
  String? get _errorSlug => SubdominioTienda.validarSlug(_slugActual);
  bool get _whatsappValido => _whatsappActual.length >= 8;

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
      final guardado = await _store.guardarPagina(
        slug: _slugActual,
        tiendaActiva: _tiendaActiva,
        whatsapp: _whatsappActual,
        mensajePublico: _mensaje.text.trim(),
      );
      if (guardado != null) {
        final negocioId = const NegocioRemoto().idParaSesion(guardado);
        if (negocioId != null) {
          unawaited(
            const TiendaPublicaRemota().guardarConfig(
              negocioId: negocioId,
              slug: _slugActual,
              tiendaActiva: _tiendaActiva,
              whatsapp: _whatsappActual,
              mensajePublico: _mensaje.text.trim(),
            ),
          );
        }
      }
      if (!mounted) return;
      if (guardado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay un negocio para configurar.')),
        );
        return;
      }
      _negocio = guardado;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Página guardada')),
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
                onChanged: _guardando
                    ? null
                    : (valor) => setState(() {
                          _tiendaActiva = valor;
                          if (!valor) _intentoPublicar = false;
                        }),
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
                'En este navegador de prueba la dirección real todavía no '
                'abre sola; “Ver mi página” muestra la vista del cliente.',
                style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Seccion(
          titulo: 'Pedidos',
          child: TextField(
            controller: _whatsapp,
            enabled: !_guardando,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'WhatsApp que recibe los pedidos',
              hintText: '5491112345678',
              prefixIcon: const Icon(Icons.chat_rounded),
              helperText: 'Incluí el código de país. Guardamos solo números.',
              errorText: _intentoPublicar && !_whatsappValido
                  ? 'Ingresá al menos 8 dígitos.'
                  : null,
            ),
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
