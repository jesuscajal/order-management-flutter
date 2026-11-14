import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatIaException implements Exception {
  final String mensaje;

  /// True si OpenAI llegó a responder, aunque sea con un error.
  final bool consulto;

  ChatIaException(this.mensaje, {this.consulto = false});

  @override
  String toString() => mensaje;
}

class MensajeChat {
  final String role;
  final String content;

  const MensajeChat({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Tokens de un turno según `usage` de la respuesta.
class UsoOpenAi {
  const UsoOpenAi({
    required this.entrada,
    required this.salida,
    required this.enCache,
    required this.milisegundos,
  });

  final int entrada;
  final int salida;
  final int enCache;
  final int milisegundos;

  static UsoOpenAi? desde(dynamic usage, {required int milisegundos}) {
    if (usage is! Map) return null;
    int entero(dynamic valor) => valor is num ? valor.toInt() : 0;
    final detalle = usage['prompt_tokens_details'];
    final cache = detalle is Map
        ? detalle['cached_tokens']
        : usage['input_tokens_details'] is Map
            ? (usage['input_tokens_details'] as Map)['cached_tokens']
            : 0;
    return UsoOpenAi(
      entrada: entero(usage['prompt_tokens'] ?? usage['input_tokens']),
      salida: entero(usage['completion_tokens'] ?? usage['output_tokens']),
      enCache: entero(cache),
      milisegundos: milisegundos,
    );
  }
}

/// Tope de lo que viaja al modelo al interpretar una frase nueva.
const topeTurnosAsistente = 6;
const topeCaracteresAsistente = 280;

/// Deja los últimos [topeTurnosAsistente] mensajes, cada uno recortado.
List<MensajeChat> recorteHistorialAsistente(List<MensajeChat> historial) {
  final propios = <MensajeChat>[];
  for (final mensaje in historial) {
    if (mensaje.role != 'user' && mensaje.role != 'assistant') continue;
    final texto = recorteTextoAsistente(mensaje.content);
    if (texto.isEmpty) continue;
    propios.add(MensajeChat(role: mensaje.role, content: texto));
  }
  if (propios.length <= topeTurnosAsistente) return propios;
  return propios.sublist(propios.length - topeTurnosAsistente);
}

String recorteTextoAsistente(String texto) {
  final limpio = texto.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (limpio.length <= topeCaracteresAsistente) return limpio;
  return limpio.substring(0, topeCaracteresAsistente);
}

/// Cliente de la API de chat de OpenAI.
/// Usa gpt-4o-mini para extraer una venta o un alta de producto.
class OpenAiChatService {
  static const modelo = 'gpt-4o-mini';
  static const baseUrlDefecto = 'https://api.openai.com/v1';

  /// Hace una única consulta estructurada. El prompt y el contexto los arma
  /// el orquestador; este cliente solo garantiza el modo JSON.
  /// Último consumo informado por OpenAI. Null si la respuesta no lo trajo.
  UsoOpenAi? ultimoUso;

  Future<String> responderJson({
    required String apiKey,
    required String systemPrompt,
    required String contextoNegocio,
    required List<MensajeChat> historial,
    int maxTokens = 700,
    String baseUrl = OpenAiChatService.baseUrlDefecto,
    String? modeloPedido,
  }) async {
    final recientes = historial.length <= 8
        ? historial
        : historial.sublist(historial.length - 8);
    return _enviar(
      apiKey: apiKey,
      maxTokens: maxTokens,
      baseUrl: baseUrl,
      modeloPedido: modeloPedido,
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

  /// Prefijo fijo en el mensaje de sistema; la ficha y la frase van al final,
  /// en el mensaje del usuario, para no romper el caché del prefijo.
  Future<String> interpretarJson({
    required String apiKey,
    required String systemPrompt,
    required String ficha,
    required String frase,
    List<MensajeChat> historial = const [],
    int maxTokens = 400,
    String baseUrl = OpenAiChatService.baseUrlDefecto,
    String? modeloPedido,
  }) {
    final conversacion = [
      for (final mensaje in recorteHistorialAsistente(historial))
        '${mensaje.role}: ${mensaje.content}',
    ].join('\n');
    final previo = conversacion.isEmpty
        ? ''
        : '<conversacion>\n$conversacion\n</conversacion>\n';
    return _enviar(
      apiKey: apiKey,
      maxTokens: maxTokens,
      baseUrl: baseUrl,
      modeloPedido: modeloPedido,
      mensajes: [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': '<ficha_negocio>$ficha</ficha_negocio>\n'
              '$previo<frase>$frase</frase>',
        },
      ],
    );
  }

  Future<String> responder({
    required String apiKey,
    required String contextoNegocio,
    required List<MensajeChat> historial,
    required String intencion,
    String baseUrl = OpenAiChatService.baseUrlDefecto,
    String? modeloPedido,
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

    return _enviar(
      apiKey: apiKey,
      mensajes: mensajes,
      maxTokens: 700,
      baseUrl: baseUrl,
      modeloPedido: modeloPedido,
    );
  }

  Future<String> _enviar({
    required String apiKey,
    required List<Map<String, String>> mensajes,
    int maxTokens = 700,
    String baseUrl = OpenAiChatService.baseUrlDefecto,
    String? modeloPedido,
  }) async {
    ultimoUso = null;
    final inicio = DateTime.now();
    final base = _baseChat(baseUrl);
    final nube = _esNubeOpenAi(base);
    final modeloUsado = (modeloPedido == null || modeloPedido.trim().isEmpty)
        ? OpenAiChatService.modelo
        : modeloPedido.trim();
    final cabeceras = <String, String>{
      'Content-Type': 'application/json',
    };
    final clave = apiKey.trim();
    if (clave.isNotEmpty) {
      cabeceras['Authorization'] = 'Bearer $clave';
    }
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$base/chat/completions'),
            headers: cabeceras,
            body: jsonEncode({
              'model': modeloUsado,
              'temperature': 0,
              'max_tokens': maxTokens,
              'response_format': {'type': 'json_object'},
              'messages': mensajes,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw ChatIaException(
        nube
            ? 'No se pudo conectar con OpenAI. Revisá la conexión e intentá de nuevo.'
            : 'No se pudo conectar con el modelo local. Revisá la dirección y que el servidor esté encendido.',
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
      throw ChatIaException(
        nube
            ? 'OpenAI devolvió una respuesta que no pude leer.'
            : 'El modelo local devolvió una respuesta que no pude leer.',
        consulto: true,
      );
    }

    if (response.statusCode == 401) {
      throw ChatIaException(
        nube
            ? 'La clave de OpenAI no es válida.'
            : 'El modelo local rechazó la clave.',
        consulto: true,
      );
    }
    if (response.statusCode == 429) {
      throw ChatIaException(
        nube
            ? 'OpenAI limitó las consultas por ahora. Esperá un momento y reintentá.'
            : 'El modelo local limitó las consultas. Esperá un momento y reintentá.',
        consulto: true,
      );
    }
    if (response.statusCode != 200) {
      final error = body['error'];
      final detalle = error is Map ? error['message']?.toString() : null;
      throw ChatIaException(
        nube
            ? (detalle == null || detalle.isEmpty
                ? 'OpenAI respondió con un error (${response.statusCode}).'
                : 'OpenAI: $detalle')
            : 'El modelo local respondió con un error (${response.statusCode}). Revisá la dirección, que termine en /v1, y el nombre del modelo.',
        consulto: true,
      );
    }

    ultimoUso = UsoOpenAi.desde(
      body['usage'],
      milisegundos: DateTime.now().difference(inicio).inMilliseconds,
    );

    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw ChatIaException(
        nube
            ? 'OpenAI no devolvió una respuesta.'
            : 'El modelo local no devolvió una respuesta.',
        consulto: true,
      );
    }
    final message = choices.first['message'];
    final content = message is Map ? _textoContenido(message['content']) : null;
    if (content == null || content.trim().isEmpty) {
      throw ChatIaException(
        nube
            ? 'OpenAI devolvió una respuesta vacía.'
            : 'El modelo local devolvió una respuesta vacía.',
        consulto: true,
      );
    }
    return content.trim();
  }
}

String _baseChat(String baseUrl) {
  var base = baseUrl.trim();
  if (base.isEmpty) return OpenAiChatService.baseUrlDefecto;
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return base;
}

bool _esNubeOpenAi(String baseUrl) {
  final base = _baseChat(baseUrl).toLowerCase();
  return base == OpenAiChatService.baseUrlDefecto ||
      base.startsWith('${OpenAiChatService.baseUrlDefecto}/');
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
