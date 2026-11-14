import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/remoto_comun.dart';
import '../openai_chat_service.dart';
import 'resumen_asistente.dart';

/// Lo que se puede saber del cupo antes de llamar al modelo.
class LecturaCupo {
  const LecturaCupo({required this.haySesion, this.disponibles});

  final bool haySesion;

  /// Null si hay sesión pero no se pudo leer. 0 si no quedan chats.
  final int? disponibles;
}

class MensajeAsistenteGuardado {
  const MensajeAsistenteGuardado({required this.rol, required this.contenido});

  final String rol;
  final String contenido;
}

/// Chat, contexto y cupo del negocio.
///
/// Con sesión escribe en Supabase el mensaje de esta cuenta y este negocio.
/// Sin sesión, o si la nube no responde, lo deja en el teléfono y el chat sigue.
class MemoriaAsistente {
  const MemoriaAsistente();

  static const mensajesAlAbrir = 40;
  static const _claveLocal = 'gexi_chat_asistente_local_v1';

  Future<List<MensajeAsistenteGuardado>> mensajesRecientes() async {
    final ctx = await _contexto();
    final local = await _leerLocal(ctx);
    if (ctx == null) return local;
    try {
      final filas = await ctx.cliente
          .from('asistente_mensajes')
          .select('rol, contenido, usuario_email')
          .eq('negocio_id', ctx.negocioId)
          .eq('usuario_email', ctx.email)
          .order('creado_en', ascending: false)
          .limit(mensajesAlAbrir);
      final remotos = <MensajeAsistenteGuardado>[];
      for (final fila in filas.reversed) {
        final email = textoRemoto(fila['usuario_email']).toLowerCase();
        if (email != ctx.email) continue;
        final mensaje = _mensajeDe(fila['rol'], fila['contenido']);
        if (mensaje != null) remotos.add(mensaje);
      }
      return _unir(remotos, local);
    } catch (error) {
      RemotoComun.aviso('No se pudo leer el chat del asistente: $error');
      return local;
    }
  }

  Future<void> guardarMensaje({
    required String rol,
    required String contenido,
  }) async {
    final texto = _textoGuardable(contenido);
    if (texto == null || (rol != 'user' && rol != 'assistant')) return;
    if (rol == 'assistant' && _esJsonCrudo(texto)) return;
    try {
      final ctx = await _contexto();
      if (ctx != null) {
        try {
          await ctx.cliente.from('asistente_mensajes').insert({
            'negocio_id': ctx.negocioId,
            'usuario_email': ctx.email,
            'rol': rol,
            'contenido': texto,
          });
        } catch (error) {
          RemotoComun.aviso(
            'No se pudo guardar el mensaje del asistente: $error',
          );
        }
      }
      await _guardarLocal(ctx, rol: rol, contenido: texto);
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar el mensaje del asistente: $error');
    }
  }

  Future<String> leerResumen() async {
    final ctx = await _contexto();
    if (ctx == null) return _leerResumenLocal(null);
    try {
      final filas = await ctx.cliente
          .from('asistente_contexto')
          .select('resumen')
          .eq('negocio_id', ctx.negocioId)
          .limit(1);
      final remoto = filas.isEmpty ? '' : textoRemoto(filas.first['resumen']);
      if (remoto.isNotEmpty) return remoto;
      return _leerResumenLocal(ctx);
    } catch (error) {
      RemotoComun.aviso('No se pudo leer el contexto del asistente: $error');
      return _leerResumenLocal(ctx);
    }
  }

