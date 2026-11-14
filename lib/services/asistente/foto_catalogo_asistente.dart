import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../data/vidriera_local.dart';
import '../fuente_ia.dart';
import '../openai_chat_service.dart';
import 'funcion_imagen_asistente.dart';
import 'memoria_asistente.dart';

/// Motivo en español de un error de la API de imágenes.
class MotivoFalloFoto {
  const MotivoFalloFoto({
    required this.mensaje,
    this.probarOtroModelo = false,
  });

  final String mensaje;

  /// True solo cuando el modelo pedido no existe o esta cuenta no lo tiene.
  final bool probarOtroModelo;
}

/// Traduce el error de OpenAI. No devuelve el texto crudo ni la clave.
///
/// [claveEnTelefono] queda para el mensaje del modelo local. La clave de
/// OpenAI no se carga en el teléfono: la usa la función compartida.
MotivoFalloFoto motivoFalloFotoOpenAi({
  required int status,
  String codigo = '',
  String parametro = '',
  String detalle = '',
  bool claveEnTelefono = true,
}) {
  final code = codigo.trim().toLowerCase();
  final param = parametro.trim().toLowerCase();
  final texto = detalle.trim().toLowerCase();

  final claveInvalida = status == 401 ||
      code == 'invalid_api_key' ||
      code == 'incorrect_api_key' ||
      texto.contains('incorrect api key') ||
      texto.contains('invalid api key') ||
      texto.contains('api key') && texto.contains('expired');
  if (claveInvalida) {
    return MotivoFalloFoto(
      mensaje: claveEnTelefono
          ? 'El modelo local rechazó la clave.'
          : 'La clave de OpenAI del asistente compartido no es válida.',
    );
  }

  final sinSaldo = status == 402 ||
      code == 'insufficient_quota' ||
      code == 'billing_hard_limit_reached' ||
      code == 'billing_not_active' ||
      texto.contains('insufficient_quota') ||
      texto.contains('exceeded your current quota') ||
      texto.contains('billing hard limit') ||
      texto.contains('check your plan and billing');
  if (sinSaldo) {
    return const MotivoFalloFoto(
      mensaje: 'La cuenta de OpenAI no tiene saldo para generar la foto.',
    );
  }

  final pesada = status == 413 ||
      code == 'image_too_large' ||
      code == 'payload_too_large' ||
      texto.contains('image is too large') ||
      texto.contains('image too large') ||
      texto.contains('file is too large');
  if (pesada) {
    return const MotivoFalloFoto(mensaje: mensajeFotoPesada);
  }

  final mencionaModelo = texto.contains('model') ||
      texto.contains('gpt-image') ||
      texto.contains('dall-e');
  final modeloCaido = code == 'model_not_found' ||
      code == 'model_not_available' ||
      param == 'model' ||
      mencionaModelo &&
          (texto.contains('not found') ||
              texto.contains('does not exist') ||
              texto.contains('do not exist') ||
              texto.contains('not available') ||
              texto.contains('do not have access') ||
              texto.contains('deprecated') ||
              texto.contains('shut down') ||
              texto.contains('shutdown') ||
              texto.contains('no longer') ||
              texto.contains('not supported'));
  if (modeloCaido) {
    return const MotivoFalloFoto(
      mensaje: 'El modelo de imagen no está disponible en esta cuenta.',
      probarOtroModelo: true,
    );
  }

  if (status == 429 || code == 'rate_limit_exceeded') {
    return const MotivoFalloFoto(
      mensaje:
          'OpenAI limitó la generación de imágenes. Esperá un momento o subí una foto.',
    );
  }

  if (code == 'moderation_blocked' ||
      texto.contains('safety system') ||
      texto.contains('content policy')) {
    return const MotivoFalloFoto(
      mensaje: 'OpenAI no dejó generar esa foto. Podés subir una.',
    );
  }

  return MotivoFalloFoto(
    mensaje: 'No pude generar la foto ($status). Podés subir una.',
  );
}

/// Foto de catálogo para la página: un producto, fondo blanco, peso de vidriera.
///
/// Si el panel dejó activo un modelo local, el POST sale a esa base. Si no,
/// usa la función `asistente-imagen` con la sesión de Supabase. El teléfono
/// no recibe la clave de OpenAI. El JPEG queda en la tarjeta y, al confirmar,
/// en la vidriera: no se guarda en el chat.
class FotoCatalogoAsistente {
  FotoCatalogoAsistente({
    FuncionImagenAsistente? funcion,
    FuenteIa? fuente,
  })  : _funcion = funcion ?? const FuncionImagenAsistente(),
        _fuente = fuente ?? const FuenteIa();

