import 'ids_remotos.dart';
import 'remoto_comun.dart';

/// Copia un movimiento recién guardado en Drift a `movimientos_capital`.
///
/// El pago parcial llega acá como cualquier otro movimiento, con tipo
/// `devolucion` y un monto que ya no supera el saldo. Si no hay remoto o
/// no hay negocio, no hace nada y no lanza.
class CapitalRemoto {
  static Future<void> replicar({
    int? localId,
    required String persona,
    required double monto,
    required String tipo,
    String? descripcion,
  }) async {
    try {
      final supabase = RemotoComun.cliente;
      if (supabase == null) return;
      final personaLimpia = persona.trim();
      if (personaLimpia.isEmpty) return;
      if (monto == 0 || monto.isNaN || monto.isInfinite) return;

      const ids = IdsRemotos();
      if (localId != null) {
        final ya = await ids.leer(IdsRemotos.capital, '$localId');
        if (ya != null) return;
      }

      final negocioId = await RemotoComun.negocioId();
      if (negocioId == null) return;

      final nota = descripcion?.trim();
      final datos = <String, dynamic>{
        'negocio_id': negocioId,
        'persona': personaLimpia,
        'monto': monto.abs(),
        'tipo': tipo,
      };
      if (nota != null && nota.isNotEmpty) {
        datos['descripcion'] = nota;
      }
      final medio = medioDeDescripcion(nota);
      if (medio != null) datos['medio_pago'] = medio;

      final creada = await supabase
          .from('movimientos_capital')
          .insert(datos)
          .select('id')
          .single()
          .timeout(const Duration(seconds: 15));
      final id = textoRemoto(creada['id']);
      if (localId != null && id.isNotEmpty) {
        await ids.guardar(IdsRemotos.capital, '$localId', id);
      }
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar el movimiento de capital: $error');
    }
  }
}
