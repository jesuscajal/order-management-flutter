import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cuántas unidades de [hacia] vale 1 unidad de [desde].
///
/// Usa la cotización pública del día. Si las dos monedas son la misma, es 1.
class Cotizacion {
  const Cotizacion._();

  static Future<double> factor({
    required String desde,
    required String hacia,
  }) async {
    final origen = desde.trim().toLowerCase();
    final destino = hacia.trim().toLowerCase();
    if (origen.isEmpty || destino.isEmpty) {
      throw StateError('Falta la moneda para calcular la cotización.');
    }
    if (origen == destino) return 1;
    final urls = [
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/$origen.min.json',
      'https://latest.currency-api.pages.dev/v1/currencies/$origen.min.json',
    ];
    Object? ultimo;
    for (final url in urls) {
      try {
        final respuesta = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 12));
        if (respuesta.statusCode != 200) {
          ultimo = 'respuesta ${respuesta.statusCode}';
          continue;
        }
        final json = jsonDecode(respuesta.body);
        if (json is! Map) continue;
        final tabla = json[origen];
        if (tabla is! Map) continue;
        final crudo = tabla[destino];
        final numero = crudo is num ? crudo.toDouble() : double.tryParse('$crudo');
        if (numero == null || !numero.isFinite || numero <= 0) continue;
        return numero;
      } catch (error) {
        ultimo = error;
      }
    }
    throw StateError(
      'No se pudo leer cuánto vale 1 ${desde.toUpperCase()} en ${hacia.toUpperCase()}. $ultimo',
    );
  }
}