  static const _baseNube = 'https://api.openai.com/v1';

  final FuncionImagenAsistente _funcion;
  final FuenteIa _fuente;

  /// Deja la foto del usuario en JPEG sobre blanco y dentro del tope.
  Uint8List preparar(Uint8List bytes) {
    return _jpegFondoBlanco(bytes);
  }

  /// Genera una foto de catálogo. Sin modelo local usa la función compartida.
  Future<Uint8List> generar({
    required String nombre,
    String? categoria,
    String? descripcion,
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw ChatIaException(
          'Falta el nombre del producto para generar la foto.');
    }
    final detalle = _detalle(descripcion);
    final prompt = _prompt(limpio, categoria, detalle);
    final local = await _fuente.leerModeloLocal();
    final Uint8List cruda;
    if (local != null) {
      cruda = await _desdeModeloLocal(local, prompt);
    } else {
      cruda = await _funcion.generar(
        nombre: limpio,
        categoria: categoria,
        descripcion: detalle,
      );
    }
    try {
      return _jpegFondoBlanco(cruda);
    } on ChatIaException {
      rethrow;
    } catch (_) {
      throw ChatIaException(
        'La imagen generada no entró en la página. Probá de nuevo o subí una foto.',
      );
    }
  }

  /// Un solo POST a `{base}/images/generations`. Si el modelo local no
  /// genera imágenes, no se prueba otra ruta.
  Future<Uint8List> _desdeModeloLocal(
    ModeloLocalIa local,
    String prompt,
  ) async {
    final base = local.baseUrl.trim();
    final modelo = local.modelo.trim();
    if (base.isEmpty || modelo.isEmpty) {
      throw ChatIaException(
        'Falta la dirección o el nombre del modelo local.',
      );
    }
    final respuesta = await _post(
      local.clave,
      prompt,
      modelo,
      baseUrl: base,
      modeloLocal: true,
    );
    final bytes = respuesta.bytes;
    if (bytes != null) {
      await const MemoriaAsistente().anotarUso(
        respuesta.uso,
        origen: 'foto',
        modelo: modelo,
      );
      return bytes;
    }
    throw ChatIaException(
      respuesta.motivo?.mensaje ??
          'Este modelo local no genera fotos de catálogo. Subí una imagen.',
      consulto: respuesta.consulto,
    );
  }

  Future<_RespuestaImagen> _post(
    String apiKey,
    String prompt,
    String modelo, {
    String baseUrl = _baseNube,
    bool modeloLocal = false,
  }) async {
    final http.Response response;
    final cabeceras = <String, String>{
      'Content-Type': 'application/json',
    };
    final clave = apiKey.trim();
    if (clave.isNotEmpty) {
      cabeceras['Authorization'] = 'Bearer $clave';
    }
    try {
      response = await http
          .post(
            Uri.parse(_urlImagenes(baseUrl)),
            headers: cabeceras,
            body: jsonEncode({
              'model': modelo,
              'prompt': prompt,
              'n': 1,
              'size': '1024x1024',
              'quality': 'medium',
              'background': 'opaque',
              'output_format': 'jpeg',
              'output_compression': 70,
            }),
          )
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw ChatIaException(
        modeloLocal
            ? 'El modelo local no respondió a tiempo. Si no genera imágenes, '
                'subí una foto.'
            : 'La generación de la foto tardó demasiado. Probá de nuevo o subí una imagen.',
      );
    } catch (_) {
      throw ChatIaException(
        modeloLocal
            ? 'No se pudo conectar con el modelo local. Si no genera imágenes, '
                'subí una foto.'
            : 'No se pudo generar la foto. Revisá la conexión o subí una imagen.',
      );
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (response.statusCode == 200) {
        throw ChatIaException(
          modeloLocal
              ? 'El modelo local devolvió una respuesta que no pude leer como foto.'
              : 'OpenAI devolvió una imagen que no pude leer.',
          consulto: true,
        );
      }
    }

    if (modeloLocal && response.statusCode != 200) {
      return _RespuestaImagen(
        consulto: true,
        motivo: MotivoFalloFoto(
          mensaje: response.statusCode == 401
              ? 'El modelo local rechazó la clave.'
              : 'Este modelo local no genera fotos de catálogo. Subí una imagen.',
        ),
      );
    }

    if (response.statusCode != 200) {
      final error = body['error'];
      final mapa = error is Map
          ? Map<String, dynamic>.from(error)
          : const <String, dynamic>{};
      return _RespuestaImagen(
        consulto: true,
        motivo: motivoFalloFotoOpenAi(
          status: response.statusCode,
          codigo: mapa['code']?.toString() ?? '',
          parametro: mapa['param']?.toString() ?? '',
          detalle: mapa['message']?.toString() ?? '',
        ),
      );
    }

    final bytes = _bytesDeRespuesta(body);
    if (bytes == null) {
      return _RespuestaImagen(
        consulto: true,
        motivo: MotivoFalloFoto(
          mensaje: modeloLocal
              ? 'Este modelo local no generó una foto. Subí una imagen.'
              : 'OpenAI no devolvió la imagen. Podés subir una foto.',
        ),
      );
    }
    return _RespuestaImagen(
      bytes: bytes,
      consulto: true,
      uso: UsoOpenAi.desde(body['usage'], milisegundos: 0),
    );
  }

