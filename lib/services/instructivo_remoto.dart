import '../backend/supabase_cliente.dart';
import '../data/instructivo_funciones.dart';

/// Lee el instructivo de la base si es más nuevo que el de la app.
class InstructivoRemoto {
  const InstructivoRemoto();

  static List<GuiaFuncion>? _cache;
  static int _versionCache = 0;

  Future<List<GuiaFuncion>> leer() async {
    if (_cache != null && _versionCache > instructivoVersion) return _cache!;
    final cliente = SupabaseListo.cliente;
    if (cliente == null || cliente.auth.currentUser == null) {
      return instructivoLocal;
    }
    try {
      final filas = await cliente
          .from('instructivo_funciones')
          .select('clave, titulo, texto, palabras, orden, version, interruptor')
          .order('orden')
          .timeout(const Duration(seconds: 6));
      if (filas.isEmpty) return instructivoLocal;
      final version = filas.fold<int>(0, (mayor, fila) {
        final valor = fila['version'];
        final numero = valor is int
            ? valor
            : valor is num
                ? valor.toInt()
                : int.tryParse('$valor') ?? 0;
        return numero > mayor ? numero : mayor;
      });
      if (version <= instructivoVersion) return instructivoLocal;
      final guias = [
        for (final fila in filas)
          if (fila['titulo'] is String && fila['texto'] is String)
            GuiaFuncion.desde(Map<String, dynamic>.from(fila)),
      ].where((guia) => guia.titulo.isNotEmpty && guia.texto.isNotEmpty);
      if (guias.isEmpty) return instructivoLocal;
      _cache = guias.toList();
      _versionCache = version;
      return _cache!;
    } catch (_) {
      return instructivoLocal;
    }
  }
}
