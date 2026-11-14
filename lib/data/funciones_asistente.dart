/// Funciones del asistente que el comerciante prende o apaga.
///
/// Viajan en `apariencia.funcionesAsistente`. Si la clave no está, quedan
/// prendidas: es el comportamiento que el asistente ya tenía.
class FuncionesAsistente {
  const FuncionesAsistente({
    this.consultarStock = true,
    this.anotarVenta = true,
    this.horarioDireccion = true,
    this.ventasHoy = true,
  });

  /// Cuánto queda de un producto, con los datos locales.
  final bool consultarStock;

  /// Armar un pedido o una venta y guardarlo al confirmar.
  final bool anotarVenta;

  /// Decir el horario y la dirección del local, si están cargados.
  final bool horarioDireccion;

  /// Resumir lo vendido hoy, sin consultar al modelo.
  final bool ventasHoy;

  static const clave = 'funcionesAsistente';

  factory FuncionesAsistente.desde(Object? apariencia) {
    if (apariencia is! Map) return const FuncionesAsistente();
    final mapa = Map<String, dynamic>.from(apariencia);
    final crudo = mapa[clave];
    if (crudo is! Map) return const FuncionesAsistente();
    final datos = Map<String, dynamic>.from(crudo);
    bool leer(String nombre) {
      final valor = datos[nombre];
      if (valor is bool) return valor;
      return true;
    }

    return FuncionesAsistente(
      consultarStock: leer('consultarStock'),
      anotarVenta: leer('anotarVenta'),
      horarioDireccion: leer('horarioDireccion'),
      ventasHoy: leer('ventasHoy'),
    );
  }

  FuncionesAsistente copiar({
    bool? consultarStock,
    bool? anotarVenta,
    bool? horarioDireccion,
    bool? ventasHoy,
  }) {
    return FuncionesAsistente(
      consultarStock: consultarStock ?? this.consultarStock,
      anotarVenta: anotarVenta ?? this.anotarVenta,
      horarioDireccion: horarioDireccion ?? this.horarioDireccion,
      ventasHoy: ventasHoy ?? this.ventasHoy,
    );
  }

  Map<String, bool> toJson() => {
        'consultarStock': consultarStock,
        'anotarVenta': anotarVenta,
        'horarioDireccion': horarioDireccion,
        'ventasHoy': ventasHoy,
      };

  @override
  bool operator ==(Object other) {
    return other is FuncionesAsistente &&
        other.consultarStock == consultarStock &&
        other.anotarVenta == anotarVenta &&
        other.horarioDireccion == horarioDireccion &&
        other.ventasHoy == ventasHoy;
  }

  @override
  int get hashCode => Object.hash(
        consultarStock,
        anotarVenta,
        horarioDireccion,
        ventasHoy,
      );
}

const mensajeConsultarStockApagado =
    'Consultar el stock está apagado. Lo podés prender en Tu página, en Asistente.';

const mensajeAnotarVentaApagado =
    'Anotar pedidos y ventas está apagado. Lo podés prender en Tu página, en Asistente.';

const mensajeHorarioApagado =
    'Decir el horario y la dirección está apagado. Lo podés prender en Tu página, en Asistente.';

const mensajeVentasHoyApagado =
    'El resumen de ventas de hoy está apagado. Lo podés prender en Tu página, en Asistente.';

/// Horario y dirección ya cargados. No inventa lo que falta.
String textoHorarioDireccion({
  required String horario,
  required String direccion,
}) {
  final hora = horario.trim();
  final lugar = direccion.trim();
  if (hora.isEmpty && lugar.isEmpty) {
    return 'Todavía no cargaste el horario ni la dirección del local.';
  }
  final partes = <String>[
    hora.isEmpty
        ? 'El horario todavía no está cargado.'
        : 'El horario es: $hora.',
    lugar.isEmpty
        ? 'La dirección todavía no está cargada.'
        : 'La dirección es: $lugar.',
  ];
  return partes.join(' ');
}

/// Pregunta por el local, no por un producto ni por una venta.
bool parecePreguntaHorarioDireccion(String texto) {
  final plano = _plano(texto);
  if (plano.isEmpty) return false;
  if (RegExp(
    r'\b(vendi\w*|vender|vende\w*|pedido|pedidos|stock|inventario|agrega\w*|suma\w*|entra\w*|carga\w*)\b',
  ).hasMatch(plano)) {
    return false;
  }
  return RegExp(
    r'\b(horario|horarios|a que hora|hasta que hora|cuando abren|cuando cierra|cuando cierran|direccion|ubicacion|como llegar|donde queda el local|donde esta el local)\b',
  ).hasMatch(plano);
}

String _plano(String texto) {
  const origen = 'áéíóúüñ';
  const destino = 'aeiouun';
  var salida = texto.toLowerCase().trim();
  for (var i = 0; i < origen.length; i++) {
    salida = salida.replaceAll(origen[i], destino[i]);
  }
  return salida.replaceAll(RegExp(r'\s+'), ' ');
}
