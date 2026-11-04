import 'ids_remotos.dart';
import 'remoto_comun.dart';

/// Copia clientes e historial de estado. Si no hay sesión, no hace nada.
class ClientesRemoto {
  const ClientesRemoto._();

  static Future<void> replicar({
    required int localId,
    required String nombre,
    String? telefono,
    String? email,
    String? notas,
    bool esPotencial = false,
    String estadoPago = 'pendiente',
  }) async {
    if (!RemotoComun.activo) return;
    try {
      await _guardar(
        localId: localId,
        nombre: nombre,
        telefono: telefono,
        email: email,
        notas: notas,
        esPotencial: esPotencial,
        estadoPago: estadoPago,
      ).timeout(const Duration(seconds: 15));
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar el cliente en la nube: $error');
    }
  }

  static Future<void> borrar(int localId) async {
    if (!RemotoComun.activo) return;
    try {
      const ids = IdsRemotos();
      final uuid = await ids.leer(IdsRemotos.cliente, '$localId');
      if (uuid == null) return;
      final supabase = RemotoComun.cliente;
      if (supabase == null) return;
      await supabase.from('clientes').delete().eq('id', uuid);
      await ids.olvidar(IdsRemotos.cliente, '$localId');
    } catch (error) {
      RemotoComun.aviso('No se pudo borrar el cliente en la nube: $error');
    }
  }

  static Future<void> replicarHistorial({
    required int historialLocalId,
    required int clienteLocalId,
    required String anterior,
    required String nuevo,
  }) async {
    if (!RemotoComun.activo) return;
    try {
      const ids = IdsRemotos();
      final ya = await ids.leer(
        IdsRemotos.historialCliente,
        '$historialLocalId',
      );
      if (ya != null) return;
      final clienteId = await ids.leer(IdsRemotos.cliente, '$clienteLocalId');
      if (clienteId == null) return;
      final supabase = RemotoComun.cliente;
      if (supabase == null) return;
      final creada = await supabase
          .from('historial_clientes')
          .insert({
            'cliente_id': clienteId,
            'estado_anterior': anterior.trim().isEmpty ? 'pendiente' : anterior.trim(),
            'estado_nuevo': nuevo.trim().isEmpty ? 'pendiente' : nuevo.trim(),
          })
          .select('id')
          .single();
      final id = textoRemoto(creada['id']);
      if (id.isEmpty) return;
      await ids.guardar(IdsRemotos.historialCliente, '$historialLocalId', id);
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar el historial del cliente: $error');
    }
  }
}

Future<void> _guardar({
  required int localId,
  required String nombre,
  String? telefono,
  String? email,
  String? notas,
  required bool esPotencial,
  required String estadoPago,
}) async {
  final nombreLimpio = nombre.trim();
  if (nombreLimpio.isEmpty) return;
  final supabase = RemotoComun.cliente;
  if (supabase == null) return;
  final negocioId = await RemotoComun.negocioId();
  if (negocioId == null) return;

  final datos = <String, dynamic>{
    'negocio_id': negocioId,
    'nombre': nombreLimpio,
    'telefono': _vacio(telefono),
    'email': _vacio(email),
    'notas': _vacio(notas),
    'es_potencial': esPotencial,
    'estado_pago': estadoPago.trim().isEmpty ? 'pendiente' : estadoPago.trim(),
  };
  const ids = IdsRemotos();
  final mapeado = await ids.leer(IdsRemotos.cliente, '$localId');
  if (mapeado != null) {
    datos.remove('negocio_id');
    await supabase.from('clientes').update(datos).eq('id', mapeado);
    return;
  }
  final creada = await supabase
      .from('clientes')
      .insert(datos)
      .select('id')
      .single();
  final id = textoRemoto(creada['id']);
  if (id.isEmpty) return;
  await ids.guardar(IdsRemotos.cliente, '$localId', id);
}

String? _vacio(String? valor) {
  final texto = valor?.trim() ?? '';
  return texto.isEmpty ? null : texto;
}
