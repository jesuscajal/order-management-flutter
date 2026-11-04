import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../backend/catalogo_remoto.dart';
import '../backend/pedidos_remoto.dart';
import '../backend/stock_remoto.dart';
import '../services/sesion_google.dart';

/// Datos del catálogo y de los pedidos que la base local no tiene columnas
/// para guardar. Vive en este dispositivo, al lado de Drift.
class FichaProducto {
  const FichaProducto({
    this.categoria = '',
    this.categorias = const [],
    this.atributos = const {},
    this.controlaStock = true,
    this.visibleEnTienda = true,
    this.umbral = 2,
    this.unidades = const [],
    this.variantes = const [],
  });

  /// Primera categoría. Los datos viejos solo tenían este campo.
  final String categoria;

  /// Todas las categorías del producto, además de [categoria] si no está en la lista.
  final List<String> categorias;
  final Map<String, String> atributos;
  final bool controlaStock;
  final bool visibleEnTienda;
  final int umbral;
  final List<UnidadSerie> unidades;
  final List<VarianteLocal> variantes;

  int get disponibles =>
      unidades.where((unidad) => unidad.estado == 'disponible').length;

  /// Categorías sin repetir, conservando el orden elegido.
  List<String> get todas {
    final vistas = <String>{};
    final lista = <String>[];
    void sumar(String nombre) {
      final limpio = nombre.trim();
      if (limpio.isEmpty) return;
      if (!vistas.add(limpio.toLowerCase())) return;
      lista.add(limpio);
    }

    for (final nombre in categorias) {
      sumar(nombre);
    }
    sumar(categoria);
    return lista;
  }

  Map<String, dynamic> toJson() => {
        'categoria': todas.isEmpty ? '' : todas.first,
        'categorias': todas,
        'atributos': atributos,
        'controlaStock': controlaStock,
        'visibleEnTienda': visibleEnTienda,
        'umbral': umbral,
        'unidades': [for (final unidad in unidades) unidad.toJson()],
        'variantes': [for (final variante in variantes) variante.toJson()],
      };

