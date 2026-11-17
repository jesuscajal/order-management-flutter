import 'package:drift/drift.dart';

import '../backend/capital_remoto.dart';
import '../utils/moneda.dart';
import '../backend/stock_remoto.dart';
import 'app_database.dart';

/// Textos que se guardan en la columna `tipo` de MovimientosCapital.
class TiposCapital {
  static const entrada = 'entrada';
  static const salida = 'salida';
  static const capitalACobrar = 'capital a cobrar';
  static const capitalAPagar = 'capital a pagar';
  static const devolucion = 'devolucion';
  static const aporte = 'aporte';
  static const retiro = 'retiro';
  static const gasto = 'gasto';
  static const cobro = 'cobro';
  static const pagoATercero = 'pago a tercero';
  static const ventaCobrada = 'venta cobrada';

  static const List<String> persistidos = [
    aporte,
    retiro,
    gasto,
    entrada,
    salida,
    capitalACobrar,
    capitalAPagar,
    devolucion,
    cobro,
    pagoATercero,
    ventaCobrada,
  ];

  static const Map<String, String> _sinonimos = {
    'entrada': entrada,
    'ingreso': entrada,
    'inversión': entrada,
    'inversion': entrada,
    'salida': salida,
    'egreso': salida,
    'transferencia': salida,
    'capital a cobrar': capitalACobrar,
    'prestamo': capitalACobrar,
    'préstamo': capitalACobrar,
    'devolucion': devolucion,
    'devolución': devolucion,
    'devolucion / pago': devolucion,
    'devolución / pago': devolucion,
    'pago': devolucion,
    'pago parcial': devolucion,
    'aporte': aporte,
    'retiro': retiro,
    'gasto': gasto,
    'cobro': cobro,
    'cobro de deuda': cobro,
    'capital a pagar': capitalAPagar,
    'a pagar': capitalAPagar,
    'pago a tercero': pagoATercero,
    'pago de deuda': pagoATercero,
    'venta cobrada': ventaCobrada,
  };

  static String normalizar(String tipo) {
    final clave = tipo.trim().toLowerCase();
    return _sinonimos[clave] ?? clave;
  }

  static String etiqueta(String tipo) {
    switch (normalizar(tipo)) {
      case entrada:
        return 'Entrada';
      case salida:
        return 'Salida';
      case aporte:
        return 'Aporte';
      case retiro:
        return 'Retiro';
      case gasto:
        return 'Gasto';
      case capitalACobrar:
        return 'A cobrar';
      case capitalAPagar:
        return 'A pagar';
      case devolucion:
        return 'Devolución / pago';
      case cobro:
        return 'Cobro de deuda';
      case pagoATercero:
        return 'Pago de deuda';
      case ventaCobrada:
        return 'Venta cobrada';
      default:
        return tipo;
    }
  }

  /// Qué hace cada tipo en el resumen. Sirve para el alta de movimientos.
  static String ayuda(String tipo) {
    switch (normalizar(tipo)) {
      case entrada:
      case aporte:
      case ventaCobrada:
        return 'Suma plata a la caja. No cambia la deuda.';
      case salida:
      case retiro:
      case gasto:
        return 'Resta plata de la caja. No cambia la deuda.';
      case capitalACobrar:
        return 'Anota una deuda a cobrar.';
      case capitalAPagar:
        return 'Anota una deuda a pagar.';
      case devolucion:
      case cobro:
        return 'Cobra una deuda y baja el saldo a cobrar.';
      case pagoATercero:
        return 'Paga una deuda y baja el saldo a pagar.';
      default:
        return 'Elegí el tipo de movimiento.';
    }
  }
}