  Future<void> actualizarResumen({
    required String frase,
    List<String> productos = const [],
  }) async {
    try {
      final anterior = await leerResumen();
      final resumen = actualizarResumenAsistente(
        anterior: anterior,
        frase: frase,
        productos: productos,
      );
      final ctx = await _contexto();
      if (ctx == null) {
        await _guardarResumenLocal(null, resumen);
        return;
      }
      try {
        await ctx.cliente.from('asistente_contexto').upsert(
          {
            'negocio_id': ctx.negocioId,
            'resumen': resumen,
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'negocio_id',
        );
      } catch (error) {
        RemotoComun.aviso(
          'No se pudo guardar el contexto del asistente: $error',
        );
        await _guardarResumenLocal(ctx, resumen);
      }
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar el contexto del asistente: $error');
    }
  }

  Future<String?> negocioActual() async {
    final ctx = await _contexto();
    return ctx?.negocioId;
  }

  /// Crea la fila en 30 si no existe. No descuenta.
  Future<LecturaCupo> leerCupo() async {
    final ctx = await _contexto();
    if (ctx == null) return const LecturaCupo(haySesion: false);
    try {
      final actual = await _leerNumero(ctx);
      if (actual != null) {
        return LecturaCupo(haySesion: true, disponibles: actual);
      }
      try {
        await ctx.cliente.from('asistente_cupo').insert({
          'negocio_id': ctx.negocioId,
        });
      } catch (_) {
        // Otra sesión pudo crearla en el mismo momento.
      }
      final creado = await _leerNumero(ctx);
      return LecturaCupo(haySesion: true, disponibles: creado);
    } catch (error) {
      RemotoComun.aviso('No se pudo leer el cupo del asistente: $error');
      return const LecturaCupo(haySesion: true);
    }
  }

  /// Descuenta uno. Null si no hay sesión. -2 si ya estaba en cero.
  Future<int?> descontarChat() async {
    final ctx = await _contexto();
    if (ctx == null) return null;
    try {
      final resultado = await ctx.cliente.rpc(
        'reservar_chat_asistente',
        params: {'p_negocio': ctx.negocioId},
      );
      if (resultado is int) return resultado;
      if (resultado is num) return resultado.toInt();
      return int.tryParse(textoRemoto(resultado));
    } catch (error) {
      RemotoComun.aviso('No se pudo descontar un chat: $error');
      return null;
    }
  }

  Future<void> anotarUso(
    UsoOpenAi? uso, {
    String origen = 'asistente',
    String modelo = '',
  }) async {
    final ctx = await _contexto();
    if (ctx == null) return;
    final lugar = origen.trim();
    try {
      await ctx.cliente.from('asistente_uso').insert({
        'negocio_id': ctx.negocioId,
        'usuario_email': ctx.email,
        'tokens_entrada': uso?.entrada ?? 0,
        'tokens_salida': uso?.salida ?? 0,
        'tokens_cache': uso?.enCache ?? 0,
        'origen': lugar.isEmpty ? 'asistente' : lugar,
        'modelo': modelo.trim(),
      });
    } catch (error) {
      RemotoComun.aviso('No se pudo anotar el uso del asistente: $error');
    }
  }

  Future<int?> _leerNumero(_ContextoAsistente ctx) async {
    final filas = await ctx.cliente
        .from('asistente_cupo')
        .select('chats_disponibles')
        .eq('negocio_id', ctx.negocioId)
        .limit(1);
    if (filas.isEmpty) return null;
    return enteroRemoto(filas.first['chats_disponibles']);
  }

  Future<_ContextoAsistente?> _contexto() async {
    final cliente = RemotoComun.cliente;
    if (cliente == null) return null;
    final email = cliente.auth.currentUser?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return null;
    final negocioId = await _negocioVisible(cliente);
    if (negocioId == null) return null;
    return _ContextoAsistente(
      cliente: cliente,
      negocioId: negocioId,
      email: email,
    );
  }

  /// El id del negocio que esta sesión puede ver. Si el id local no coincide
  /// (un empleado no es el dueño), usa el negocio que deja pasar RLS.
  Future<String?> _negocioVisible(SupabaseClient cliente) async {
    final candidato = await RemotoComun.negocioId();
    if (candidato != null && candidato.isNotEmpty) {
      try {
        final filas = await cliente
            .from('negocios')
            .select('id')
            .eq('id', candidato)
            .limit(1);
        if (filas.isNotEmpty) return candidato;
      } catch (error) {
        RemotoComun.aviso('No se pudo confirmar el negocio: $error');
      }
    }
    try {
      final filas = await cliente.from('negocios').select('id').limit(1);
      if (filas.isEmpty) return null;
      final id = textoRemoto(filas.first['id']);
      return id.isEmpty ? null : id;
    } catch (error) {
      RemotoComun.aviso('No se pudo ubicar el negocio del asistente: $error');
      return null;
    }
  }

  String _cubo(_ContextoAsistente? ctx) {
    if (ctx == null) return 'sin-sesion';
    return '${ctx.email}\n${ctx.negocioId}';
  }

  Future<List<MensajeAsistenteGuardado>> _leerLocal(
    _ContextoAsistente? ctx,
  ) async {
    final doc = await _leerDocumento();
    final mensajes = doc['mensajes'];
    if (mensajes is! Map) return const [];
    final lista = mensajes[_cubo(ctx)];
    if (lista is! List) return const [];
    return [
      for (final item in lista)
        if (item is Map)
          if (_mensajeDe(item['rol'], item['contenido']) != null)
            _mensajeDe(item['rol'], item['contenido'])!,
    ];
  }

  Future<void> _guardarLocal(
    _ContextoAsistente? ctx, {
    required String rol,
    required String contenido,
  }) async {
    final doc = await _leerDocumento();
    final crudo = doc['mensajes'];
    final mensajes = crudo is Map
        ? Map<String, dynamic>.from(crudo)
        : <String, dynamic>{};
    final cubo = _cubo(ctx);
    final actual = mensajes[cubo];
    final lista = actual is List
        ? [for (final item in actual) item]
        : <dynamic>[];
    lista.add({'rol': rol, 'contenido': contenido});
    final recorte = lista.length > mensajesAlAbrir
        ? lista.sublist(lista.length - mensajesAlAbrir)
        : lista;
    mensajes[cubo] = recorte;
    doc['mensajes'] = mensajes;
    await _escribirDocumento(doc);
  }

  Future<String> _leerResumenLocal(_ContextoAsistente? ctx) async {
    final doc = await _leerDocumento();
    final resumenes = doc['resumenes'];
    if (resumenes is! Map) return '';
    return textoRemoto(resumenes[_cubo(ctx)]);
  }

  Future<void> _guardarResumenLocal(
    _ContextoAsistente? ctx,
    String resumen,
  ) async {
    final doc = await _leerDocumento();
    final crudo = doc['resumenes'];
    final resumenes = crudo is Map
        ? Map<String, dynamic>.from(crudo)
        : <String, dynamic>{};
    resumenes[_cubo(ctx)] = resumen;
    doc['resumenes'] = resumenes;
    await _escribirDocumento(doc);
  }

  Future<Map<String, dynamic>> _leerDocumento() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_claveLocal);
      if (crudo == null || crudo.isEmpty) return {};
      final decoded = jsonDecode(crudo);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      RemotoComun.aviso('No se pudo leer el chat local: $error');
    }
    return {};
  }

  Future<void> _escribirDocumento(Map<String, dynamic> doc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveLocal, jsonEncode(doc));
  }

  MensajeAsistenteGuardado? _mensajeDe(dynamic rolCrudo, dynamic contenidoCrudo) {
    final rol = textoRemoto(rolCrudo);
    final contenido = textoRemoto(contenidoCrudo);
    if ((rol != 'user' && rol != 'assistant') || contenido.isEmpty) {
      return null;
    }
    return MensajeAsistenteGuardado(rol: rol, contenido: contenido);
  }

  List<MensajeAsistenteGuardado> _unir(
    List<MensajeAsistenteGuardado> remotos,
    List<MensajeAsistenteGuardado> locales,
  ) {
    if (remotos.isEmpty) return locales;
    if (locales.isEmpty) return remotos;
    final unidos = [...remotos];
    var desde = 0;
    for (final mensaje in locales) {
      final encontrado = unidos.indexWhere(
        (otro) => otro.rol == mensaje.rol && otro.contenido == mensaje.contenido,
        desde,
      );
      if (encontrado >= 0) {
        desde = encontrado + 1;
        continue;
      }
      unidos.add(mensaje);
    }
    if (unidos.length <= mensajesAlAbrir) return unidos;
    return unidos.sublist(unidos.length - mensajesAlAbrir);
  }
}

