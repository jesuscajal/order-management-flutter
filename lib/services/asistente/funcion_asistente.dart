import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/remoto_comun.dart';
import '../openai_chat_service.dart';

/// Respuesta de la función. Nunca trae la clave.
class ResultadoFuncionAsistente {
  const ResultadoFuncionAsistente({
    this.json,
    this.uso,
    this.error,
    this.noConfigurado = false,
    this.sinChats = false,
    this.descontoCupo = false,
  });

  final String? json;
  final UsoOpenAi? uso;
  final String? error;
  final bool noConfigurado;
  final bool sinChats;
  final bool descontoCupo;
}

/// Llama a `asistente-interpretar` con el JWT de la sesión.
class FuncionAsistenteCompartida {
  const FuncionAsistenteCompartida();

  Future<ResultadoFuncionAsistente> interpretar({
    required String frase,
    required String ficha,
    String? negocioId,
    List<MensajeChat> historial = const [],
  }) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) {
      return const ResultadoFuncionAsistente(noConfigurado: true);
    }
    final inicio = DateTime.now();
    try {
      final respuesta = await supabase.functions.invoke(
        'asistente-interpretar',
        body: {
          'frase': frase,
          'ficha': ficha,
          if (negocioId != null && negocioId.isNotEmpty) 'negocio_id': negocioId,
          'historial': [
            for (final mensaje in recorteHistorialAsistente(historial))
              {'role': mensaje.role, 'content': mensaje.content},
          ],
        },
      );
      return _leerMapa(
        respuesta.data,
        milisegundos: DateTime.now().difference(inicio).inMilliseconds,
      );
    } on FunctionException catch (error) {
      final mapa = error.details is Map
          ? Map<String, dynamic>.from(error.details as Map)
          : const <String, dynamic>{};
      final milisegundos = DateTime.now().difference(inicio).inMilliseconds;
      if (error.status == 401 || mapa['error'] == 'asistente_no_configurado') {
        return ResultadoFuncionAsistente(
          noConfigurado: true,
          descontoCupo: mapa['cupo_descontado'] == true,
          uso: UsoOpenAi.desde(mapa['usage'], milisegundos: milisegundos),
        );
      }
      if (error.status == 409 || mapa['error'] == 'sin_cupo') {
        return const ResultadoFuncionAsistente(sinChats: true);
      }
      return _leerMapa(mapa, milisegundos: milisegundos, fallo: true);
    } catch (error) {
      RemotoComun.aviso('No se pudo llamar al asistente compartido: $error');
      return const ResultadoFuncionAsistente(
        error: 'No pude consultar el asistente compartido. No guardé nada.',
      );
    }
  }

  ResultadoFuncionAsistente _leerMapa(
    dynamic data, {
    required int milisegundos,
    bool fallo = false,
  }) {
    final mapa = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    if (mapa['error'] == 'asistente_no_configurado') {
      return const ResultadoFuncionAsistente(noConfigurado: true);
    }
    if (mapa['error'] == 'sin_cupo') {
      return const ResultadoFuncionAsistente(sinChats: true);
    }
    final json = mapa['json']?.toString();
    final uso = UsoOpenAi.desde(
      mapa['usage'],
      milisegundos: milisegundos,
    );
    final desconto = mapa['cupo_descontado'] == true;
    final mensaje = mapa['mensaje']?.toString().trim();
    if (fallo || json == null || json.trim().isEmpty) {
      return ResultadoFuncionAsistente(
        uso: uso,
        descontoCupo: desconto,
        error: mensaje == null || mensaje.isEmpty
            ? 'No pude consultar el asistente compartido. No guardé nada.'
            : mensaje,
      );
    }
    return ResultadoFuncionAsistente(
      json: json.trim(),
      uso: uso,
      descontoCupo: desconto,
    );
  }
}
