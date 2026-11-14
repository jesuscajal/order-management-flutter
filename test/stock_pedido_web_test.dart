import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/data/stock_pedido_web.dart';

void main() {
  test('la salida del pedido web nombra el uuid una sola vez', () {
    const uuid = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';
    final texto = StockPedidoWeb.descripcion(uuid);
    expect(
      texto,
      'Salida por pedido web aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    );
    expect(StockPedidoWeb.uuidDe(texto), 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
    expect(StockPedidoWeb.uuidDe('Salida por pedido 4'), isNull);
    expect(StockPedidoWeb.uuidDe('Salida por pedido web '), isNull);
  });
}
