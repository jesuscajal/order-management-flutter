import 'package:drift/drift.dart';

import 'app_database.dart';

/// Textos que se guardan en la columna `tipo` de MovimientosCapital.
class TiposCapital {
  static const entrada = 'entrada';
  static const salida = 'salida';
  static const capitalACobrar = 'capital a cobrar';
  static const devolucion = 'devolucion';

  static const List<String> persistidos = [
    entrada,
    salida,
    capitalACobrar,
    devolucion,
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
      case capitalACobrar:
        return 'Capital a cobrar';
      case devolucion:
        return 'Devolución';
      default:
        return tipo;
    }
  }
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
    required this.saldoDeuda,
  });

  final String persona;
  final double totalEntradas;
  final double totalSalidas;

  /// Capital a cobrar menos devoluciones. Puede ser negativo.
  final double saldoDeuda;
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
  }) {
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

    return database.into(database.movimientosCapital).insert(
          MovimientosCapitalCompanion.insert(
            persona: personaLimpia,
            monto: monto.abs(),
            tipo: TiposCapital.normalizar(tipo),
            descripcion: descripcionValor,
            fecha: Value(fecha ?? DateTime.now()),
          ),
        );
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
          totales.entradas += monto;
        case TiposCapital.salida:
          totales.salidas += monto;
        case TiposCapital.capitalACobrar:
          totales.aCobrar += monto;
        case TiposCapital.devolucion:
          totales.devuelto += monto;
      }
    }

    final resumen = [
      for (final totales in acumulado.values)
        ResumenFinancieroPersona(
          persona: totales.persona,
          totalEntradas: totales.entradas,
          totalSalidas: totales.salidas,
          saldoDeuda: totales.aCobrar - totales.devuelto,
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
