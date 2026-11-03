import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'openai_chat_service.dart';

/// Datos leídos de una foto. No incluyen precios: los carga la persona.
class ProductoDetectado {
  final String nombre;
  final String descripcion;
  final String categoria;

  const ProductoDetectado({
    required this.nombre,
    required this.descripcion,
    required this.categoria,
  });
}

/// Analiza una foto de producto con gpt-4o-mini (visión).
/// La imagen viaja como data URL base64 en el mensaje user.
class OpenAiVisionService {
  static const modelo = 'gpt-4o-mini';
  static const _url = 'https://api.openai.com/v1/chat/completions';
  static const _maxBytes = 10 * 1024 * 1024;

  static const _sistema = '''
Sos un asistente que identifica productos en fotos para un sistema de gestión.
Respondés únicamente con un objeto JSON, sin markdown, con estas claves de texto:
- nombre: nombre corto y concreto del producto
- descripcion: una o dos oraciones sobre qué es
- categoria: rubro comercial breve
Si la foto no muestra un producto claro, usá nombre "Producto sin identificar",
descripcion con lo que sí se ve y categoria "Sin categoría".
No inventes marca, modelo ni precios. No incluyas otras claves.
''';

  Future<ProductoDetectado> analizarProducto({
    required String apiKey,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw ChatIaException('La foto está vacía. Elegí otra imagen.');
    }
    if (bytes.length > _maxBytes) {
      throw ChatIaException(
        'La foto es demasiado pesada. Elegí una imagen de menos de 10 MB.',
      );
    }

    final mime = mimeType.toLowerCase().startsWith('image/')
        ? mimeType.split(';').first.trim().toLowerCase()
        : 'image/jpeg';
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': modelo,
              'temperature': 0.1,
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': _sistema},
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text':
                          'Extraé nombre, descripción y categoría del producto de la foto. '
                          'Respondé solo con el JSON pedido.',
                    },
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': dataUrl,
                        'detail': 'high',
                      },
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw ChatIaException(
        'OpenAI tardó demasiado en analizar la foto. Intentá de nuevo.',
      );
    } catch (_) {
      throw ChatIaException(
        'No se pudo conectar con OpenAI para analizar la foto. Revisá la conexión e intentá de nuevo.',
      );
    }

    final body = _leerCuerpo(response);
    _lanzarSiErrorHttp(response.statusCode, body);
    return interpretarProducto(_textoDeMensaje(body));
  }

  /// Tipo MIME a partir de lo que informa el selector o de la extensión.
  static String mimeDeArchivo({required String path, String? mimeType}) {
    final declarado = mimeType?.split(';').first.trim().toLowerCase();
    if (declarado != null && declarado.startsWith('image/')) {
      return declarado;
    }
    final nombre = path.replaceAll('\\', '/').toLowerCase();
    if (nombre.endsWith('.png')) return 'image/png';
    if (nombre.endsWith('.webp')) return 'image/webp';
    if (nombre.endsWith('.gif')) return 'image/gif';
    if (nombre.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }
}

Map<String, dynamic> _leerCuerpo(http.Response response) {
  String raw;
  try {
    raw = utf8.decode(response.bodyBytes);
  } catch (_) {
    throw ChatIaException(
      'OpenAI devolvió una respuesta que no pude leer al analizar la foto.',
    );
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    throw ChatIaException(
      'OpenAI devolvió una respuesta que no pude leer al analizar la foto.',
    );
  }
  throw ChatIaException(
    'OpenAI devolvió una respuesta que no pude leer al analizar la foto.',
  );
}

void _lanzarSiErrorHttp(int status, Map<String, dynamic> body) {
  if (status == 401) {
    throw ChatIaException(
      'La clave de OpenAI no es válida. Actualizala desde el ícono de la llave.',
    );
  }
  if (status == 429) {
    throw ChatIaException(
      'OpenAI limitó el análisis de fotos por ahora. Esperá un momento y reintentá.',
    );
  }
  if (status != 200) {
    final error = body['error'];
    final detalle = error is Map ? error['message']?.toString().trim() : null;
    if (detalle == null || detalle.isEmpty) {
      throw ChatIaException(
        'No se pudo analizar la foto. OpenAI respondió con un error ($status).',
      );
    }
    throw ChatIaException('No se pudo analizar la foto. OpenAI respondió: $detalle');
  }
}

