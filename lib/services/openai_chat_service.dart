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
/// Usa gpt-4o-mini, el modelo de costo medio previsto para consultas del negocio.
class OpenAiChatService {
  static const modelo = 'gpt-4o-mini';
  static const _url = 'https://api.openai.com/v1/chat/completions';

  Future<String> responder({
    required String apiKey,
    required String contextoNegocio,
    required List<MensajeChat> historial,
  }) async {
    final mensajes = <Map<String, String>>[
      {
        'role': 'system',
        'content': '''
Eres el asistente del sistema de gestión de pedidos.
Respondes en español, de forma breve y concreta.
Usas solamente el contexto del negocio que te paso.
Si un dato no está en el contexto, decís que no figura en la base local.
No inventes clientes, stock, pedidos ni montos.
No pidas ni repitas claves de API.

Contexto actual:
$contextoNegocio
''',
      },
      ...historial.take(12).map((m) => m.toJson()),
    ];

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
              'temperature': 0.2,
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
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
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
    final content = message is Map ? message['content']?.toString() : null;
    if (content == null || content.trim().isEmpty) {
      throw ChatIaException('OpenAI devolvió una respuesta vacía.');
    }
    return content.trim();
  }
}