  String _urlImagenes(String baseUrl) {
    var base = baseUrl.trim();
    if (base.isEmpty) base = _baseNube;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/images/generations';
  }

  Uint8List? _bytesDeRespuesta(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! List || data.isEmpty || data.first is! Map) return null;
    final fila = Map<String, dynamic>.from(data.first as Map);
    final b64 = fila['b64_json']?.toString() ?? '';
    if (b64.isEmpty) return null;
    try {
      final bytes = base64Decode(b64);
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  String _detalle(String? descripcion) {
    final limpio = (descripcion ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (limpio.length <= 240) return limpio;
    return limpio.substring(0, 240);
  }

  String _prompt(String nombre, String? categoria, String descripcion) {
    final rubro = categoria?.trim() ?? '';
    final deRubro = rubro.isEmpty ? '' : ', categoría $rubro';
    final deDetalle =
        descripcion.isEmpty ? '' : ' Características: $descripcion.';
    return 'Una sola foto de catálogo para una tienda online del producto "$nombre"$deRubro.$deDetalle '
        'El producto está centrado, entero y apoyado sobre un fondo blanco puro (#FFFFFF). '
        'Luz de estudio pareja, sombra de contacto muy suave, encuadre cuadrado. '
        'Sin texto, sin letras, sin logo, sin marca de agua, sin precio, sin manos '
        'y sin otros objetos.';
  }

  Uint8List _jpegFondoBlanco(Uint8List origen) {
    final decodificada = img.decodeImage(origen);
    if (decodificada == null) {
      throw ChatIaException('No pude leer esa imagen. Probá con otra foto.');
    }
    var ladoMaximo = 800;
    var calidad = 62;
    while (true) {
      final ajustada = _encajar(decodificada, ladoMaximo);
      final lienzo = img.Image(
        width: ajustada.width,
        height: ajustada.height,
        numChannels: 3,
      );
      img.fill(lienzo, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(lienzo, ajustada);
      final jpg = img.encodeJpg(lienzo, quality: calidad);
      if (base64Encode(jpg).length <= topeFotoVidriera) {
        return Uint8List.fromList(jpg);
      }
      if (calidad > 42) {
        calidad -= 8;
        continue;
      }
      if (ladoMaximo > 480) {
        ladoMaximo -= 120;
        calidad = 62;
        continue;
      }
      throw ChatIaException(mensajeFotoPesada);
    }
  }

  img.Image _encajar(img.Image origen, int ladoMaximo) {
    if (origen.width <= ladoMaximo && origen.height <= ladoMaximo) {
      return origen;
    }
    if (origen.width >= origen.height) {
      return img.copyResize(origen, width: ladoMaximo);
    }
    return img.copyResize(origen, height: ladoMaximo);
  }
}

class _RespuestaImagen {
  const _RespuestaImagen({
    this.bytes,
    this.motivo,
    this.uso,
    this.consulto = false,
  });

  final Uint8List? bytes;
  final MotivoFalloFoto? motivo;
  final UsoOpenAi? uso;
  final bool consulto;
}
