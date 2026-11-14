import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/services/codigo_qr.dart';
import 'package:gestion_pedidos/services/subdominio_tienda.dart';

void main() {
  test('el corrector coincide con el vector clásico de 10 símbolos', () {
    final datos = [
      32,
      91,
      11,
      120,
      209,
      114,
      220,
      77,
      67,
      64,
      236,
      17,
      236,
      17,
      236,
      17,
    ];
    expect(
      CodigoQr.simbolosDeCorreccion(datos, 10),
      [196, 35, 39, 119, 235, 215, 231, 226, 93, 23],
    );
  });

  test('cada slug arma un QR distinto, con los buscadores en las esquinas', () {
    final corta = SubdominioTienda.urlPublica('abc');
    final larga = SubdominioTienda.urlPublica('mi-negocio-de-formosa-123456');
    final a = CodigoQr.modulos(corta);
    final b = CodigoQr.modulos(larga);
    final fija = CodigoQr.modulos(corta, mascara: 0);

    expect(corta, 'https://gexi.com.ar/abc');
    expect(a.length, a.first.length);
    expect(a.length, 25);
    expect(b.length, 33);
    expect(a, isNot(equals(b)));
    expect(fija.length, 25);
    _esperarBuscador(a, 0, 0);
    _esperarBuscador(a, 0, a.length - 7);
    _esperarBuscador(a, a.length - 7, 0);
    _esperarBuscador(b, 0, 0);
  });
}

void _esperarBuscador(List<List<bool>> m, int fila, int columna) {
  for (var dy = 0; dy < 7; dy++) {
    for (var dx = 0; dx < 7; dx++) {
      final borde = dy == 0 || dy == 6 || dx == 0 || dx == 6;
      final centro = dy >= 2 && dy <= 4 && dx >= 2 && dx <= 4;
      expect(m[fila + dy][columna + dx], borde || centro);
    }
  }
}