/// Pago rechazado: monto vacío, negativo o mayor al saldo.
class PagoParcialInvalido implements Exception {
  PagoParcialInvalido(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Saldos que se muestran después de registrar un pago parcial.
class ResultadoPagoParcial {
  const ResultadoPagoParcial({
    required this.saldoAnterior,
    required this.pago,
    required this.saldoNuevo,
  });

  final double saldoAnterior;
  final double pago;
  final double saldoNuevo;
}

/// Movimiento reducido para armar el resumen, venga de memoria o de SQLite.
class MovimientoParaResumen {
  const MovimientoParaResumen({
    required this.persona,
    required this.monto,
    required this.tipo,
  });

  final String persona;
  final double monto;
  final String tipo;
}

/// Totales de RF-022 para una persona.
class ResumenFinancieroPersona {
  const ResumenFinancieroPersona({
    required this.persona,
    required this.totalEntradas,
    required this.totalSalidas,
    required this.totalPagos,
    required this.saldoDeuda,
    this.saldoAPagar = 0,
  });

  final String persona;
  final double totalEntradas;
  final double totalSalidas;

  /// Devoluciones y pagos parciales. Descuentan [saldoDeuda].
  final double totalPagos;

  /// Capital a cobrar menos devoluciones. Puede ser negativo.
  final double saldoDeuda;

  /// Deudas del negocio hacia otras personas.
  final double saldoAPagar;
}

/// Fila leída de MovimientosCapital, sin exponer el tipo generado de Drift.
class MovimientoCapitalRegistro {
  const MovimientoCapitalRegistro({
    required this.id,
    required this.persona,
    required this.monto,
    required this.tipo,
    required this.descripcion,
    required this.fecha,
  });

  final int id;
  final String persona;
  final double monto;
  final String tipo;
  final String? descripcion;
  final DateTime fecha;
}

class _TotalesPersona {
  _TotalesPersona(this.persona);

  final String persona;
  double entradas = 0;
  double salidas = 0;
  double aCobrar = 0;
  double devuelto = 0;
  double aPagar = 0;
  double pagadoATerceros = 0;
}

/// Lectura y alta sobre la tabla MovimientosCapital. No modifica el esquema.
class CapitalRepository {
  CapitalRepository(this.database);

  final AppDatabase database;

  Future<List<MovimientoCapitalRegistro>> listar() async {
    final consulta = database.select(database.movimientosCapital);
    consulta.orderBy([
      (tabla) => OrderingTerm.desc(tabla.fecha),
      (tabla) => OrderingTerm.desc(tabla.id),
    ]);
    final filas = await consulta.get();
    return [
      for (final fila in filas)
        MovimientoCapitalRegistro(
          id: fila.id,
          persona: fila.persona,
          monto: fila.monto,
          tipo: fila.tipo,
          descripcion: fila.descripcion,
          fecha: fila.fecha,
        ),
    ];
  }

  Future<int> registrar({
    required String persona,
    required double monto,
    required String tipo,
    String? descripcion,
    DateTime? fecha,
  }) async {
    final personaLimpia = persona.trim();
    if (personaLimpia.isEmpty) {
      throw ArgumentError('La persona es obligatoria');
    }
    if (monto == 0 || monto.isNaN || monto.isInfinite) {
      throw ArgumentError('El monto es inválido');
    }

    final descripcionLimpia = descripcion?.trim();
    final Value<String?> descripcionValor =
        descripcionLimpia == null || descripcionLimpia.isEmpty
            ? const Value.absent()
            : Value(descripcionLimpia);
    final tipoNormalizado = TiposCapital.normalizar(tipo);
    final montoGuardado = monto.abs();

    final id = await database.into(database.movimientosCapital).insert(
          MovimientosCapitalCompanion.insert(
            persona: personaLimpia,
            monto: montoGuardado,
            tipo: tipoNormalizado,
            descripcion: descripcionValor,
            fecha: Value(fecha ?? DateTime.now()),
          ),
        );

    ReplicaScope.diferir(
      () => CapitalRemoto.replicar(
        localId: id,
        persona: personaLimpia,
        monto: montoGuardado,
        tipo: tipoNormalizado,
        descripcion: (descripcionLimpia == null || descripcionLimpia.isEmpty)
            ? null
            : descripcionLimpia,
      ),
    );
    return id;
  }

  static int enCentavos(double valor) {
    if (valor.isNaN || valor.isInfinite) return 0;
    return (valor * 100).round();
  }

  /// Lee el texto del formulario. Rechaza vacío o que no sea un número.
  static double leerMontoPago(String texto) {
    if (texto.trim().isEmpty) {
      throw PagoParcialInvalido('Ingresá un monto.');
    }
    final monto = leerMontoEscrito(texto);
    if (monto == null) {
      throw PagoParcialInvalido('El monto no es válido.');
    }
    return monto;
  }

  /// El pago tiene que ser positivo y no puede pasar el saldo a cobrar.
  static ResultadoPagoParcial calcularPagoParcial({
    required double saldo,
    required double monto,
  }) {
    if (monto.isNaN || monto.isInfinite) {
      throw PagoParcialInvalido('El monto no es válido.');
    }
    if (monto < 0) {
      throw PagoParcialInvalido('El monto no puede ser negativo.');
    }
    final saldoCent = enCentavos(saldo);
    final pagoCent = enCentavos(monto);
    if (pagoCent <= 0) {
      throw PagoParcialInvalido('El monto tiene que ser mayor a cero.');
    }
    if (saldoCent <= 0) {
      throw PagoParcialInvalido('Esta persona no tiene saldo para cobrar.');
    }
    if (pagoCent > saldoCent) {
      throw PagoParcialInvalido(
        'El pago no puede ser mayor al saldo (${textoMonto(saldoCent / 100)}).',
      );
    }
    return ResultadoPagoParcial(
      saldoAnterior: saldoCent / 100,
      pago: pagoCent / 100,
      saldoNuevo: (saldoCent - pagoCent) / 100,
    );
  }

  static double saldoDePersona(
    Iterable<MovimientoParaResumen> movimientos,
    String persona,
  ) {
    final clave = persona.trim().toLowerCase();
    for (final fila in resumir(movimientos)) {
      if (fila.persona.trim().toLowerCase() == clave) {
        return fila.saldoDeuda;
      }
    }
    return 0;
  }

  /// Anota un pago como [TiposCapital.devolucion], que ya descuenta la deuda.
  Future<ResultadoPagoParcial> registrarPagoParcial({
    required String persona,
    required double monto,
    String? descripcion,
  }) async {
    final filas = await listar();
    final saldo = saldoDePersona(
      [
        for (final fila in filas)
          MovimientoParaResumen(
            persona: fila.persona,
            monto: fila.monto,
            tipo: fila.tipo,
          ),
      ],
      persona,
    );
    final resultado = calcularPagoParcial(saldo: saldo, monto: monto);
    final nota = descripcion?.trim();
    await registrar(
      persona: persona,
      monto: resultado.pago,
      tipo: TiposCapital.devolucion,
      descripcion: (nota == null || nota.isEmpty) ? 'Pago parcial' : nota,
    );
    return resultado;
  }

  /// Agrupa por persona: entradas, salidas y saldo de deuda.
  static List<ResumenFinancieroPersona> resumir(
    Iterable<MovimientoParaResumen> movimientos,
  ) {
    final acumulado = <String, _TotalesPersona>{};

    for (final movimiento in movimientos) {
      final visible = movimiento.persona.trim();
      if (visible.isEmpty) continue;
      final totales = acumulado.putIfAbsent(
        visible.toLowerCase(),
        () => _TotalesPersona(visible),
      );
      final monto = movimiento.monto.abs();
      switch (TiposCapital.normalizar(movimiento.tipo)) {
        case TiposCapital.entrada:
        case TiposCapital.aporte:
        case TiposCapital.ventaCobrada:
          totales.entradas += monto;
        case TiposCapital.salida:
        case TiposCapital.retiro:
        case TiposCapital.gasto:
          totales.salidas += monto;
        case TiposCapital.capitalACobrar:
          totales.aCobrar += monto;
        case TiposCapital.devolucion:
          totales.devuelto += monto;
        case TiposCapital.cobro:
          totales.devuelto += monto;
          totales.entradas += monto;
        case TiposCapital.capitalAPagar:
          totales.aPagar += monto;
        case TiposCapital.pagoATercero:
          totales.pagadoATerceros += monto;
          totales.salidas += monto;
      }
    }

    final resumen = [
      for (final totales in acumulado.values)
        ResumenFinancieroPersona(
          persona: totales.persona,
          totalEntradas: totales.entradas,
          totalSalidas: totales.salidas,
          totalPagos: totales.devuelto,
          saldoDeuda: totales.aCobrar - totales.devuelto,
          saldoAPagar: totales.aPagar - totales.pagadoATerceros,
        ),
    ]..sort(
        (a, b) => a.persona.toLowerCase().compareTo(b.persona.toLowerCase()),
      );
    return resumen;
  }

  static String textoMonto(double valor) {
    final redondeado = (valor * 100).round() / 100;
    final absoluto = redondeado.abs();
    final texto = absoluto == absoluto.truncateToDouble()
        ? absoluto.toInt().toString()
        : absoluto.toStringAsFixed(2);
    if (redondeado < 0) return '-$texto';
    return texto;
  }
}

/// Tipo y monto de un ajuste opcional del cierre. No es un movimiento todavía.
class AjusteCierreCaja {
  const AjusteCierreCaja({required this.tipo, required this.monto});

  final String tipo;
  final double monto;
}

/// Totales del día para el cierre de caja.
///
/// No escribe filas y no cambia el texto de los tipos ya guardados. Las sumas
/// siguen los mismos tipos que [CapitalRepository.resumir], con cobros aparte
/// para poder mostrarlos solos.
class TotalesCierreCaja {
  const TotalesCierreCaja({
    required this.entradas,
    required this.salidas,
    required this.cobros,
    required this.aCobrar,
    required this.aPagar,
    required this.entradasEfectivo,
    required this.salidasEfectivo,
    this.ingresosTransferencia = 0,
    this.ingresosOtro = 0,
  });

  static const descripcionAjuste = 'Cierre de caja';
  static const personaAjuste = 'Caja';

  /// Entrada, aporte y venta cobrada. Sin cobros, para no mezclar la fila.
  final double entradas;

  /// Salida, retiro, gasto y pago a tercero.
  final double salidas;

  /// Cobro y devolución.
  final double cobros;

  /// Capital a cobrar cargado en el día. No es el saldo neto.
  final double aCobrar;

  /// Capital a pagar cargado en el día. No es el saldo neto.
  final double aPagar;

  /// Lo que [CapitalRepository.resumir] suma como entrada y además es efectivo:
  /// entrada, aporte, venta cobrada y cobro.
  final double entradasEfectivo;

  /// Salidas en efectivo. Se muestran, y no se restan de [entradasEfectivo].
  final double salidasEfectivo;

  /// Entradas, aportes, ventas cobradas y cobros que dicen Transferencia.
  final double ingresosTransferencia;

  /// Los mismos tipos cuando la descripción dice Otro.
  final double ingresosOtro;

  static final RegExp _palabraOtro = RegExp(
    r'(^|[^a-z0-9áéíóúüñ])otro([^a-z0-9áéíóúüñ]|$)',
  );

  static bool esMismoDia(DateTime fecha, DateTime dia) {
    return fecha.year == dia.year &&
        fecha.month == dia.month &&
        fecha.day == dia.day;
  }

  /// Efectivo: empieza con Efectivo, o no dice Transferencia ni Otro.
  ///
  /// El medio se guarda al principio de la descripción, como en la pantalla
  /// de capital (`Efectivo · nota`). Si empieza con Efectivo, cuenta aunque
  /// el resto nombre otro medio.
  static bool descripcionEsEfectivo(String? descripcion) {
    final texto = (descripcion ?? '').trim().toLowerCase();
    if (texto.startsWith('efectivo')) return true;
    if (texto.contains('transferencia')) return false;
    if (_palabraOtro.hasMatch(texto)) return false;
    return true;
  }

  /// Vacío no es un error: todavía no contó. Un texto que no es un número
  /// mayor o igual a cero sí lo es.
  static double? leerContado(String texto) {
    if (texto.trim().isEmpty) return null;
    final valor = leerMontoEscrito(texto);
    if (valor == null || valor < 0) return null;
    return CapitalRepository.enCentavos(valor) / 100;
  }

  static bool contadoInvalido(String texto) {
    if (texto.trim().isEmpty) return false;
    return leerContado(texto) == null;
  }

  static TotalesCierreCaja de(
    Iterable<MovimientoCapitalRegistro> movimientos, {
    DateTime? ahora,
  }) {
    final momento = ahora ?? DateTime.now();
    var entradas = 0.0;
    var salidas = 0.0;
    var cobros = 0.0;
    var aCobrar = 0.0;
    var aPagar = 0.0;
    var entradasEfectivo = 0.0;
    var salidasEfectivo = 0.0;
    var ingresosTransferencia = 0.0;
    var ingresosOtro = 0.0;

    void sumarIngreso(double monto, String? descripcion) {
      final texto = (descripcion ?? '').trim().toLowerCase();
      if (descripcionEsEfectivo(descripcion)) {
        entradasEfectivo += monto;
      } else if (texto.contains('transferencia')) {
        ingresosTransferencia += monto;
      } else {
        ingresosOtro += monto;
      }
    }

    for (final movimiento in movimientos) {
      if (!esMismoDia(movimiento.fecha, momento)) continue;
      final monto = movimiento.monto.abs();
      if (monto == 0 || monto.isNaN || monto.isInfinite) continue;
      final efectivo = descripcionEsEfectivo(movimiento.descripcion);
      switch (TiposCapital.normalizar(movimiento.tipo)) {
        case TiposCapital.entrada:
        case TiposCapital.aporte:
        case TiposCapital.ventaCobrada:
          entradas += monto;
          sumarIngreso(monto, movimiento.descripcion);
        case TiposCapital.cobro:
          cobros += monto;
          sumarIngreso(monto, movimiento.descripcion);
        case TiposCapital.devolucion:
          cobros += monto;
        case TiposCapital.salida:
        case TiposCapital.retiro:
        case TiposCapital.gasto:
        case TiposCapital.pagoATercero:
          salidas += monto;
          if (efectivo) salidasEfectivo += monto;
        case TiposCapital.capitalACobrar:
          aCobrar += monto;
        case TiposCapital.capitalAPagar:
          aPagar += monto;
      }
    }

    return TotalesCierreCaja(
      entradas: entradas,
      salidas: salidas,
      cobros: cobros,
      aCobrar: aCobrar,
      aPagar: aPagar,
      entradasEfectivo: entradasEfectivo,
      salidasEfectivo: salidasEfectivo,
      ingresosTransferencia: ingresosTransferencia,
      ingresosOtro: ingresosOtro,
    );
  }

  /// Contado menos entradas en efectivo, en centavos. Positivo: sobra.
  int diferenciaCentavos(double contado) {
    return CapitalRepository.enCentavos(contado) -
        CapitalRepository.enCentavos(entradasEfectivo);
  }

  /// Entrada si sobra efectivo, salida si falta. Null si la diferencia es cero.
  AjusteCierreCaja? ajustePara(double contado) {
    if (contado.isNaN || contado.isInfinite || contado < 0) return null;
    final delta = diferenciaCentavos(contado);
    if (delta == 0) return null;
    if (delta > 0) {
      return AjusteCierreCaja(tipo: TiposCapital.entrada, monto: delta / 100);
    }
    return AjusteCierreCaja(tipo: TiposCapital.salida, monto: (-delta) / 100);
  }
}
