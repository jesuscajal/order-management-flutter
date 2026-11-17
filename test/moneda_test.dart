import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/utils/moneda.dart';

void main() {
  test('el punto de miles no se lee como decimal', () {
    expect(leerMontoEscrito('20.000'), 20000);
    expect(leerMontoEscrito('20.000,50'), 20000.50);
    expect(leerMontoEscrito('1.000.000'), 1000000);
    expect(leerMontoEscrito('20,50'), 20.50);
    expect(leerMontoEscrito('20.50'), 20.50);
    expect(leerMontoEscrito('10,5'), 10.5);
    expect(formatearMoneda(20000, 'ARS'), 'ARS 20.000,00');
  });
}
