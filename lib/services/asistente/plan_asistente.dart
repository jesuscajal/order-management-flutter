import 'dart:convert';
import 'dart:typed_data';

import '../../utils/moneda.dart';

/// Acciones que el asistente deja pendientes hasta que la persona confirma.
///
/// El modelo solo propone. Este plan no toca la base.
enum TipoAccionPlan { entradaStock, crearProducto, venta }

/// incompleto: falta un dato. ambiguo: hay varios productos y no se elige.
/// listo: se puede mostrar el resumen único y confirmar.
enum EstadoPlanAsistente { incompleto, listo, ambiguo }

/// El único dato que se está preguntando. El resto del plan queda guardado.
enum DatoFaltante {
  nombre,
  producto,
  categoria,
  cantidad,
  costo,
  precioVenta,
  medio,
}

const _ausente = Object();

/// Opción tocable: un producto, una categoría o un medio de cobro.
class OpcionPlan {
  const OpcionPlan({
    required this.id,
    required this.etiqueta,
    this.detalle = '',
    this.productoId,
    this.precioCompra,
    this.precioVenta,
    this.stock,
    this.categoria,
    this.fotoUrl,
    this.fotoBytes,
  });

  final String id;
  final String etiqueta;
  final String detalle;
  final int? productoId;
  final double? precioCompra;
  final double? precioVenta;
  final int? stock;
  final String? categoria;

  /// URL http(s) para la miniatura. No entra en el JSON de acciones.
  final String? fotoUrl;

  /// Bytes locales si no hay URL. No entra en el JSON de acciones.
  final Uint8List? fotoBytes;
}

/// Una operación todavía no ejecutada.
class AccionPlan {
  const AccionPlan({
    required this.tipo,
    required this.nombre,
    this.cantidad,
    this.costoUnitario,
    this.precioVenta,
    this.precioVentaExplicito = false,
    this.costoDesdeTotal = false,
    this.categoria,
    this.medio,
    this.cliente,
    this.productoId,
    this.nombreConfirmado,
    this.crear = false,
    this.buscado = false,
    this.omitir = false,
    this.origenCreacion,
    this.costoHistorico,
    this.stockConocido,
    this.pideFoto = false,
  });

  final TipoAccionPlan tipo;
  final String nombre;
  final int? cantidad;
  final double? costoUnitario;
  final double? precioVenta;

  /// true si la persona dijo el precio de venta. Si no, se usa el del producto.
  final bool precioVentaExplicito;

  /// true si [costoUnitario] ya salió de costo total / cantidad.
  final bool costoDesdeTotal;
  final String? categoria;

  /// "efectivo" o "transferencia".
  final String? medio;
  final String? cliente;
  final int? productoId;
  final String? nombreConfirmado;

  /// Hay que crear el producto antes de cargar stock o vender.
  final bool crear;

  /// Ya se buscó en el catálogo. No se vuelve a buscar ni se elige otro.
  final bool buscado;

  /// El producto ya existía y esta acción no escribe.
  final bool omitir;

  /// Índice de la acción que crea el mismo producto en este plan.
  final int? origenCreacion;
  final double? costoHistorico;
  final int? stockConocido;

  /// El producto va a la página y todavía no tiene foto.
  final bool pideFoto;

  bool get esAltaNueva =>
      !omitir &&
      productoId == null &&
      origenCreacion == null &&
      (crear || tipo == TipoAccionPlan.crearProducto);

