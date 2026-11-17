import '../data/paises_latam.dart';

/// Formato fijo en español: código ISO, miles con punto y decimales con coma.
/// Siempre dos decimales. Ejemplo: `ARS 3.000.000,00`.
const monedaPorDefecto = 'USD';

/// Devuelve un código de América Latina (o EUR). Cualquier otro valor queda en USD.
String codigoMoneda(String? codigo) => normalizarMonedaLatam(codigo);

String formatearMoneda(double valor, String codigo) {
  final iso = codigoMoneda(codigo);
  final seguro = valor.isFinite ? valor : 0.0;
  final negativo = seguro < 0;
  final fijo = seguro.abs().toStringAsFixed(2);
  final punto = fijo.indexOf('.');
  final entera = fijo.substring(0, punto);
  final decimales = fijo.substring(punto + 1);
  final miles = StringBuffer();
  for (var i = 0; i < entera.length; i++) {
    if (i > 0 && (entera.length - i) % 3 == 0) miles.write('.');
    miles.write(entera[i]);
  }
  final cuerpo = '${miles.toString()},$decimales';
  if (negativo && cuerpo != '0,00') return '-$iso $cuerpo';
  return '$iso $cuerpo';
}

/// Lee un importe como se escribe en la app: miles con punto y decimales con coma.
///
/// `20.000` y `20.000,00` son 20000. `20,50` y `20.50` son 20,50.
double? leerMontoEscrito(String raw) {
  var texto = raw.trim().replaceAll(RegExp(r'\s'), '');
  if (texto.isEmpty) return null;
  final negativo = texto.startsWith('-');
  if (negativo) texto = texto.substring(1);
  texto = texto.replaceAll(RegExp(r'[^0-9,.]'), '');
  if (texto.isEmpty) return null;

  final tieneComa = texto.contains(',');
  final tienePunto = texto.contains('.');
  if (tieneComa && tienePunto) {
    if (texto.lastIndexOf(',') > texto.lastIndexOf('.')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    } else {
      texto = texto.replaceAll(',', '');
    }
  } else if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(texto)) {
    texto = texto.replaceAll(RegExp(r'[.,]'), '');
  } else if (tieneComa) {
    texto = texto.replaceAll(',', '.');
  }

  final valor = double.tryParse(texto);
  if (valor == null || valor.isNaN || valor.isInfinite) return null;
  return negativo ? -valor : valor;
}
