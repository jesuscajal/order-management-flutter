import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pregunta si la foto sale de la galería o de la cámara.
/// Devuelve null si la persona cancela.
Future<ImageSource?> preguntarOrigenFoto(BuildContext context) {
  return showDialog<ImageSource>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Agregar imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Elegí una foto que ya tengas o sacala ahora.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galería'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Cámara'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );
}

/// La galería puede devolver varias fotos. La cámara devuelve una.
Future<List<XFile>> elegirFotos({
  required ImageSource origen,
  required bool variasEnGaleria,
  double maxWidth = 900,
  int imageQuality = 40,
}) async {
  final selector = ImagePicker();
  if (origen == ImageSource.camera || !variasEnGaleria) {
    final archivo = await selector.pickImage(
      source: origen,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    if (archivo == null) return const [];
    return [archivo];
  }
  return selector.pickMultiImage(
    maxWidth: maxWidth,
    imageQuality: imageQuality,
  );
}
