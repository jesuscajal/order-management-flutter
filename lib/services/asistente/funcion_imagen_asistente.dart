import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/remoto_comun.dart';
import '../openai_chat_service.dart';
import 'memoria_asistente.dart';

/// La función compartida no está desplegada o no tiene el secreto de OpenAI.
const mensajeFotoSinConfigurar =
    'Para generar la foto hace falta configurar el asistente.';

/// No hay sesión: el secreto de Supabase no se puede usar todavía.
const mensajeFotoSinSesion =
    'Iniciá sesión para generar la foto.';

/// Pide la foto de catálogo a `asistente-imagen` con el JWT de la sesión.
///
/// La respuesta trae el JPEG en memoria. No se escribe en `asistente_mensajes`
/// y la función no devuelve la clave.
class FuncionImagenAsistente {
  const FuncionImagenAsistente();

  Future<Uint8List> generar({
    required String nombre,
    String? categoria,
    String? descripcion,
  }) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) {
      throw ChatIaException(mensajeFotoSinSesion);
    }
    try {
      final respuesta = await supabase.functions.invoke(
        'asistente-imagen',
        body: {
          'nombre': nombre,
          if (categoria != null && categoria.trim().isNotEmpty)
            'categoria': categoria.trim(),
          if (descripcion != null && descripcion.trim().isNotEmpty)
            'descripcion': descripcion.trim(),
        },
      );
      final mapa = respuesta.data is Map
          ? Map<String, dynamic>.from(respuesta.data as Map)
          : const <String, dynamic>{};
      final bytes = _bytes(mapa);
      await const MemoriaAsistente().anotarUso(
        UsoOpenAi.desde(mapa['usage'], milisegundos: 0),
        origen: 'foto',
        modelo: mapa['modelo']?.toString() ?? '',
      );
      return bytes;
    } on ChatIaException {
      rethrow;
    } on FunctionException catch (error) {
      throw ChatIaException(_mensajeDe(error.status, error.details));
    } catch (_) {
      RemotoComun.aviso('No se pudo generar la foto de catálogo.');
      throw ChatIaException(
        'No se pudo generar la foto. Revisá la conexión o subí una imagen.',
      );
    }
  }

  Uint8List _bytes(Map<String, dynamic> mapa) {
    if (mapa['error'] == 'imagen_no_configurada') {
      throw ChatIaException(
        _texto(mapa['mensaje']) ?? mensajeFotoSinConfigurar,
      );
    }
    final aviso = _texto(mapa['mensaje']);
    final b64 = mapa['imagen_base64']?.toString().trim() ?? '';
    if (b64.isEmpty) {
      throw ChatIaException(
        aviso ?? 'OpenAI no devolvió la imagen. Podés subir una foto.',
      );
    }
    try {
      final bytes = base64Decode(b64);
      if (bytes.isEmpty) {
        throw ChatIaException(
          'OpenAI no devolvió la imagen. Podés subir una foto.',
        );
      }
      return bytes;
    } catch (error) {
      if (error is ChatIaException) rethrow;
      throw ChatIaException('OpenAI devolvió una imagen que no pude leer.');
    }
  }

  String _mensajeDe(int status, dynamic details) {
    final mapa = _mapa(details);
    final codigo = mapa['error']?.toString() ?? '';
    final mensaje = _texto(mapa['mensaje']);
    if (codigo == 'imagen_no_configurada' || status == 404) {
      return mensaje ?? mensajeFotoSinConfigurar;
    }
    if (mensaje != null) return mensaje;
    if (status == 401 || status == 403) {
      return 'No pude usar la sesión para generar la foto. Volvé a entrar.';
    }
    return 'No pude generar la foto con el asistente compartido. Podés subir una.';
  }

  Map<String, dynamic> _mapa(dynamic details) {
    if (details is Map) return Map<String, dynamic>.from(details);
    if (details is String && details.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  String? _texto(dynamic valor) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isEmpty) return null;
    return texto;
  }
}
