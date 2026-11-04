import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/negocio_local.dart';
import 'remoto_comun.dart';
import 'supabase_cliente.dart';

/// Publica el negocio local en `negocios` y al dueño en `miembros`.
class NegocioRemoto {
  const NegocioRemoto();

  /// Devuelve el mismo id estable que usa [publicar] para la sesión actual.
  String? idParaSesion(NegocioLocal negocio) {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return null;
    final email = cliente.auth.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) return null;
    return _idEstable(email, negocio.codigo);
  }

  /// No hace nada si no hay sesión de Supabase. El guardado local no depende de esto.
  Future<void> publicar(
    NegocioLocal negocio, {
    String? slug,
    bool? tiendaActiva,
    String? whatsapp,
    String? mensajePublico,
  }) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return;
    final email = cliente.auth.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) return;

    final id = _idEstable(email, negocio.codigo);
    final slugFinal = (slug ?? negocio.slug).trim().toLowerCase();
    final whats = (whatsapp ?? negocio.whatsapp).trim();
    final mensaje = (mensajePublico ?? negocio.mensajePublico).trim();
    final activa = tiendaActiva ?? negocio.tiendaActiva;
    await cliente.from('negocios').upsert(
      {
        'id': id,
        'nombre': negocio.nombre,
        'descripcion': negocio.descripcion,
        'codigo': negocio.codigo,
        'rubros': negocio.rubros,
        'plantilla': negocio.plantilla,
        'categorias': negocio.categorias,
        'atributos': negocio.atributos,
        'tipo_tienda': negocio.tipoTienda,
        'configurado': negocio.configurado,
        'dueno_email': email,
        'slug': slugFinal.isEmpty ? null : slugFinal,
        'tienda_activa': activa,
        'whatsapp': whats.isEmpty ? null : whats,
        'mensaje_publico': mensaje.isEmpty ? null : mensaje,
      },
      onConflict: 'id',
    );
    await cliente.from('miembros').upsert(
      {
        'negocio_id': id,
        'email': email,
        'rol': 'administrador',
        'nombre': negocio.nombre,
        'activo': true,
      },
      onConflict: 'negocio_id,email',
    );
    await _publicarEquipo(cliente, id, email, negocio.equipo);
  }

  /// Personas del equipo que ya tienen email. Sin email no hay fila válida.
  Future<void> _publicarEquipo(
    SupabaseClient cliente,
    String negocioId,
    String duenoEmail,
    List<MiembroEquipo> equipo,
  ) async {
    final dueno = duenoEmail.trim().toLowerCase();
    final presentes = <String>{dueno};
    for (final miembro in equipo) {
      final email = miembro.email.trim();
      if (email.isEmpty) continue;
      final clave = email.toLowerCase();
      if (clave == dueno || !presentes.add(clave)) continue;
      final rol = miembro.rol == 'administrador' ? 'administrador' : 'vendedor';
      final datos = <String, dynamic>{
        'negocio_id': negocioId,
        'email': email,
        'rol': rol,
        'nombre': miembro.nombre.trim(),
        'activo': miembro.activo,
      };
      final codigo = miembro.codigo.trim().toUpperCase();
      if (RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(codigo)) {
        datos['codigo_empleado'] = codigo;
      }
      try {
        await cliente.from('miembros').upsert(
          datos,
          onConflict: 'negocio_id,email',
        );
      } catch (error) {
        RemotoComun.aviso('No se pudo guardar un integrante: $error');
      }
    }
    try {
      final filas = await cliente
          .from('miembros')
          .select('id, email')
          .eq('negocio_id', negocioId);
      for (final fila in filas) {
        final email = textoRemoto(fila['email']).toLowerCase();
        if (email.isEmpty || presentes.contains(email)) continue;
        final id = fila['id'];
        if (id == null) continue;
        await cliente.from('miembros').delete().eq('id', id);
      }
    } catch (error) {
      RemotoComun.aviso('No se pudo actualizar el equipo: $error');
    }
  }

  /// UUID v5-like estable por dueño y código, para que crear y confirmar
  /// actualicen la misma fila.
  String _idEstable(String email, String codigo) {
    final semilla = '${email.toLowerCase()}|${codigo.trim().toUpperCase()}';
    final partes = [
      _fnv(semilla, 0x811c9dc5),
      _fnv('$semilla#b', 0x811c9dc5),
      _fnv('$semilla#c', 0x811c9dc5),
      _fnv('$semilla#d', 0x811c9dc5),
    ];
    final hex = partes.map((n) => n.toRadixString(16).padLeft(8, '0')).join();
    final chars = hex.split('');
    chars[12] = '5';
    final variante = (int.parse(chars[16], radix: 16) & 0x3) | 0x8;
    chars[16] = variante.toRadixString(16);
    final s = chars.join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
        '${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  int _fnv(String texto, int semilla) {
    var hash = semilla;
    for (final unit in texto.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