  AccionPlan copiar({
    TipoAccionPlan? tipo,
    String? nombre,
    Object? cantidad = _ausente,
    Object? costoUnitario = _ausente,
    Object? precioVenta = _ausente,
    bool? precioVentaExplicito,
    bool? costoDesdeTotal,
    Object? categoria = _ausente,
    Object? medio = _ausente,
    Object? cliente = _ausente,
    Object? productoId = _ausente,
    Object? nombreConfirmado = _ausente,
    bool? crear,
    bool? buscado,
    bool? omitir,
    Object? origenCreacion = _ausente,
    Object? costoHistorico = _ausente,
    Object? stockConocido = _ausente,
    bool? pideFoto,
  }) {
    return AccionPlan(
      tipo: tipo ?? this.tipo,
      nombre: nombre ?? this.nombre,
      cantidad: identical(cantidad, _ausente) ? this.cantidad : cantidad as int?,
      costoUnitario: identical(costoUnitario, _ausente)
          ? this.costoUnitario
          : costoUnitario as double?,
      precioVenta: identical(precioVenta, _ausente)
          ? this.precioVenta
          : precioVenta as double?,
      precioVentaExplicito: precioVentaExplicito ?? this.precioVentaExplicito,
      costoDesdeTotal: costoDesdeTotal ?? this.costoDesdeTotal,
      categoria:
          identical(categoria, _ausente) ? this.categoria : categoria as String?,
      medio: identical(medio, _ausente) ? this.medio : medio as String?,
      cliente: identical(cliente, _ausente) ? this.cliente : cliente as String?,
      productoId:
          identical(productoId, _ausente) ? this.productoId : productoId as int?,
      nombreConfirmado: identical(nombreConfirmado, _ausente)
          ? this.nombreConfirmado
          : nombreConfirmado as String?,
      crear: crear ?? this.crear,
      buscado: buscado ?? this.buscado,
      omitir: omitir ?? this.omitir,
      origenCreacion: identical(origenCreacion, _ausente)
          ? this.origenCreacion
          : origenCreacion as int?,
      costoHistorico: identical(costoHistorico, _ausente)
          ? this.costoHistorico
          : costoHistorico as double?,
      stockConocido: identical(stockConocido, _ausente)
          ? this.stockConocido
          : stockConocido as int?,
      pideFoto: pideFoto ?? this.pideFoto,
    );
  }
}

/// Plan en memoria. Vive en el estado del chat hasta Confirmar o Cancelar.
class PlanAsistente {
  const PlanAsistente({
    required this.acciones,
    this.estado = EstadoPlanAsistente.incompleto,
    this.indicePendiente,
    this.pregunta,
    this.opciones = const [],
    this.datoFaltante,
  });

  final List<AccionPlan> acciones;
  final EstadoPlanAsistente estado;
  final int? indicePendiente;
  final String? pregunta;
  final List<OpcionPlan> opciones;
  final DatoFaltante? datoFaltante;

  bool get listo => estado == EstadoPlanAsistente.listo;

  bool get tieneEscritura => acciones.any((accion) => !accion.omitir);

  PlanAsistente copiar({
    List<AccionPlan>? acciones,
    EstadoPlanAsistente? estado,
    Object? indicePendiente = _ausente,
    Object? pregunta = _ausente,
    List<OpcionPlan>? opciones,
    Object? datoFaltante = _ausente,
  }) {
    return PlanAsistente(
      acciones: acciones ?? this.acciones,
      estado: estado ?? this.estado,
      indicePendiente: identical(indicePendiente, _ausente)
          ? this.indicePendiente
          : indicePendiente as int?,
      pregunta: identical(pregunta, _ausente) ? this.pregunta : pregunta as String?,
      opciones: opciones ?? this.opciones,
      datoFaltante: identical(datoFaltante, _ausente)
          ? this.datoFaltante
          : datoFaltante as DatoFaltante?,
    );
  }
}

sealed class ParseoPlan {}

class ParseoOk extends ParseoPlan {
  ParseoOk(this.acciones, {this.mensaje});

  final List<AccionPlan> acciones;
  final String? mensaje;
}

class ParseoError extends ParseoPlan {
  ParseoError(this.mensaje);

  final String mensaje;
}

/// true si el texto pegado trae un plan y no hace falta llamar a la API.
bool parecePlanJson(String texto) {
  final limpio = texto.trim();
  if (!limpio.startsWith('{')) return false;
  return limpio.contains('"acciones"');
}