  factory FichaProducto.fromJson(Map<String, dynamic> json) {
    final atributos = <String, String>{};
    final crudos = json['atributos'];
    if (crudos is Map) {
      crudos.forEach((clave, valor) {
        atributos[clave.toString()] = valor?.toString() ?? '';
      });
    }
    return FichaProducto(
      categoria: json['categoria'] as String? ?? '',
      categorias: [
        for (final item in (json['categorias'] as List<dynamic>? ?? const []))
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim(),
      ],
      atributos: atributos,
      controlaStock: json['controlaStock'] as bool? ?? true,
      visibleEnTienda: json['visibleEnTienda'] as bool? ?? true,
      umbral: (json['umbral'] as num?)?.toInt() ?? 2,
      unidades: [
        for (final item in (json['unidades'] as List<dynamic>? ?? const []))
          if (item is Map)
            UnidadSerie.fromJson(Map<String, dynamic>.from(item)),
      ],
      variantes: [
        for (final item in (json['variantes'] as List<dynamic>? ?? const []))
          if (item is Map)
            VarianteLocal.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  FichaProducto copiar({
    List<UnidadSerie>? unidades,
    List<VarianteLocal>? variantes,
  }) {
    return FichaProducto(
      categoria: categoria,
      categorias: categorias,
      atributos: atributos,
      controlaStock: controlaStock,
      visibleEnTienda: visibleEnTienda,
      umbral: umbral,
      unidades: unidades ?? this.unidades,
      variantes: variantes ?? this.variantes,
    );
  }
}

class UnidadSerie {
  const UnidadSerie({required this.codigo, this.estado = 'disponible'});

  final String codigo;
  final String estado;

  Map<String, dynamic> toJson() => {'codigo': codigo, 'estado': estado};

  factory UnidadSerie.fromJson(Map<String, dynamic> json) {
    final estado = (json['estado'] as String? ?? 'disponible').trim();
    const validos = ['disponible', 'reservada', 'vendida', 'baja'];
    return UnidadSerie(
      codigo: (json['codigo'] as String? ?? '').trim(),
      estado: validos.contains(estado) ? estado : 'disponible',
    );
  }
}

class VarianteLocal {
  const VarianteLocal({
    required this.etiqueta,
    required this.stock,
    this.precio,
  });

  final String etiqueta;
  final int stock;
  final double? precio;

  Map<String, dynamic> toJson() => {
        'etiqueta': etiqueta,
        'stock': stock,
        'precio': precio,
      };

  factory VarianteLocal.fromJson(Map<String, dynamic> json) {
    final precio = json['precio'];
    return VarianteLocal(
      etiqueta: (json['etiqueta'] as String? ?? '').trim(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      precio: precio is num ? precio.toDouble() : null,
    );
  }
}

/// Relación de una línea con una unidad de serie o una variante.
///
/// Los pedidos viejos no tienen esta lista: [MetaPedido.fromJson] la deja vacía.
class LineaMeta {
  const LineaMeta({
    required this.productoId,
    required this.cantidad,
    required this.precio,
    this.unidad = '',
    this.variante = '',
  });

  final int productoId;
  final int cantidad;
  final double precio;

  /// Código de serie o IMEI. Vacío si la línea no eligió unidad.
  final String unidad;

  /// Etiqueta de la variante. Vacía si el producto no tiene variantes.
  final String variante;

  Map<String, dynamic> toJson() => {
        'productoId': productoId,
        'cantidad': cantidad,
        'precio': precio,
        'unidad': unidad,
        'variante': variante,
      };

  factory LineaMeta.fromJson(Map<String, dynamic> json) {
    final precio = json['precio'];
    return LineaMeta(
      productoId: (json['productoId'] as num?)?.toInt() ?? 0,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
      precio: precio is num ? precio.toDouble() : 0,
      unidad: (json['unidad'] as String? ?? '').trim(),
      variante: (json['variante'] as String? ?? '').trim(),
    );
  }
}

class MetaPedido {
  const MetaPedido({
    this.origen = 'local',
    this.autor = '',
    this.precios = const {},
    this.comprobante = '',
    this.comprobanteEstado = '',
    this.lineas = const [],
    this.stockAplicado = false,
    this.medioPago = '',
    this.fiado = false,
    this.descuentoTipo = '',
    this.descuentoValor = 0,
    this.descuentoMonto = 0,
  });

  static const medios = ['efectivo', 'transferencia', 'otro'];

  final String origen;
  final String autor;
  final Map<int, double> precios;

  /// Imagen en base64, sin encabezado. Vacío si no hay comprobante.
  final String comprobante;

  /// pendiente, aceptado o rechazado. Vacío si no hay imagen.
  final String comprobanteEstado;

  /// Unidades y variantes elegidas al armar el pedido.
  final List<LineaMeta> lineas;

  /// True si confirmar ya pasó la unidad a vendida y descontó la variante.
  final bool stockAplicado;

  /// efectivo, transferencia u otro. Vacío en pedidos viejos.
  final String medioPago;

  /// True si el saldo quedó fiado. La deuda la anota el alta del pedido.
  final bool fiado;

  /// monto o porcentaje. Vacío si no hubo descuento.
  final String descuentoTipo;

  /// Lo que escribió el usuario: pesos o el porcentaje.
  final double descuentoValor;

  /// Pesos restados del total al guardar. No cambia el precio de catálogo.
  final double descuentoMonto;

  double? precioDe(int productoId) => precios[productoId];

  /// Pesos a restar de [bruto]. No supera el bruto. Los pedidos viejos dan 0.
  double descuentoSobre(double bruto) {
    if (bruto.isNaN || bruto.isInfinite || bruto <= 0) return 0;
    var monto = descuentoMonto;
    if (monto <= 0) {
      if (descuentoTipo == 'porcentaje') {
        final pct = descuentoValor <= 0
            ? 0.0
            : (descuentoValor > 100 ? 100.0 : descuentoValor);
        monto = bruto * pct / 100;
      } else if (descuentoTipo == 'monto') {
        monto = descuentoValor;
      }
    }
    if (monto.isNaN || monto.isInfinite || monto <= 0) return 0;
    return monto > bruto ? bruto : monto;
  }

  static String normalizarMedio(String raw) {
    final clave = raw.trim().toLowerCase();
    return medios.contains(clave) ? clave : '';
  }

  static String etiquetaMedio(String medio) {
    switch (normalizarMedio(medio)) {
      case 'efectivo':
        return 'Efectivo';
      case 'transferencia':
        return 'Transferencia';
      case 'otro':
        return 'Otro';
      default:
        return '';
    }
  }

  /// Pone el medio al principio, como espera el cierre de caja.
  /// Sin medio, el texto queda igual.
  static String conMedio(String texto, {required String medio}) {
    final base = texto.trim();
    final etiqueta = etiquetaMedio(medio);
    if (etiqueta.isEmpty) return base;
    return '$etiqueta · $base';
  }

  static String normalizarDescuento(String raw) {
    final clave = raw.trim().toLowerCase();
    if (clave == 'monto' || clave == 'porcentaje') return clave;
    return '';
  }

  MetaPedido copiar({
    String? origen,
    String? autor,
    Map<int, double>? precios,
    String? comprobante,
    String? comprobanteEstado,
    List<LineaMeta>? lineas,
    bool? stockAplicado,
    String? medioPago,
    bool? fiado,
    String? descuentoTipo,
    double? descuentoValor,
    double? descuentoMonto,
  }) {
    return MetaPedido(
      origen: origen ?? this.origen,
      autor: autor ?? this.autor,
      precios: precios ?? this.precios,
      comprobante: comprobante ?? this.comprobante,
      comprobanteEstado: comprobanteEstado ?? this.comprobanteEstado,
      lineas: lineas ?? this.lineas,
      stockAplicado: stockAplicado ?? this.stockAplicado,
      medioPago: medioPago ?? this.medioPago,
      fiado: fiado ?? this.fiado,
      descuentoTipo: descuentoTipo ?? this.descuentoTipo,
      descuentoValor: descuentoValor ?? this.descuentoValor,
      descuentoMonto: descuentoMonto ?? this.descuentoMonto,
    );
  }

  Map<String, dynamic> toJson() => {
        'origen': origen,
        'autor': autor,
        'precios': {
          for (final entrada in precios.entries)
            entrada.key.toString(): entrada.value,
        },
        'comprobante': comprobante,
        'comprobanteEstado': comprobanteEstado,
        'lineas': [for (final linea in lineas) linea.toJson()],
        'stockAplicado': stockAplicado,
        'medioPago': medioPago,
        'fiado': fiado,
        'descuentoTipo': descuentoTipo,
        'descuentoValor': descuentoValor,
        'descuentoMonto': descuentoMonto,
      };

  factory MetaPedido.fromJson(Map<String, dynamic> json) {
    final precios = <int, double>{};
    final crudos = json['precios'];
    if (crudos is Map) {
      crudos.forEach((clave, valor) {
        final id = int.tryParse(clave.toString());
        if (id == null || valor is! num) return;
        precios[id] = valor.toDouble();
      });
    }
    final medio = json['medioPago'];
    final tipoDescuento = json['descuentoTipo'];
    return MetaPedido(
      origen: json['origen'] as String? ?? 'local',
      autor: json['autor'] as String? ?? '',
      precios: precios,
      comprobante: json['comprobante'] as String? ?? '',
      comprobanteEstado: json['comprobanteEstado'] as String? ?? '',
      lineas: [
        for (final item in (json['lineas'] as List<dynamic>? ?? const []))
          if (item is Map)
            LineaMeta.fromJson(Map<String, dynamic>.from(item)),
      ].where((linea) => linea.productoId > 0 && linea.cantidad > 0).toList(),
      stockAplicado: json['stockAplicado'] == true,
      medioPago: MetaPedido.normalizarMedio(medio is String ? medio : ''),
      fiado: json['fiado'] == true,
      descuentoTipo: MetaPedido.normalizarDescuento(
        tipoDescuento is String ? tipoDescuento : '',
      ),
      descuentoValor: _numeroNoNegativo(json['descuentoValor']),
      descuentoMonto: _numeroNoNegativo(json['descuentoMonto']),
    );
  }
}

double _numeroNoNegativo(Object? valor) {
  if (valor is! num) return 0;
  final numero = valor.toDouble();
  if (numero.isNaN || numero.isInfinite || numero < 0) return 0;
  return numero;
}

/// Cambio de fichas listo para guardar después de que el pedido ya cambió
/// de estado en la base. Si la transacción falla, no se confirma.
class MutacionAmpliacion {
  const MutacionAmpliacion({
    required this.base,
    required this.fichas,
    required this.pedidos,
    required this.detalle,
  });

  final DocumentoAmpliacion base;
  final Map<int, FichaProducto> fichas;
  final Map<int, MetaPedido> pedidos;
  final String detalle;
}

class NotaAuditoria {
  const NotaAuditoria({
    required this.cuando,
    required this.actor,
    required this.accion,
    required this.entidad,
    required this.detalle,
  });

  final DateTime cuando;
  final String actor;
  final String accion;
  final String entidad;
  final String detalle;

  Map<String, dynamic> toJson() => {
        'cuando': cuando.toIso8601String(),
        'actor': actor,
        'accion': accion,
        'entidad': entidad,
        'detalle': detalle,
      };

  factory NotaAuditoria.fromJson(Map<String, dynamic> json) {
    return NotaAuditoria(
      cuando: DateTime.tryParse(json['cuando'] as String? ?? '') ??
          DateTime.now(),
      actor: json['actor'] as String? ?? '',
      accion: json['accion'] as String? ?? '',
      entidad: json['entidad'] as String? ?? '',
      detalle: json['detalle'] as String? ?? '',
    );
  }
}

class DocumentoAmpliacion {
  const DocumentoAmpliacion({
    this.fichas = const {},
    this.pedidos = const {},
    this.auditoria = const [],
  });

  final Map<int, FichaProducto> fichas;
  final Map<int, MetaPedido> pedidos;
  final List<NotaAuditoria> auditoria;
}

/// Tope para que la foto del comprobante entre en las preferencias.
const int topeComprobante = 140000;

class AmpliacionLocal {
  const AmpliacionLocal();

  static const _clave = 'gexi_ampliacion_v1';

  Future<DocumentoAmpliacion> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return const DocumentoAmpliacion();
    try {
      final decoded = jsonDecode(crudo);
      if (decoded is! Map) return const DocumentoAmpliacion();
      final json = Map<String, dynamic>.from(decoded);
      final fichas = <int, FichaProducto>{};
      final productos = json['fichas'];
      if (productos is Map) {
        productos.forEach((clave, valor) {
          final id = int.tryParse(clave.toString());
          if (id == null || valor is! Map) return;
          fichas[id] = FichaProducto.fromJson(Map<String, dynamic>.from(valor));
        });
      }
      final pedidos = <int, MetaPedido>{};
      final metas = json['pedidos'];
      if (metas is Map) {
        metas.forEach((clave, valor) {
          final id = int.tryParse(clave.toString());
          if (id == null || valor is! Map) return;
          pedidos[id] = MetaPedido.fromJson(Map<String, dynamic>.from(valor));
        });
      }
      return DocumentoAmpliacion(
        fichas: fichas,
        pedidos: pedidos,
        auditoria: [
          for (final item in (json['auditoria'] as List<dynamic>? ?? const []))
            if (item is Map)
              NotaAuditoria.fromJson(Map<String, dynamic>.from(item)),
        ],
      );
    } catch (_) {
      return const DocumentoAmpliacion();
    }
  }

  Future<void> guardarFicha(int productoId, FichaProducto ficha) async {
    final actual = await cargar();
    final fichas = Map<int, FichaProducto>.of(actual.fichas);
    fichas[productoId] = ficha;
    await _escribir(actual, fichas: fichas);
    await anotar(
      accion: 'editar',
      entidad: 'producto',
      detalle: 'Ficha del producto $productoId',
    );
    _empujarFicha(productoId, ficha);
  }

  Future<void> marcarPedido({
    required int pedidoId,
    required String origen,
    Map<int, double> precios = const {},
    List<LineaMeta> lineas = const [],
    String? medioPago,
    bool? fiado,
    String? descuentoTipo,
    double? descuentoValor,
    double? descuentoMonto,
  }) async {
    final actual = await cargar();
    final previa = actual.pedidos[pedidoId];
    final sesion = await AuthGoogle.instancia.leer();
    final pedidos = Map<int, MetaPedido>.of(actual.pedidos);
    pedidos[pedidoId] = (previa ?? const MetaPedido()).copiar(
      origen: origen,
      autor: sesion?.email ?? previa?.autor ?? '',
      precios: precios.isEmpty ? previa?.precios : precios,
      lineas: lineas.isEmpty ? previa?.lineas : lineas,
      medioPago: medioPago == null ? null : MetaPedido.normalizarMedio(medioPago),
      fiado: fiado,
      descuentoTipo: descuentoTipo == null
          ? null
          : MetaPedido.normalizarDescuento(descuentoTipo),
      descuentoValor: descuentoValor,
      descuentoMonto: descuentoMonto,
    );
    await _escribir(actual, pedidos: pedidos);
    await anotar(
      accion: 'alta',
      entidad: 'pedido',
      detalle: 'Pedido #$pedidoId · $origen',
    );
    final guardada = pedidos[pedidoId];
    if (guardada == null) return;
    ReplicaScope.diferir(
      () => PedidosRemoto.completarMeta(
        pedidoLocalId: pedidoId,
        origen: guardada.origen,
        medioPago: guardada.medioPago,
        fiado: guardada.fiado,
      ),
    );
  }

  Future<MetaPedido> guardarComprobante({
    required int pedidoId,
    required String base64,
    required String estado,
  }) async {
    if (base64.length > topeComprobante) {
      throw StateError('La imagen es muy pesada. Probá con una foto más chica.');
    }
    final actual = await cargar();
    final previa = actual.pedidos[pedidoId] ?? const MetaPedido();
    final meta = previa.copiar(
      comprobante: base64,
      comprobanteEstado: estado,
    );
    final pedidos = Map<int, MetaPedido>.of(actual.pedidos);
    pedidos[pedidoId] = meta;
    await _escribir(actual, pedidos: pedidos);
    await anotar(
      accion: estado == 'rechazado' ? 'rechazar' : 'editar',
      entidad: 'comprobante',
      detalle: 'Comprobante del pedido #$pedidoId · $estado',
    );
    return meta;
  }

  /// Unidades de serie ya elegidas en pedidos que no están cancelados.
  ///
  /// La ficha sigue en `disponible` hasta confirmar. Esta lista evita vender
  /// la misma unidad en dos pedidos abiertos.
  Map<int, Set<String>> unidadesEnPedidos(
    DocumentoAmpliacion doc,
    Iterable<int> pedidosAbiertos,
  ) {
    final abiertos = pedidosAbiertos.toSet();
    final mapa = <int, Set<String>>{};
    for (final id in abiertos) {
      final meta = doc.pedidos[id];
      if (meta == null) continue;
      for (final linea in meta.lineas) {
        final codigo = linea.unidad.trim();
        if (codigo.isEmpty) continue;
        mapa.putIfAbsent(linea.productoId, () => <String>{}).add(codigo.toLowerCase());
      }
    }
    return mapa;
  }

  /// Arma el cambio de fichas sin guardarlo. Lanza si la unidad no está
  /// disponible o si la variante no alcanza.
  Future<MutacionAmpliacion?> prepararDescuento(int pedidoId) {
    return _prepararMovimiento(pedidoId, descontar: true);
  }

  /// Devuelve la unidad a disponible y repone el stock de la variante.
  /// No hace nada si confirmar todavía no había descontado.
  Future<MutacionAmpliacion?> prepararDevolucion(int pedidoId) {
    return _prepararMovimiento(pedidoId, descontar: false);
  }

  Future<void> confirmarMutacion(MutacionAmpliacion mutacion) async {
    await _escribir(
      mutacion.base,
      fichas: mutacion.fichas,
      pedidos: mutacion.pedidos,
    );
    await anotar(
      accion: 'editar',
      entidad: 'producto',
      detalle: mutacion.detalle,
    );
    final fichas = mutacion.fichas;
    for (final entrada in fichas.entries) {
      _empujarFicha(entrada.key, entrada.value);
    }
  }

  Future<MutacionAmpliacion?> _prepararMovimiento(
    int pedidoId, {
    required bool descontar,
  }) async {
    final actual = await cargar();
    final meta = actual.pedidos[pedidoId];
    if (meta == null || meta.lineas.isEmpty) return null;
    if (descontar && meta.stockAplicado) return null;
    if (!descontar && !meta.stockAplicado) return null;

    final fichas = Map<int, FichaProducto>.of(actual.fichas);
    _moverLineas(fichas, meta.lineas, descontar: descontar);
    final pedidos = Map<int, MetaPedido>.of(actual.pedidos);
    pedidos[pedidoId] = meta.copiar(stockAplicado: descontar);
    return MutacionAmpliacion(
      base: actual,
      fichas: fichas,
      pedidos: pedidos,
      detalle: descontar
          ? 'Pedido #$pedidoId: la unidad pasó a vendida y se descontó la variante.'
          : 'Pedido #$pedidoId: la unidad volvió a disponible y se repuso la variante.',
    );
  }

  void _moverLineas(
    Map<int, FichaProducto> fichas,
    List<LineaMeta> lineas, {
    required bool descontar,
  }) {
    final porProducto = <int, List<LineaMeta>>{};
    for (final linea in lineas) {
      porProducto.putIfAbsent(linea.productoId, () => []).add(linea);
    }
    final unidadesVistas = <String>{};

    for (final entrada in porProducto.entries) {
      final ficha = fichas[entrada.key];
      // El servicio no mueve serie ni variante: no exige unidades.
      if (ficha != null && !ficha.controlaStock) continue;
      final pideDetalle = entrada.value.any(
        (linea) => linea.unidad.isNotEmpty || linea.variante.isNotEmpty,
      );
      if (ficha == null) {
        if (descontar && pideDetalle) {
          throw StateError(
            'No encontré la ficha para actualizar la unidad o la variante.',
          );
        }
        continue;
      }

      final unidades = [...ficha.unidades];
      final variantes = [...ficha.variantes];
      for (final linea in entrada.value) {
        if (linea.unidad.isNotEmpty) {
          final clave = '${entrada.key}|${linea.unidad.toLowerCase()}';
          if (descontar && !unidadesVistas.add(clave)) {
            throw StateError(
              'La unidad ${linea.unidad} está repetida en el pedido.',
            );
          }
          final index = unidades.indexWhere(
            (unidad) => unidad.codigo.toLowerCase() == linea.unidad.toLowerCase(),
          );
          if (descontar) {
            if (linea.cantidad != 1) {
              throw StateError(
                'La unidad ${linea.unidad} se vende de a una.',
              );
            }
            if (index < 0 || unidades[index].estado != 'disponible') {
              throw StateError(
                'La unidad ${linea.unidad} ya no está disponible.',
              );
            }
            unidades[index] = UnidadSerie(
              codigo: unidades[index].codigo,
              estado: 'vendida',
            );
          } else if (index >= 0) {
            unidades[index] = UnidadSerie(
              codigo: unidades[index].codigo,
              estado: 'disponible',
            );
          }
        }
        if (linea.variante.isNotEmpty) {
          final index = variantes.indexWhere(
            (variante) =>
                variante.etiqueta.toLowerCase() == linea.variante.toLowerCase(),
          );
          if (descontar) {
            if (index < 0) {
              throw StateError(
                'La variante ${linea.variante} ya no está en la ficha.',
              );
            }
            if (variantes[index].stock < linea.cantidad) {
              throw StateError(
                'No hay stock suficiente de ${linea.variante}. '
                'Hay ${variantes[index].stock} y el pedido pide ${linea.cantidad}.',
              );
            }
            variantes[index] = VarianteLocal(
              etiqueta: variantes[index].etiqueta,
              stock: variantes[index].stock - linea.cantidad,
              precio: variantes[index].precio,
            );
          } else if (index >= 0) {
            variantes[index] = VarianteLocal(
              etiqueta: variantes[index].etiqueta,
              stock: variantes[index].stock + linea.cantidad,
              precio: variantes[index].precio,
            );
          }
        }
      }
      fichas[entrada.key] = ficha.copiar(
        unidades: unidades,
        variantes: variantes,
      );
    }
  }

  Future<void> anotar({
    required String accion,
    required String entidad,
    required String detalle,
  }) async {
    final actual = await cargar();
    final sesion = await AuthGoogle.instancia.leer();
    final notas = [
      NotaAuditoria(
        cuando: DateTime.now(),
        actor: sesion?.email ?? '',
        accion: accion,
        entidad: entidad,
        detalle: detalle,
      ),
      ...actual.auditoria,
    ];
    await _escribir(
      actual,
      auditoria: notas.length > 80 ? notas.sublist(0, 80) : notas,
    );
  }

  void _empujarFicha(int productoId, FichaProducto ficha) {
    ReplicaScope.diferir(
      () => CatalogoRemoto.publicarFicha(
        productoLocalId: productoId,
        categoria: ficha.todas.isEmpty ? '' : ficha.todas.first,
        categorias: ficha.todas,
        visibleEnTienda: ficha.visibleEnTienda,
        umbral: ficha.umbral,
        controlaSerie: ficha.unidades.isNotEmpty,
        variantes: [
          for (final variante in ficha.variantes)
            if (variante.etiqueta.trim().isNotEmpty)
              VarianteParaNube(
                etiqueta: variante.etiqueta,
                precio: variante.precio,
              ),
        ],
        unidades: [
          for (final unidad in ficha.unidades)
            if (unidad.codigo.trim().isNotEmpty)
              UnidadParaNube(codigo: unidad.codigo, estado: unidad.estado),
        ],
        atributos: ficha.atributos,
      ),
    );
  }

  Future<void> _escribir(
    DocumentoAmpliacion actual, {
    Map<int, FichaProducto>? fichas,
    Map<int, MetaPedido>? pedidos,
    List<NotaAuditoria>? auditoria,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fichasFinal = fichas ?? actual.fichas;
    final pedidosFinal = pedidos ?? actual.pedidos;
    final auditoriaFinal = auditoria ?? actual.auditoria;
    await prefs.setString(
      _clave,
      jsonEncode({
        'fichas': {
          for (final entrada in fichasFinal.entries)
            entrada.key.toString(): entrada.value.toJson(),
        },
        'pedidos': {
          for (final entrada in pedidosFinal.entries)
            entrada.key.toString(): entrada.value.toJson(),
        },
        'auditoria': [for (final nota in auditoriaFinal) nota.toJson()],
      }),
    );
  }
}
