enum TipoMovimiento { ingreso, egreso, prestamo, devolucion }

class MovimientoCapital {
  final String id;
  final String persona;
  final double monto;
  final DateTime fecha;
  final TipoMovimiento tipo;
  final String descripcion;

  MovimientoCapital({
    required this.id,
    required this.persona,
    required this.monto,
    required this.fecha,
    required this.tipo,
    required this.descripcion,
  });

  // Método para crear un ID único
  static String generarId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Método para crear un nuevo movimiento
  static MovimientoCapital crear({
    required String persona,
    required double monto,
    required TipoMovimiento tipo,
    required String descripcion,
  }) {
    return MovimientoCapital(
      id: generarId(),
      persona: persona,
      monto: monto,
      fecha: DateTime.now(),
      tipo: tipo,
      descripcion: descripcion,
    );
  }
}

// Clase para agrupar los movimientos por persona
class ResumenDeudor {
  final String persona;
  final List<MovimientoCapital> movimientos;

  ResumenDeudor({required this.persona, required this.movimientos});

  double get totalPrestado => movimientos
      .where((m) => m.tipo == TipoMovimiento.prestamo)
      .fold(0, (sum, m) => sum + m.monto);

  double get totalDevuelto => movimientos
      .where((m) => m.tipo == TipoMovimiento.devolucion)
      .fold(0, (sum, m) => sum + m.monto);

  double get montoAdeudado => totalPrestado - totalDevuelto;

  MovimientoCapital? get ultimoMovimiento {
    if (movimientos.isEmpty) return null;
    return movimientos.reduce((a, b) => a.fecha.isAfter(b.fecha) ? a : b);
  }
}
