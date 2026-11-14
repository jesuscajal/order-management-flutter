import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/remoto_comun.dart';
import '../backend/supabase_cliente.dart';

/// Correos que pueden abrir el panel. Tiene que coincidir con la lista fija
/// de `resumen_desarrollador` en la migración 0018.
///
/// `jesus.cajal.work@gmail.com` es el contacto del equipo en el README.
/// `jesuscajal49@gmail.com` es la cuenta de Jesús Cajal en la app.
/// `piloto@novaceltec.local` es la cuenta de vista previa de Jesús Cajal.
/// `leocajald@gmail.com` es el dueño de Novaceltec en la base.
const correosDesarrollador = <String>[
  'jesus.cajal.work@gmail.com',
  'jesuscajal49@gmail.com',
  'piloto@novaceltec.local',
  'leocajald@gmail.com',
];

/// True solo si el email de la sesión de Supabase está en [correosDesarrollador].
bool esDesarrollador(String? email) {
  final limpio = email?.trim().toLowerCase() ?? '';
  if (limpio.isEmpty) return false;
  for (final correo in correosDesarrollador) {
    if (correo.toLowerCase() == limpio) return true;
  }
  return false;
}

/// Email de Auth. No usa la sesión guardada en el teléfono.
String? emailSesionDesarrollador() {
  final email = SupabaseListo.cliente?.auth.currentUser?.email?.trim() ?? '';
  return email.isEmpty ? null : email;
}

/// Conteos del panel. Null si esta sesión no es del desarrollador.
class ResumenDesarrollador {
  const ResumenDesarrollador({
    required this.tiendasActivas,
    required this.usuarios,
    required this.tokens,
    required this.chatsDisponibles,
    required this.asistenteSinDatos,
  });

  final int tiendasActivas;
  final int usuarios;
  final int tokens;
  final int chatsDisponibles;

  /// Las tablas del asistente, o la columna de chats, todavía no existen.
  final bool asistenteSinDatos;
}

/// Lee el resumen con la clave anónima y el JWT de la sesión.
/// No usa service role. Si la función 0018 no está aplicada, cuenta solo las
/// filas que RLS deja ver. Si faltan las tablas del asistente, deja esos
/// números en 0 y marca [ResumenDesarrollador.asistenteSinDatos].
Future<ResumenDesarrollador?> cargarResumenDesarrollador() async {
  if (!esDesarrollador(emailSesionDesarrollador())) return null;
  final cliente = SupabaseListo.cliente;
  if (cliente == null) {
    return const ResumenDesarrollador(
      tiendasActivas: 0,
      usuarios: 0,
      tokens: 0,
      chatsDisponibles: 0,
      asistenteSinDatos: true,
    );
  }

  try {
    final respuesta = await cliente.rpc('resumen_desarrollador');
    final fila = _primeraFila(respuesta);
    if (fila == null) return null;
    return ResumenDesarrollador(
      tiendasActivas: enteroRemoto(fila['tiendas_activas']) ?? 0,
      usuarios: enteroRemoto(fila['usuarios']) ?? 0,
      tokens: enteroRemoto(fila['tokens']) ?? 0,
      chatsDisponibles: enteroRemoto(fila['chats_disponibles']) ?? 0,
      asistenteSinDatos: banderaRemota(fila['asistente_sin_datos']),
    );
  } catch (error) {
    if (!_funcionAusente(error)) rethrow;
  }
  return _desdeTablas(cliente);
}

Future<ResumenDesarrollador> _desdeTablas(SupabaseClient cliente) async {
  final negocios = await cliente.from('negocios').select('dueno_email, tienda_activa');
  final miembros = await cliente.from('miembros').select('email');
  final personas = <String>{};
  var tiendas = 0;
  for (final fila in negocios) {
    if (banderaRemota(fila['tienda_activa'])) tiendas++;
    final correo = textoRemoto(fila['dueno_email']).toLowerCase();
    if (correo.isNotEmpty && !correo.endsWith('@equipo.gexi')) {
      personas.add(correo);
    }
  }
  for (final fila in miembros) {
    final correo = textoRemoto(fila['email']).toLowerCase();
    if (correo.isEmpty || correo.endsWith('@equipo.gexi')) continue;
    personas.add(correo);
  }

  var tokens = 0;
  var chats = 0;
  var sinDatos = false;
  try {
    final uso = await cliente
        .from('asistente_uso')
        .select('tokens_entrada, tokens_salida');
    for (final fila in uso) {
      tokens += (enteroRemoto(fila['tokens_entrada']) ?? 0) +
          (enteroRemoto(fila['tokens_salida']) ?? 0);
    }
  } catch (error) {
    if (!_esquemaAsistenteAusente(error)) rethrow;
    sinDatos = true;
    tokens = 0;
  }
  try {
    final cupos = await cliente.from('asistente_cupo').select('chats_disponibles');
    for (final fila in cupos) {
      chats += enteroRemoto(fila['chats_disponibles']) ?? 0;
    }
  } catch (error) {
    if (!_esquemaAsistenteAusente(error)) rethrow;
    sinDatos = true;
    chats = 0;
  }

  return ResumenDesarrollador(
    tiendasActivas: tiendas,
    usuarios: personas.length,
    tokens: tokens,
    chatsDisponibles: chats,
    asistenteSinDatos: sinDatos,
  );
}

Map<String, dynamic>? _primeraFila(dynamic respuesta) {
  if (respuesta is List) {
    if (respuesta.isEmpty) return null;
    final primera = respuesta.first;
    if (primera is Map) return Map<String, dynamic>.from(primera);
    return null;
  }
  if (respuesta is Map) return Map<String, dynamic>.from(respuesta);
  return null;
}

bool _funcionAusente(Object error) {
  final codigo = error is PostgrestException ? (error.code ?? '') : '';
  if (codigo == 'PGRST202' || codigo == '42883') return true;
  final texto = error.toString().toLowerCase();
  return texto.contains('resumen_desarrollador') &&
      (texto.contains('could not find') ||
          texto.contains('does not exist') ||
          texto.contains('schema cache'));
}

bool _esquemaAsistenteAusente(Object error) {
  final codigo = error is PostgrestException ? (error.code ?? '') : '';
  if (codigo == 'PGRST204' ||
      codigo == 'PGRST205' ||
      codigo == '42P01' ||
      codigo == '42703') {
    return true;
  }
  final texto = error.toString().toLowerCase();
  return texto.contains('asistente_uso') ||
      texto.contains('chats_disponibles') ||
      texto.contains('does not exist') ||
      texto.contains('could not find the table') ||
      (texto.contains('could not find the') && texto.contains('column'));
}
