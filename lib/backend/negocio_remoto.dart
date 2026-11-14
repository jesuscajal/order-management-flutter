import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/apariencia_tienda.dart';
import '../data/diseno_tienda.dart';
import '../data/funciones_asistente.dart';
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

  /// Negocio de la nube cuyo dueño es la sesión actual. Null si todavía no hay.
  Future<NegocioLocal?> delDueno() async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return null;
    final email = cliente.auth.currentUser?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return null;
    final filas = await cliente.from('negocios').select();
    Map<String, dynamic>? fila;
    for (final item in filas) {
      if (item is! Map) continue;
      final mapa = Map<String, dynamic>.from(item);
      if (textoRemoto(mapa['dueno_email']).toLowerCase() == email) {
        fila = mapa;
        break;
      }
    }
    if (fila == null) return null;
    final id = textoRemoto(fila['id']);
    final equipo = <MiembroEquipo>[];
    if (id.isNotEmpty) {
      try {
        final miembros = await cliente
            .from('miembros')
            .select('email, rol, nombre, codigo_empleado, activo')
            .eq('negocio_id', id);
        for (final item in miembros) {
          if (item is! Map) continue;
          final mapa = Map<String, dynamic>.from(item);
          final correo = textoRemoto(mapa['email']);
          if (correo.isEmpty || correo.toLowerCase() == email) continue;
          final nombre = textoRemoto(mapa['nombre']);
          if (nombre.isEmpty) continue;
          equipo.add(
            MiembroEquipo(
              nombre: nombre,
              rol: textoRemoto(mapa['rol']) == 'administrador'
                  ? 'administrador'
                  : 'vendedor',
              activo:
                  mapa['activo'] == null ? true : banderaRemota(mapa['activo']),
              codigo: textoRemoto(mapa['codigo_empleado']).toUpperCase(),
              email:
                  correo.toLowerCase().endsWith('@equipo.gexi') ? '' : correo,
            ),
          );
        }
      } catch (error) {
        RemotoComun.aviso('No se pudo traer el equipo: $error');
      }
    }
    final nombre = textoRemoto(fila['nombre']);
    if (nombre.isEmpty) return null;
    return NegocioLocal(
      nombre: nombre,
      descripcion: textoRemoto(fila['descripcion']),
      codigo: textoRemoto(fila['codigo']),
      rol: 'administrador',
      configurado: banderaRemota(fila['configurado']),
      plantilla: textoRemoto(fila['plantilla']),
      rubros: _textos(fila['rubros']),
      categorias: _textos(fila['categorias']),
      atributos: _textos(fila['atributos']),
      tipoTienda: textoRemoto(fila['tipo_tienda']).isEmpty
          ? 'Catálogo'
          : textoRemoto(fila['tipo_tienda']),
      duenoEmail: textoRemoto(fila['dueno_email']),
      slug: textoRemoto(fila['slug']),
      tiendaActiva: banderaRemota(fila['tienda_activa']),
      whatsapp: textoRemoto(fila['whatsapp']),
      mensajePublico: textoRemoto(fila['mensaje_publico']),
      horario: textoRemoto(fila['horario']),
      aliasCobro: textoRemoto(fila['alias_cobro']),
      logoUrl: textoRemoto(fila['logo_url']),
      facebookUrl: textoRemoto(fila['facebook_url']),
      instagramUrl: textoRemoto(fila['instagram_url']),
      mapsUrl: textoRemoto(fila['maps_url']),
      latitud: _coord(fila['latitud']),
      longitud: _coord(fila['longitud']),
      asistenteListo: _asistenteDe(fila['apariencia']),
      equipo: equipo.take(NegocioLocal.cupoEquipo).toList(),
      moneda: NegocioLocal.normalizarMoneda(textoRemoto(fila['moneda'])),
      pais: textoRemoto(fila['pais']).toUpperCase(),
      nacionalidad: textoRemoto(fila['nacionalidad']),
      apariencia: AparienciaTienda.desde(fila['apariencia']),
      diseno: DisenoTienda.desdeApariencia(
        fila['apariencia'],
        rubros: _textos(fila['rubros']),
      ),
      funciones: FuncionesAsistente.desde(fila['apariencia']),
    );
  }

  /// El empleado entra con el código en un teléfono nuevo.
  /// La función de la base le asigna la fila y después se baja el negocio.
  Future<NegocioLocal?> reclamarCodigo(String codigo) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return null;
    final email = cliente.auth.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) return null;
    final limpio = codigo.trim().toUpperCase();
    final id = await cliente.rpc(
      'unirse_por_codigo',
      params: {'p_codigo': limpio},
    );
    final negocioId = textoRemoto(id);
    if (negocioId.isEmpty) return null;
    return _bajar(cliente, email, negocioId);
  }

  /// Negocio en el que esta cuenta ya es empleada, para otro teléfono.
  Future<NegocioLocal?> delEquipo() async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return null;
    final email = cliente.auth.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) return null;
    final filas = await cliente
        .from('miembros')
        .select('negocio_id')
        .eq('email', email.toLowerCase())
        .limit(1);
    if (filas.isEmpty) return null;
    final negocioId = textoRemoto(filas.first['negocio_id']);
    if (negocioId.isEmpty) return null;
    return _bajar(cliente, email, negocioId);
  }

  Future<NegocioLocal?> _bajar(
    SupabaseClient cliente,
    String email,
    String negocioId,
  ) async {
    final filas =
        await cliente.from('negocios').select().eq('id', negocioId).limit(1);
    if (filas.isEmpty) return null;
    final fila = Map<String, dynamic>.from(filas.first as Map);
    final equipo = <MiembroEquipo>[];
    var rol = 'vendedor';
    try {
      final miembros = await cliente
          .from('miembros')
          .select('email, rol, nombre, codigo_empleado, activo')
          .eq('negocio_id', negocioId);
      for (final item in miembros) {
        final mapa = Map<String, dynamic>.from(item as Map);
        final correo = textoRemoto(mapa['email']);
        final nombre = textoRemoto(mapa['nombre']);
        if (nombre.isEmpty) continue;
        final esPropio = correo.toLowerCase() == email.toLowerCase();
        final rolMiembro = textoRemoto(mapa['rol']) == 'administrador'
            ? 'administrador'
            : 'vendedor';
        if (esPropio) rol = rolMiembro;
        if (correo.toLowerCase() ==
            textoRemoto(fila['dueno_email']).toLowerCase()) {
          continue;
        }
        equipo.add(
          MiembroEquipo(
            nombre: nombre,
            rol: rolMiembro,
            activo:
                mapa['activo'] == null ? true : banderaRemota(mapa['activo']),
            codigo: textoRemoto(mapa['codigo_empleado']).toUpperCase(),
            email: esPropio || correo.toLowerCase().endsWith('@equipo.gexi')
                ? (esPropio ? email : '')
                : correo,
          ),
        );
      }
    } catch (error) {
      RemotoComun.aviso('No se pudo traer el equipo: $error');
    }
    final nombre = textoRemoto(fila['nombre']);
    if (nombre.isEmpty) return null;
    final propio = equipo.where(
      (miembro) => miembro.email.toLowerCase() == email.toLowerCase(),
    );
    final resto = equipo.where(
      (miembro) => miembro.email.toLowerCase() != email.toLowerCase(),
    );
    final ordenado =
        [...propio, ...resto].take(NegocioLocal.cupoEquipo).toList();
    return NegocioLocal(
      nombre: nombre,
      descripcion: textoRemoto(fila['descripcion']),
      codigo: textoRemoto(fila['codigo']),
      rol: rol,
      configurado: banderaRemota(fila['configurado']),
      plantilla: textoRemoto(fila['plantilla']),
      rubros: _textos(fila['rubros']),
      categorias: _textos(fila['categorias']),
      atributos: _textos(fila['atributos']),
      tipoTienda: textoRemoto(fila['tipo_tienda']).isEmpty
          ? 'Catálogo'
          : textoRemoto(fila['tipo_tienda']),
      duenoEmail: textoRemoto(fila['dueno_email']),
      slug: textoRemoto(fila['slug']),
      tiendaActiva: banderaRemota(fila['tienda_activa']),
      whatsapp: textoRemoto(fila['whatsapp']),
      mensajePublico: textoRemoto(fila['mensaje_publico']),
      horario: textoRemoto(fila['horario']),
      aliasCobro: textoRemoto(fila['alias_cobro']),
      logoUrl: textoRemoto(fila['logo_url']),
      facebookUrl: textoRemoto(fila['facebook_url']),
      instagramUrl: textoRemoto(fila['instagram_url']),
      mapsUrl: textoRemoto(fila['maps_url']),
      latitud: _coord(fila['latitud']),
      longitud: _coord(fila['longitud']),
      asistenteListo: _asistenteDe(fila['apariencia']),
      equipo: ordenado,
      moneda: NegocioLocal.normalizarMoneda(textoRemoto(fila['moneda'])),
      pais: textoRemoto(fila['pais']).toUpperCase(),
      nacionalidad: textoRemoto(fila['nacionalidad']),
      apariencia: AparienciaTienda.desde(fila['apariencia']),
      diseno: DisenoTienda.desdeApariencia(
        fila['apariencia'],
        rubros: _textos(fila['rubros']),
      ),
      funciones: FuncionesAsistente.desde(fila['apariencia']),
    );
  }

  List<String> _textos(Object? valor) {
    if (valor is! List) return const [];
    return [
      for (final item in valor)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
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
    final fila = <String, dynamic>{
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
      'horario': negocio.horario.trim(),
      'alias_cobro':
          negocio.aliasCobro.trim().isEmpty ? null : negocio.aliasCobro.trim(),
      'logo_url':
          negocio.logoUrl.trim().isEmpty ? null : negocio.logoUrl.trim(),
      'facebook_url': negocio.facebookUrl.trim().isEmpty
          ? null
          : negocio.facebookUrl.trim(),
      'instagram_url': negocio.instagramUrl.trim().isEmpty
          ? null
          : negocio.instagramUrl.trim(),
      'maps_url':
          negocio.mapsUrl.trim().isEmpty ? null : negocio.mapsUrl.trim(),
      'latitud': negocio.latitud,
      'longitud': negocio.longitud,
      'moneda': NegocioLocal.normalizarMoneda(negocio.moneda),
      'pais': negocio.pais.trim().isEmpty
          ? null
          : negocio.pais.trim().toUpperCase(),
      'nacionalidad': negocio.nacionalidad.trim().isEmpty
          ? null
          : negocio.nacionalidad.trim(),
      'apariencia': _aparienciaPublica(negocio),
    };
    try {
      await cliente.from('negocios').upsert(fila, onConflict: 'id');
    } catch (error) {
      final texto = error.toString().toLowerCase();
      final filaSinColumnasNuevas = Map<String, dynamic>.from(fila);
      var quito = false;
      if (texto.contains('moneda')) {
        filaSinColumnasNuevas.remove('moneda');
        quito = true;
      }
      if (texto.contains('pais') || texto.contains('nacionalidad')) {
        filaSinColumnasNuevas.remove('pais');
        filaSinColumnasNuevas.remove('nacionalidad');
        quito = true;
      }
      if (texto.contains('apariencia')) {
        filaSinColumnasNuevas.remove('apariencia');
        quito = true;
      }
      if (texto.contains('logo_url')) {
        filaSinColumnasNuevas.remove('logo_url');
        quito = true;
      }
      if (texto.contains('alias_cobro')) {
        filaSinColumnasNuevas.remove('alias_cobro');
        quito = true;
      }
      if (texto.contains('horario')) {
        filaSinColumnasNuevas.remove('horario');
        final portada =
            (filaSinColumnasNuevas['mensaje_publico'] as String?)?.trim() ?? '';
        if (portada.isEmpty && negocio.horario.trim().isNotEmpty) {
          filaSinColumnasNuevas['mensaje_publico'] = negocio.horario.trim();
        }
        quito = true;
      }
      if (texto.contains('facebook_url') ||
          texto.contains('instagram_url') ||
          texto.contains('maps_url') ||
          texto.contains('latitud') ||
          texto.contains('longitud')) {
        filaSinColumnasNuevas.remove('facebook_url');
        filaSinColumnasNuevas.remove('instagram_url');
        filaSinColumnasNuevas.remove('maps_url');
        filaSinColumnasNuevas.remove('latitud');
        filaSinColumnasNuevas.remove('longitud');
        quito = true;
      }
      if (!quito) rethrow;
      await cliente
          .from('negocios')
          .upsert(filaSinColumnasNuevas, onConflict: 'id');
    }
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
      final codigo = miembro.codigo.trim().toUpperCase();
      final real = miembro.email.trim();
      final email = real.isNotEmpty
          ? real
          : (RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(codigo)
              ? 'codigo.$codigo@equipo.gexi'
              : '');
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

  /// Vuelve a la versión anterior del mismo negocio. Solo el dueño.
  ///
  /// El resultado ya quedó en `apariencia.layout`. Hay que guardarlo en el
  /// teléfono con [NegocioStore.guardarDiseno] para que el próximo publicado
  /// no pise ese diseño con una copia vieja.
  Future<DisenoTienda> activarDisenoAnterior(String negocioId) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) {
      throw StateError('No hay sesión para restaurar el diseño.');
    }
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No encontramos el negocio para restaurar el diseño.');
    }
    final respuesta = await cliente.rpc(
      'activar_diseno_anterior',
      params: {'p_negocio_id': id},
    );
    return DisenoTienda.desdeJson(respuesta);
  }

  /// True cuando esta base todavía no tiene la columna `negocios.moneda`.
  static bool columnaMonedaAusente(Object error) {
    final texto = error.toString().toLowerCase();
    if (!texto.contains('moneda')) return false;
    return texto.contains('pgrst204') ||
        texto.contains('42703') ||
        texto.contains('schema cache') ||
        texto.contains('does not exist') ||
        texto.contains('no existe') ||
        texto.contains('could not find');
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

/// El asistente y el diseño viajan dentro de `apariencia`, que ya es jsonb.
/// El diseño queda en la clave `layout`. Sin columna nueva.
Map<String, dynamic> _aparienciaPublica(NegocioLocal negocio) {
  return {
    ...negocio.aparienciaConDiseno(),
    if (negocio.asistenteListo != null) 'asistente': negocio.asistenteListo,
  };
}

bool? _asistenteDe(Object? apariencia) {
  if (apariencia is! Map || !apariencia.containsKey('asistente')) return null;
  final valor = apariencia['asistente'];
  if (valor is bool) return valor;
  return null;
}

double? _coord(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor?.toString() ?? '');
}
