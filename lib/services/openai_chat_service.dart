import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatIaException implements Exception {
  final String mensaje;
  ChatIaException(this.mensaje);

  @override
  String toString() => mensaje;
}

class MensajeChat {
  final String role;
  final String content;

  const MensajeChat({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Cliente de la API de chat de OpenAI.
/// Usa gpt-4o-mini para extraer una venta o un alta de producto.
class OpenAiChatService {
  static const modelo = 'gpt-4o-mini';
  static const _url = 'https://api.openai.com/v1/chat/completions';

  /// Hace una única consulta estructurada. El prompt y el contexto los arma
  /// el orquestador; este cliente solo garantiza el modo JSON.
  Future<String> responderJson({
    required String apiKey,
    required String systemPrompt,
    required String contextoNegocio,
    required List<MensajeChat> historial,
  }) async {
    final recientes = historial.length <= 8
        ? historial
        : historial.sublist(historial.length - 8);
    return _enviar(
      apiKey: apiKey,
      mensajes: [
        {
          'role': 'system',
          'content':
              '$systemPrompt\n\nContexto de la base local:\n$contextoNegocio',
        },
        for (final mensaje in recientes)
          if (mensaje.role == 'user' || mensaje.role == 'assistant')
            mensaje.toJson(),
      ],
    );
  }

  Future<String> responder({
    required String apiKey,
    required String contextoNegocio,
    required List<MensajeChat> historial,
    required String intencion,
  }) async {
    final recientes = historial.length <= 8
        ? historial
        : historial.sublist(historial.length - 8);
    final mensajes = <Map<String, String>>[
      {
        'role': 'system',
        'content': _sistema(intencion, contextoNegocio),
      },
      for (final mensaje in recientes)
        if (mensaje.role == 'user' || mensaje.role == 'assistant')
          mensaje.toJson(),
    ];

    return _enviar(apiKey: apiKey, mensajes: mensajes);
  }

  Future<String> _enviar({
    required String apiKey,
    required List<Map<String, String>> mensajes,
  }) async {
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
              'temperature': 0,
              'max_tokens': 700,
              'response_format': {'type': 'json_object'},
              'messages': mensajes,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw ChatIaException(
        'No se pudo conectar con OpenAI. Revisá la conexión e intentá de nuevo.',
      );
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
    } catch (_) {
      throw ChatIaException('OpenAI devolvió una respuesta que no pude leer.');
    }

    if (response.statusCode == 401) {
      throw ChatIaException(
        'La clave de OpenAI no es válida. Actualizala desde el ícono de la llave.',
      );
    }
    if (response.statusCode == 429) {
      throw ChatIaException(
        'OpenAI limitó las consultas por ahora. Esperá un momento y reintentá.',
      );
    }
    if (response.statusCode != 200) {
      final error = body['error'];
      final detalle = error is Map ? error['message']?.toString() : null;
      throw ChatIaException(
        detalle == null || detalle.isEmpty
            ? 'OpenAI respondió con un error (${response.statusCode}).'
            : 'OpenAI: $detalle',
      );
    }

    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw ChatIaException('OpenAI no devolvió una respuesta.');
    }
    final message = choices.first['message'];
    final content = message is Map ? _textoContenido(message['content']) : null;
    if (content == null || content.trim().isEmpty) {
      throw ChatIaException('OpenAI devolvió una respuesta vacía.');
    }
    return content.trim();
  }
}

String _sistema(String intencion, String contexto) {
  return '''
Devolvé únicamente un objeto JSON. No escribas texto fuera del JSON.
La intención de este mensaje ya está decidida: $intencion.
Extraé solo datos que la persona haya dicho. Si falta un dato, usá null o una cadena vacía.
Si en el historial ya dijo un dato, conservalo. El último mensaje puede completar lo que faltaba.
No inventes clientes, productos ni precios.
Si dijo un, una o uno, la cantidad es 1. Si no dijo cantidad, usá null.
Si no dijo un precio, usá null. Usá 0 solo si dijo cero.
Los precios van como número con punto decimal.
Si no habló de seña, montoSena es 0.
No pidas ni repitas claves de API.

Si la intención es venta:
{"intencion":"venta","cliente":"","montoSena":0,"lineas":[{"producto":"","cantidad":null,"precioVenta":null}]}

Si la intención es producto:
{"intencion":"producto","nombre":"","precioCompra":null,"precioVenta":null}

Contexto de la base local, para copiar nombres que ya existen:
$contexto
''';
}

String? _textoContenido(dynamic content) {
  if (content is String) return content;
  if (content is List) {
    final partes = <String>[];
    for (final parte in content) {
      if (parte is String && parte.trim().isNotEmpty) {
        partes.add(parte);
      } else if (parte is Map && parte['text'] != null) {
        partes.add(parte['text'].toString());
      }
    }
    if (partes.isEmpty) return null;
    return partes.join();
  }
  return null;
}