ParseoPlan parsearPlanJson(String raw) {
  final mapa = _extraerMapa(raw);
  if (mapa == null) {
    if (_pareceSql(raw)) {
      return ParseoError(
        'Eso parece SQL. La IA no escribe en la base: solo devuelve acciones. No ejecuté nada.',
      );
    }
    return ParseoError(
      'No pude leer el plan. Tiene que ser un JSON con la clave "acciones". No guardé nada.',
    );
  }
  if (mapa.containsKey('sql') || mapa.containsKey('query')) {
    return ParseoError(
      'La IA no escribe SQL. El plan tiene que traer acciones. No ejecuté nada.',
    );
  }
  final mensaje = _texto(mapa['mensaje']);
  final crudas = mapa['acciones'];
  if (crudas == null) {
    return ParseoError(
      'El JSON no trae "acciones". No guardé nada.',
    );
  }
  if (crudas is! List) {
    return ParseoError(
      'La clave "acciones" tiene que ser una lista. No guardé nada.',
    );
  }
  if (crudas.isEmpty) {
    return ParseoOk(
      const [],
      mensaje: _mensajeSinAccion(mensaje),
    );
  }

  final acciones = <AccionPlan>[];
  for (final item in crudas) {
    if (item is! Map) {
      return ParseoError(
        'Hay una acción que no es un objeto. No guardé nada.',
      );
    }
    final datos = Map<String, dynamic>.from(item);
    final tipo = _tipo(datos['tipo']);
    if (tipo == null) {
      return ParseoError(
        'No reconozco la acción "${_texto(datos['tipo'])}". '
        'Solo uso entrada_stock, crear_producto y venta. No guardé nada.',
      );
    }
    final nombre = _texto(
      datos['nombre'] ?? datos['producto'],
    );
    final cantidad = _entero(datos['cantidad']);
    final costoUnitarioExplicito = _importe(
      datos['costo_unitario'] ??
          datos['costoUnitario'] ??
          datos['costo_por_producto'] ??
          datos['precio_compra'] ??
          datos['precioCompra'],
    );
    final costoTotal = _importe(datos['costo_total'] ?? datos['costoTotal']);
    final precioExplicito = datos.containsKey('precio_venta') ||
        datos.containsKey('precioVenta');
    final precioVenta = _importe(datos['precio_venta'] ?? datos['precioVenta']);
    double? costo = costoUnitarioExplicito;
    var desdeTotal = false;
    if (costo == null &&
        costoTotal != null &&
        cantidad != null &&
        cantidad > 0) {
      costo = costoTotal / cantidad;
      desdeTotal = true;
    }
    acciones.add(
      AccionPlan(
        tipo: tipo,
        nombre: nombre,
        cantidad: cantidad,
        costoUnitario: costo,
        costoDesdeTotal: desdeTotal,
        precioVenta: precioVenta,
        precioVentaExplicito: precioExplicito && precioVenta != null,
        categoria: _vacioANull(_texto(datos['categoria'])),
        medio: _medio(datos['medio']),
        cliente: _vacioANull(_texto(datos['cliente'])),
      ),
    );
  }
  return ParseoOk(acciones, mensaje: mensaje.isEmpty ? null : mensaje);
}

String _mensajeSinAccion(String mensaje) {
  final limpio = mensaje.trim().toLowerCase();
  const fijo =
      'Eso no lo tomé como una entrada, un alta ni una venta. '
      'Decime el producto y la cantidad, o pedime el stock.';
  if (limpio.isEmpty || limpio.contains('frase corta')) return fijo;
  return mensaje.trim();
}

String normalizarPlan(String texto) {
  const origen = 'áéíóúüñ';
  const destino = 'aeiouun';
  var salida = texto.toLowerCase().trim();
  for (var i = 0; i < origen.length; i++) {
    salida = salida.replaceAll(origen[i], destino[i]);
  }
  return salida.replaceAll(RegExp(r'\s+'), ' ');
}

double? leerImporte(String raw) {
  var texto = normalizarPlan(raw);
  final millones = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*millones?\b').firstMatch(texto);
  if (millones != null) {
    final base = _numeroPlano(millones.group(1)!);
    if (base == null) return null;
    return base * 1000000;
  }
  final mil = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*mil\b').firstMatch(texto);
  if (mil != null) {
    final base = _numeroPlano(mil.group(1)!);
    if (base == null) return null;
    return base * 1000;
  }
  final numeros = RegExp(r'[0-9]+(?:[.,][0-9]+)?').allMatches(texto);
  if (numeros.isEmpty) return null;
  return _numeroPlano(numeros.last.group(0)!);
}