String _textoDeMensaje(Map<String, dynamic> body) {
  final choices = body['choices'];
  if (choices is! List || choices.isEmpty) {
    throw ChatIaException('OpenAI no devolvió datos del producto.');
  }
  final primero = choices.first;
  if (primero is! Map) {
    throw ChatIaException('OpenAI no devolvió datos del producto.');
  }
  final message = primero['message'];
  if (message is! Map) {
    throw ChatIaException('OpenAI no devolvió datos del producto.');
  }
  final content = message['content'];
  final texto = _aplanarContenido(content).trim();
  if (texto.isNotEmpty) return texto;
  final rechazo = message['refusal']?.toString().trim();
  if (rechazo != null && rechazo.isNotEmpty) {
    throw ChatIaException('El modelo rechazó analizar la foto. $rechazo');
  }
  throw ChatIaException('OpenAI devolvió una respuesta vacía al analizar la foto.');
}

String _aplanarContenido(Object? content) {
  if (content is String) return content;
  if (content is List) {
    final buffer = StringBuffer();
    for (final parte in content) {
      if (parte is String) {
        buffer.write(parte);
      } else if (parte is Map && parte['text'] != null) {
        buffer.write(parte['text']);
      }
    }
    return buffer.toString();
  }
  return '';
}

/// Interpreta el JSON del modelo. Visible para mantener el parseo en un solo lugar.
ProductoDetectado interpretarProducto(String contenido) {
  final objeto = _decodificarObjeto(contenido);
  final mapa = _desenvolver(objeto);
  return ProductoDetectado(
    nombre: _texto(mapa, const ['nombre', 'name'], 'Producto sin identificar'),
    descripcion: _texto(
      mapa,
      const ['descripcion', 'descripción', 'description'],
      'Sin descripción',
    ),
    categoria: _texto(
      mapa,
      const ['categoria', 'categoría', 'category', 'rubro'],
      'Sin categoría',
    ),
  );
}

Map<String, dynamic> _decodificarObjeto(String contenido) {
  var texto = contenido.trim();
  final bloque = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(texto);
  if (bloque != null) {
    texto = bloque.group(1)!.trim();
  }
  final inicio = texto.indexOf('{');
  final fin = texto.lastIndexOf('}');
  if (inicio < 0 || fin <= inicio) {
    throw ChatIaException(
      'La visión respondió, pero no pude extraer nombre, descripción y categoría. Intentá con otra foto.',
    );
  }
  try {
    final decoded = jsonDecode(texto.substring(inicio, fin + 1));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    throw ChatIaException(
      'La visión respondió, pero no pude extraer nombre, descripción y categoría. Intentá con otra foto.',
    );
  }
  throw ChatIaException(
    'La visión respondió, pero no pude extraer nombre, descripción y categoría. Intentá con otra foto.',
  );
}

Map<String, dynamic> _desenvolver(Map<String, dynamic> mapa) {
  if (_buscar(mapa, 'nombre') != null || _buscar(mapa, 'name') != null) {
    return mapa;
  }
  for (final clave in const ['producto', 'product', 'item', 'resultado', 'data']) {
    final interno = _buscar(mapa, clave);
    if (interno is Map) {
      return interno.map((key, value) => MapEntry(key.toString(), value));
    }
  }
  return mapa;
}

String _texto(Map<String, dynamic> mapa, List<String> claves, String defecto) {
  for (final clave in claves) {
    final valor = _buscar(mapa, clave);
    if (valor is String && valor.trim().isNotEmpty) return valor.trim();
    if (valor is num || valor is bool) return valor.toString();
  }
  return defecto;
}

Object? _buscar(Map<String, dynamic> mapa, String clave) {
  for (final entry in mapa.entries) {
    if (entry.key.toLowerCase() == clave) return entry.value;
  }
  return null;
}
