import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/data/capital_repository.dart';

void main() {
  test('efectivo si empieza con Efectivo o no dice Transferencia ni Otro', () {
    expect(TotalesCierreCaja.descripcionEsEfectivo(null), isTrue);
    expect(TotalesCierreCaja.descripcionEsEfectivo(''), isTrue);
    expect(
        TotalesCierreCaja.descripcionEsEfectivo('Aporte de capital'), isTrue);
    expect(TotalesCierreCaja.descripcionEsEfectivo('Efectivo'), isTrue);
    expect(TotalesCierreCaja.descripcionEsEfectivo('Efectivo · seña'), isTrue);
    expect(
      TotalesCierreCaja.descripcionEsEfectivo(
          'Efectivo · pasó a transferencia'),
      isTrue,
    );
    expect(TotalesCierreCaja.descripcionEsEfectivo('Transferencia'), isFalse);
    expect(
      TotalesCierreCaja.descripcionEsEfectivo('Transferencia · alquiler'),
      isFalse,
    );
    expect(TotalesCierreCaja.descripcionEsEfectivo('Otro'), isFalse);
    expect(TotalesCierreCaja.descripcionEsEfectivo('Otro · mixto'), isFalse);
    expect(
        TotalesCierreCaja.descripcionEsEfectivo('Cobro de nosotros'), isTrue);
    expect(
        TotalesCierreCaja.descripcionEsEfectivo('pago en otro local'), isFalse);
    expect(TotalesCierreCaja.descripcionEsEfectivo('Cierre de caja'), isTrue);
    expect(TotalesCierreCaja.descripcionEsEfectivo('Compra de Funda'), isTrue);
  });

  test('totales solo de hoy y diferencia contra entradas en efectivo', () {
    final hoy = DateTime(2026, 11, 4, 15);
    final ayer = DateTime(2026, 11, 3, 23);
    final totales = TotalesCierreCaja.de(
      [
        _mov(1, 100, 'entrada', 'Efectivo · venta', hoy),
        _mov(2, 40, 'entrada', 'Transferencia · venta', hoy),
        _mov(3, 15, 'salida', 'Efectivo · flete', hoy),
        _mov(4, 10, 'cobro', 'Efectivo · deuda', hoy),
        _mov(5, 25, 'capital a pagar', 'Compra de Funda', hoy),
        _mov(6, 8, 'capital a cobrar', null, hoy),
        _mov(7, 999, 'entrada', 'Efectivo', ayer),
        _mov(8, 5, 'devolucion', 'Efectivo · pago', hoy),
        _mov(9, 7, 'pago a tercero', 'Efectivo · proveedor', hoy),
        _mov(10, 3, 'aporte', 'Otro · socio', hoy),
      ],
      ahora: hoy,
    );

    expect(totales.entradas, 143);
    expect(totales.salidas, 22);
    expect(totales.cobros, 15);
    expect(totales.aCobrar, 8);
    expect(totales.aPagar, 25);
    expect(totales.entradasEfectivo, 110);
    expect(totales.ingresosTransferencia, 40);
    expect(totales.ingresosOtro, 3);
    expect(totales.salidasEfectivo, 22);

    expect(totales.diferenciaCentavos(80), -3000);
    final falta = totales.ajustePara(80);
    expect(falta, isNotNull);
    expect(falta!.tipo, TiposCapital.salida);
    expect(falta.monto, 30);

    final sobra = totales.ajustePara(130);
    expect(sobra, isNotNull);
    expect(sobra!.tipo, TiposCapital.entrada);
    expect(sobra.monto, 20);
    expect(totales.ajustePara(110), isNull);
  });

  test('el contado vacío no es un error y el negativo no se lee', () {
    expect(TotalesCierreCaja.leerContado(''), isNull);
    expect(TotalesCierreCaja.contadoInvalido(''), isFalse);
    expect(TotalesCierreCaja.leerContado('10,5'), 10.5);
    expect(TotalesCierreCaja.leerContado('0'), 0);
    expect(TotalesCierreCaja.leerContado('-1'), isNull);
    expect(TotalesCierreCaja.contadoInvalido('abc'), isTrue);
  });
}

MovimientoCapitalRegistro _mov(
  int id,
  double monto,
  String tipo,
  String? descripcion,
  DateTime fecha,
) {
  return MovimientoCapitalRegistro(
    id: id,
    persona: 'Ana',
    monto: monto,
    tipo: tipo,
    descripcion: descripcion,
    fecha: fecha,
  );
}
