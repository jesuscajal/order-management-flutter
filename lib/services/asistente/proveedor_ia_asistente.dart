import '../fuente_ia.dart';
import '../openai_chat_service.dart';
import '../prompts_asistente.dart';
import 'funcion_asistente.dart';
import 'memoria_asistente.dart';

/// Lo que dice el orquestador cuando todavía no hay asistente.
///
/// El plan JSON pegado en el chat se puede aplicar igual, sin llamar a la API.
const mensajeFaltaApi =
    'Falta conectar la API de la IA. Si ya tenés el plan, pegalo como JSON con la clave '
    '"acciones". Todavía no guardé nada.';

const mensajeAsistenteCompartido =
    'El asistente compartido no está configurado. Todavía no guardé nada.';

const mensajeSinChats =
    'No quedan chats del asistente. No consulté el modelo y no guardé nada.';

/// Respuesta del adaptador. [json] es el objeto de acciones, nunca SQL.
class ResultadoProveedorIa {
  const ResultadoProveedorIa({
    this.json,
    this.faltaClave = false,
    this.error,
    this.uso,
    this.medible = false,
  });

  final String? json;
  final bool faltaClave;
  final String? error;

  /// Tokens y demora del turno, si el proveedor los informa.
  final UsoOpenAi? uso;

  /// True solo cuando este turno llamó al modelo.
  final bool medible;
}

/// Proveedor intercambiable. El orquestador no conoce OpenAI.
abstract class ProveedorIaAsistente {
  Future<ResultadoProveedorIa> interpretar({
    required String frase,
    String contexto = '',
    List<MensajeChat> historial = const [],
  });
}

/// Si el panel dejó activo un modelo local, el teléfono llama a esa dirección.
/// Si no, usa la función compartida. La clave de OpenAI no llega al teléfono.
///
/// Cada turno que consulta el modelo anota el uso y descuenta un chat del negocio.
class ProveedorOpenAiAsistente implements ProveedorIaAsistente {
  ProveedorOpenAiAsistente({
    FuenteIa? fuente,
    OpenAiChatService? chat,
    MemoriaAsistente? memoria,
    FuncionAsistenteCompartida? funcion,
  })  : _fuente = fuente ?? const FuenteIa(),
        _chat = chat ?? OpenAiChatService(),
        _memoria = memoria ?? const MemoriaAsistente(),
        _funcion = funcion ?? const FuncionAsistenteCompartida();

  final FuenteIa _fuente;
  final OpenAiChatService _chat;
  final MemoriaAsistente _memoria;
  final FuncionAsistenteCompartida _funcion;

  @override
  Future<ResultadoProveedorIa> interpretar({
    required String frase,
    String contexto = '',
    List<MensajeChat> historial = const [],
  }) async {
    final cupo = await _memoria.leerCupo();
    if (cupo.haySesion && cupo.disponibles == 0) {
      return const ResultadoProveedorIa(error: mensajeSinChats);
    }

    final local = await _fuente.leerModeloLocal();
    if (local != null) {
      return _conClaveLocal(
        clave: local.clave,
        frase: frase,
        contexto: contexto,
        historial: historial,
        haySesion: cupo.haySesion,
        baseUrl: local.baseUrl,
        modelo: local.modelo,
      );
    }
    if (!cupo.haySesion) {
      return const ResultadoProveedorIa(error: mensajeAsistenteCompartido);
    }
    return _conFuncion(frase: frase, contexto: contexto, historial: historial);
  }

  Future<ResultadoProveedorIa> _conClaveLocal({
    required String clave,
    required String frase,
    required String contexto,
    required List<MensajeChat> historial,
    required bool haySesion,
    String? baseUrl,
    String? modelo,
  }) async {
    final modeloUsado = (modelo == null || modelo.trim().isEmpty)
        ? OpenAiChatService.modelo
        : modelo.trim();
    try {
      final json = await _chat.interpretarJson(
        apiKey: clave,
        systemPrompt: PromptsAsistente.systemPrompt,
        ficha: contexto,
        frase: frase,
        historial: historial,
        baseUrl: baseUrl ?? OpenAiChatService.baseUrlDefecto,
        modeloPedido: modeloUsado,
      );
      if (haySesion) await _cobrarLocal(_chat.ultimoUso, modelo: modeloUsado);
      return ResultadoProveedorIa(
        json: json,
        uso: _chat.ultimoUso,
        medible: true,
      );
    } on ChatIaException catch (error) {
      if (haySesion && error.consulto) {
        await _cobrarLocal(_chat.ultimoUso, modelo: modeloUsado);
      }
      return ResultadoProveedorIa(
        error: error.mensaje,
        uso: _chat.ultimoUso,
        medible: error.consulto,
      );
    } catch (_) {
      return const ResultadoProveedorIa(
        error: 'No pude consultar la API de la IA. No guardé nada.',
      );
    }
  }

  Future<ResultadoProveedorIa> _conFuncion({
    required String frase,
    required String contexto,
    required List<MensajeChat> historial,
  }) async {
    final negocioId = await _memoria.negocioActual();
    final remoto = await _funcion.interpretar(
      frase: frase,
      ficha: contexto,
      negocioId: negocioId,
      historial: historial,
    );
    if (remoto.descontoCupo) {
      await _memoria.anotarUso(
        remoto.uso,
        origen: 'asistente',
        modelo: OpenAiChatService.modelo,
      );
    }
    if (remoto.noConfigurado) {
      return const ResultadoProveedorIa(error: mensajeAsistenteCompartido);
    }
    if (remoto.sinChats) {
      return const ResultadoProveedorIa(error: mensajeSinChats);
    }
    final error = remoto.error;
    if (error != null && error.isNotEmpty) {
      return ResultadoProveedorIa(
        error: error,
        uso: remoto.uso,
        medible: remoto.descontoCupo,
      );
    }
    return ResultadoProveedorIa(
      json: remoto.json,
      uso: remoto.uso,
      medible: true,
    );
  }

  /// La función compartida descuenta sola. Acá solo lo que sale del teléfono.
  Future<void> _cobrarLocal(UsoOpenAi? uso, {required String modelo}) async {
    await _memoria.descontarChat();
    await _memoria.anotarUso(
      uso,
      origen: 'asistente',
      modelo: modelo,
    );
  }
}
