/// Estados del pedido alineados al TIF.
///
/// En la base se guardan como texto en `pedidos.estado`. Los valores viejos
/// no se migran: [PedidoEstados.leer] los interpreta al mostrarlos.
enum PedidoEstado {
  pendiente,
  pendienteDePago,
  pagado,
  confirmado,
  entregado,
  cancelado,
}

extension PropiedadesPedidoEstado on PedidoEstado {
  /// Texto canónico que se escribe en la columna `estado`.
  String get texto {
    switch (this) {
      case PedidoEstado.pendiente:
        return 'pendiente';
      case PedidoEstado.pendienteDePago:
        return 'pendiente de pago';
      case PedidoEstado.pagado:
        return 'pagado';
      case PedidoEstado.confirmado:
        return 'confirmado';
      case PedidoEstado.entregado:
        return 'entregado';
      case PedidoEstado.cancelado:
        return 'cancelado';
    }
  }

  String get etiqueta {
    switch (this) {
      case PedidoEstado.pendiente:
        return 'Pendiente';
      case PedidoEstado.pendienteDePago:
        return 'Pendiente de pago';
      case PedidoEstado.pagado:
        return 'Pagado';
      case PedidoEstado.confirmado:
        return 'Confirmado';
      case PedidoEstado.entregado:
        return 'Entregado';
      case PedidoEstado.cancelado:
        return 'Cancelado';
    }
  }

  /// Texto del chip que dispara la transición hacia este estado.
  String get accion {
    switch (this) {
      case PedidoEstado.pendiente:
        return 'Volver a pendiente';
      case PedidoEstado.pendienteDePago:
        return 'Pendiente de pago';
      case PedidoEstado.pagado:
        return 'Marcar pagado';
      case PedidoEstado.confirmado:
        return 'Confirmar';
      case PedidoEstado.entregado:
        return 'Entregar';
      case PedidoEstado.cancelado:
        return 'Cancelar';
    }
  }

  /// Transiciones válidas desde este estado. Entregado y cancelado cierran.
  List<PedidoEstado> get siguientes {
    switch (this) {
      case PedidoEstado.pendiente:
        return const [
          PedidoEstado.pendienteDePago,
          PedidoEstado.pagado,
          PedidoEstado.confirmado,
          PedidoEstado.cancelado,
        ];
      case PedidoEstado.pendienteDePago:
        return const [
          PedidoEstado.pagado,
          PedidoEstado.confirmado,
          PedidoEstado.cancelado,
        ];
      case PedidoEstado.pagado:
        return const [
          PedidoEstado.confirmado,
          PedidoEstado.entregado,
          PedidoEstado.cancelado,
        ];
      case PedidoEstado.confirmado:
        return const [
          PedidoEstado.entregado,
          PedidoEstado.cancelado,
        ];
      case PedidoEstado.entregado:
      case PedidoEstado.cancelado:
        return const [];
    }
  }

  bool get reservaStock =>
      this == PedidoEstado.confirmado || this == PedidoEstado.entregado;
}

/// Lectura y escritura de los textos de [PedidoEstado].
class PedidoEstados {
  const PedidoEstados._();

  static const valores = <String>[
    'pendiente',
    'pendiente de pago',
    'pagado',
    'confirmado',
    'entregado',
    'cancelado',
  ];

  /// Interpreta el texto guardado. No reescribe la fila.
  ///
  /// `en proceso` y `en curso` se leen como confirmado.
  /// `completado` se lee como entregado.
  static PedidoEstado? leer(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pendiente':
        return PedidoEstado.pendiente;
      case 'pendiente de pago':
      case 'pendiente_de_pago':
        return PedidoEstado.pendienteDePago;
      case 'pagado':
        return PedidoEstado.pagado;
      case 'confirmado':
      case 'en proceso':
      case 'en_proceso':
      case 'en curso':
      case 'en_curso':
        return PedidoEstado.confirmado;
      case 'entregado':
      case 'completado':
        return PedidoEstado.entregado;
      case 'cancelado':
        return PedidoEstado.cancelado;
      default:
        return null;
    }
  }

  static bool esCanonico(String raw) => valores.contains(raw.trim().toLowerCase());

  /// Etiqueta visible. El valor viejo `en proceso` se muestra como En curso.
  static String etiqueta(String raw) {
    final limpio = raw.trim().toLowerCase();
    switch (limpio) {
      case 'en proceso':
      case 'en_proceso':
      case 'en curso':
      case 'en_curso':
        return 'En curso';
      case 'completado':
        return 'Entregado';
      default:
        final estado = leer(raw);
        if (estado != null) return estado.etiqueta;
        if (limpio.isEmpty) return 'Sin estado';
        return limpio[0].toUpperCase() + limpio.substring(1);
    }
  }

  static List<PedidoEstado> siguientesDe(String almacenado) {
    final actual = leer(almacenado);
    if (actual == null) return const [PedidoEstado.cancelado];
    return actual.siguientes;
  }

  static bool puedePasar(String almacenado, PedidoEstado destino) {
    final actual = leer(almacenado);
    if (actual == null) return destino == PedidoEstado.cancelado;
    if (actual == destino) return false;
    return actual.siguientes.contains(destino);
  }

  /// `true` solo si esta versión ya descontó stock al guardar ese texto.
  /// Los valores viejos (`en proceso`, `completado`) no cuentan.
  static bool yaDescontoStock(String almacenado) {
    final limpio = almacenado.trim().toLowerCase();
    return limpio == PedidoEstado.confirmado.texto ||
        limpio == PedidoEstado.entregado.texto;
  }

  /// Seña 0: pendiente. Seña parcial: pendiente de pago. Seña = total: pagado.
  static String estadoInicial({
    required double sena,
    required double total,
  }) {
    if (sena < 0) {
      throw ArgumentError('La seña no puede ser negativa.');
    }
    if (sena > total + 0.009) {
      throw ArgumentError('La seña no puede ser mayor al total.');
    }
    if (total > 0 && (total - sena) <= 0.009) {
      return PedidoEstado.pagado.texto;
    }
    if (sena > 0.009) return PedidoEstado.pendienteDePago.texto;
    return PedidoEstado.pendiente.texto;
  }
}

String pedidoEstadoToString(PedidoEstado estado) => estado.etiqueta;

PedidoEstado pedidoEstadoFromString(String estado) =>
    PedidoEstados.leer(estado) ?? PedidoEstado.pendiente;
