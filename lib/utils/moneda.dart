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