int? leerCantidadTexto(String raw) {
  final clave = normalizarPlan(raw);
  const palabras = {
    'un': 1,
    'una': 1,
    'uno': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
  };
  if (palabras.containsKey(clave)) return palabras[clave];
  final importe = leerImporte(raw);
  if (importe == null) return null;
  if (importe == importe.roundToDouble() && importe > 0 && importe < 1000000) {
    return importe.toInt();
  }
  return null;
}

String? leerMedioTexto(String raw) {
  final clave = normalizarPlan(raw);
  if (clave.contains('transfer')) return 'transferencia';
  if (RegExp(r'\b(efectivo|cash|contado)\b').hasMatch(clave)) {
    return 'efectivo';
  }
  return null;
}

bool mencionaCostoTotal(String frase) {
  return RegExp(r'costo total').hasMatch(normalizarPlan(frase));
}

bool mencionaCostoPorProducto(String frase) {
  return RegExp(
    r'costo por (producto|unidad)|por unidad|costo unitario|cada uno|c/u',
  ).hasMatch(normalizarPlan(frase));
}

double? importeCostoTotal(String frase) {
  final match = RegExp(
    r'costo total\s*(?:de|a|:)?\s*\$?\s*([0-9][0-9.,]*)',
  ).firstMatch(normalizarPlan(frase));
  if (match == null) return null;
  return _numeroPlano(match.group(1)!);
}

double? importeCostoPorProducto(String frase) {
  final match = RegExp(
    r'(?:costo|precio de compra)\s+por\s+(?:producto|unidad)\s*(?:de|a|:)?\s*\$?\s*([0-9][0-9.,]*)',
  ).firstMatch(normalizarPlan(frase));
  if (match == null) return null;
  return _numeroPlano(match.group(1)!);
}

Map<String, dynamic>? _extraerMapa(String raw) {
  final limpio = raw.trim();
  final directo = _decodificar(limpio);
  if (directo != null) return directo;
  final inicio = limpio.indexOf('{');
  final fin = limpio.lastIndexOf('}');
  if (inicio < 0 || fin <= inicio) return null;
  return _decodificar(limpio.substring(inicio, fin + 1));
}

Map<String, dynamic>? _decodificar(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
  return null;
}

bool _pareceSql(String raw) {
  return RegExp(
    r'\b(select\s+.+\s+from|insert\s+into|update\s+\w+\s+set|delete\s+from|drop\s+table)\b',
    caseSensitive: false,
  ).hasMatch(raw);
}

TipoAccionPlan? _tipo(Object? raw) {
  final clave = normalizarPlan(_texto(raw)).replaceAll(' ', '_');
  switch (clave) {
    case 'entrada_stock':
    case 'entrada':
    case 'agregar_stock':
      return TipoAccionPlan.entradaStock;
    case 'crear_producto':
    case 'crear':
    case 'alta':
      return TipoAccionPlan.crearProducto;
    case 'venta':
    case 'vender':
    case 'vendi':
      return TipoAccionPlan.venta;
    default:
      return null;
  }
}

String? _medio(Object? raw) {
  final texto = _texto(raw);
  if (texto.isEmpty || texto == 'null') return null;
  return leerMedioTexto(texto);
}

String _texto(Object? raw) {
  if (raw == null) return '';
  final texto = raw.toString().trim();
  if (texto == 'null') return '';
  return texto;
}

String? _vacioANull(String texto) => texto.isEmpty ? null : texto;

double? _importe(Object? raw) {
  if (raw == null) return null;
  if (raw is num) {
    final valor = raw.toDouble();
    if (valor.isNaN || valor.isInfinite) return null;
    return valor;
  }
  if (raw is! String || raw.trim().isEmpty) return null;
  return leerImporte(raw);
}

int? _entero(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) {
    if (raw.isNaN || raw.isInfinite) return null;
    if (raw == raw.roundToDouble()) return raw.toInt();
    return null;
  }
  if (raw is! String) return null;
  return leerCantidadTexto(raw);
}

double? _numeroPlano(String raw) => leerMontoEscrito(raw);
