import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Ayuda al comerciante. El 9 después del 54 es el de celular en Argentina.
const enlaceSoporteWhatsapp = 'https://wa.me/5493705032010';

class SoporteWhatsapp extends StatelessWidget {
  const SoporteWhatsapp({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppColors.tarjeta,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => abrirSoporteWhatsapp(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _IconoWhatsapp(),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¿Necesitás ayuda? Escribinos por WhatsApp',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.texto,
                      height: 1.25,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppColors.textoSuave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconoWhatsapp extends StatelessWidget {
  const _IconoWhatsapp();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F8EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: FaIcon(
          FontAwesomeIcons.whatsapp,
          color: Color(0xFF25D366),
          size: 18,
        ),
      ),
    );
  }
}

Future<void> abrirSoporteWhatsapp(BuildContext context) async {
  final enlace = Uri.parse(enlaceSoporteWhatsapp);
  final abierto = await _abrir(enlace);
  if (abierto || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
  );
}

Future<bool> _abrir(Uri enlace) async {
  try {
    if (await launchUrl(enlace, mode: LaunchMode.externalApplication)) {
      return true;
    }
  } catch (_) {
    // En la web a veces no existe el modo externo.
  }
  try {
    return await launchUrl(enlace, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}