String? _textoGuardable(String contenido) {
  var texto = contenido.trim();
  if (texto.isEmpty || _esSql(texto) || _esFotoBase64(texto)) return null;
  texto = texto.replaceAll(RegExp(r'\bsk-[A-Za-z0-9_-]{8,}'), '');
  texto = texto.replaceAll(
    RegExp(r'data:image/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=\s]+'),
    '',
  );
  texto = texto.replaceAll(RegExp(r'[A-Za-z0-9+/]{200,}={0,2}'), '');
  texto = texto.trim();
  if (texto.isEmpty || _esSql(texto) || _esFotoBase64(texto)) return null;
  return texto;
}

bool _esJsonCrudo(String texto) {
  final limpio = texto.trim();
  if (!limpio.startsWith('{') || !limpio.endsWith('}')) return false;
  return limpio.contains('"acciones"') || limpio.contains('"sql"');
}

bool _esFotoBase64(String texto) {
  final limpio = texto.trim();
  if (limpio.startsWith('data:image/')) return true;
  return limpio.length > 800 &&
      RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(limpio);
}

bool _esSql(String texto) {
  return RegExp(
    r'\b(select\s+\S[\s\S]{0,240}?\sfrom\s|insert\s+into\s|update\s+\S+\s+set\s|delete\s+from\s|drop\s+(table|database)\s|alter\s+table\s)\b',
    caseSensitive: false,
  ).hasMatch(texto);
}

class _ContextoAsistente {
  const _ContextoAsistente({
    required this.cliente,
    required this.negocioId,
    required this.email,
  });

  final SupabaseClient cliente;
  final String negocioId;
  final String email;
}
