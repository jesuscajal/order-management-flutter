import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/codigo_qr.dart';
import '../services/negocio_local.dart';
import '../services/subdominio_tienda.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';
import '../widgets/qr_dibujo.dart';

/// QR y enlace de la página pública del negocio, para mostrar o copiar.
class PromocionPaginaScreen extends StatefulWidget {
  const PromocionPaginaScreen({super.key});

  @override
  State<PromocionPaginaScreen> createState() => _PromocionPaginaScreenState();
}

class _PromocionPaginaScreenState extends State<PromocionPaginaScreen> {
  final _store = NegocioStore();
  bool _cargando = true;
  String? _url;
  bool _oculta = false;
  List<List<bool>>? _modulos;
  String? _errorQr;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final negocio = await _store.leer();
    if (!mounted) return;
    final slug = (negocio?.slug ?? '').trim().toLowerCase();
    final valida = slug.isNotEmpty && SubdominioTienda.validarSlug(slug) == null;
    final url = valida ? SubdominioTienda.urlPublica(slug) : null;
    List<List<bool>>? modulos;
    String? errorQr;
    if (url != null) {
      try {
        modulos = CodigoQr.modulos(url);
      } catch (_) {
        errorQr = 'No se pudo armar el código QR de esta dirección.';
      }
    }
    setState(() {
      _cargando = false;
      _url = url;
      _oculta = valida && negocio?.tiendaActiva != true;
      _modulos = modulos;
      _errorQr = errorQr;
    });
  }

  Future<void> _copiar() async {
    final url = _url;
    if (url == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo copiar el enlace.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final modulos = _modulos;
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text('Promocioná tu página')),
      body: FondoGexi(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    url == null
                        ? 'Cuando publiques la página, acá vas a tener el código para compartirla.'
                        : 'Mostrá este código para que entren a la página de tu negocio.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  if (url == null)
                    const _Aviso(
                      icono: Icons.language_rounded,
                      texto:
                          'Todavía no hay una dirección publicada. Primero publicá tu página web y después volvé a esta pantalla.',
                    )
                  else ...[
                    if (_oculta) ...[
                      const _Aviso(
                        icono: Icons.visibility_off_rounded,
                        texto:
                            'La página está oculta. Publicala para que quien escanee el código vea el catálogo.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    DecoratedBox(
                      decoration: AppColors.tarjeta,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Column(
                          children: [
                            if (modulos != null)
                              LayoutBuilder(
                                builder: (context, limites) {
                                  final lado = limites.maxWidth.clamp(180.0, 320.0);
                                  return Semantics(
                                    label: 'Código QR de $url',
                                    child: QrDibujo(modulos: modulos, lado: lado),
                                  );
                                },
                              )
                            else
                              Text(
                                _errorQr ?? 'No se pudo armar el código QR.',
                                style: const TextStyle(color: AppColors.texto),
                              ),
                            const SizedBox(height: 12),
                            SelectableText(
                              url,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.primario,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _copiar,
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copiar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppColors.tarjeta,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: AppColors.primario),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(color: AppColors.texto, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
