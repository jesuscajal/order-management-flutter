import '../backend/remoto_comun.dart';

/// Modelo local que el panel dejó como única fuente activa.
///
/// [clave] puede ir vacía. No incluye claves de OpenAI.
class ModeloLocalIa {
  const ModeloLocalIa({
    required this.baseUrl,
    required this.modelo,
    required this.clave,
  });

  final String baseUrl;
  final String modelo;
  final String clave;
}

/// Lee la fuente que eligió el panel.
///
/// Si el modelo local está activo, devuelve su dirección y su clave opcional.
/// Si no, devuelve null: el teléfono usa la función compartida y no recibe
/// la clave de OpenAI.
class FuenteIa {
  const FuenteIa();

  Future<ModeloLocalIa?> leerModeloLocal() async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return null;
    try {
      final respuesta = await supabase.rpc('modelo_local_activo');
      final fila = _fila(respuesta);
      if (fila == null) return null;
      final base = fila['base_url']?.toString().trim() ?? '';
      final modelo = fila['modelo']?.toString().trim() ?? '';
      if (base.isEmpty || modelo.isEmpty) return null;
      return ModeloLocalIa(
        baseUrl: base,
        modelo: modelo,
        clave: fila['clave']?.toString().trim() ?? '',
      );
    } catch (_) {
      RemotoComun.aviso('No se pudo leer el modelo local.');
      return null;
    }
  }

  Map<String, dynamic>? _fila(dynamic respuesta) {
    if (respuesta is List) {
      if (respuesta.isEmpty) return null;
      final primera = respuesta.first;
      if (primera is Map) return Map<String, dynamic>.from(primera);
      return null;
    }
    if (respuesta is Map) return Map<String, dynamic>.from(respuesta);
    return null;
  }
}
