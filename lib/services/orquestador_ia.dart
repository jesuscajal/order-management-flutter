import 'dart:convert';

import '../data/app_database.dart';
import '../data/capital_repository.dart';
import '../data/pedido_repository.dart';
import '../data/stock_repository.dart';
import '../models/pedido_estado.dart';
import 'asistente_enrutador.dart';
import 'negocio_contexto.dart';
import 'openai_chat_service.dart';
import 'prompts_asistente.dart';

sealed class DecisionAsistente {
  const DecisionAsistente();
}

class RespuestaAsistente extends DecisionAsistente {
  const RespuestaAsistente(this.mensaje);

  final String mensaje;
}

class InterpretacionAsistente extends DecisionAsistente {
  const InterpretacionAsistente(this.interpretacion);

  final Interpretacion interpretacion;
}

class RequiereModelo extends DecisionAsistente {
  const RequiereModelo();
}

/// Orquesta el asistente en cuatro niveles:
/// normalización, reglas locales, clasificación JSON y ejecución.
class OrquestadorIa {
  OrquestadorIa({
    OpenAiChatService? chat,
    AsistenteEnrutador? enrutador,
  })  : _chat = chat ?? OpenAiChatService(),
        _enrutador = enrutador ?? AsistenteEnrutador();

  final OpenAiChatService _chat;
  final AsistenteEnrutador _enrutador;

  Future<DecisionAsistente> evaluarLocal({
    required AppDatabase database,
    required String texto,
    IntencionAsistente? esperando,
  }) async {
    final normalizado = normalizarTexto(texto);
    if (normalizado.isEmpty) {
      return const RespuestaAsistente('Escribime qué necesitás.');
    }

    if (_esInformeDeudas(normalizado)) {
      return RespuestaAsistente(await _informeDeudas(database));
    }
    if (_esInformePedidos(normalizado)) {
      return RespuestaAsistente(await _informePedidos(database));
    }
    if (_esInformeCapital(normalizado)) {
      return RespuestaAsistente(await _informeCapital(database));
    }
    if (_esInformeStock(normalizado)) {
      return RespuestaAsistente(
        await _informeStock(database, texto, normalizado),
      );
    }

    final producto = _productoLocal(normalizado);
    if (producto != null) {
      final interpretacion = await _enrutador.interpretarDatos(
        database: database,
        accion: 'crear_producto',
        datos: producto,
      );
      return InterpretacionAsistente(interpretacion);
    }

    final ajuste = await _ajusteLocal(database, normalizado);
    if (ajuste != null) return InterpretacionAsistente(ajuste);

    if (mencionaFoto(texto)) {
      return const RespuestaAsistente(
        '$alcanceAsistente La carga por foto queda fuera de este prototipo.',
      );
    }
    if (esperando != null || _pareceDelDominio(normalizado)) {
      return const RequiereModelo();
    }
    return const RespuestaAsistente(alcanceAsistente);
  }

  /// Nivel 3: una sola llamada al modelo y respuesta JSON obligatoria.
  Future<DecisionAsistente> consultarModelo({
    required AppDatabase database,
    required String apiKey,
    required List<MensajeChat> historial,
  }) async {
    final contexto = await NegocioContexto(database).resumir();
    final raw = await _chat.responderJson(
      apiKey: apiKey,
      systemPrompt: '${PromptsAsistente.systemPrompt}\n'
          'Para este prototipo, si no se indica propietario usá Yo por defecto.',
      contextoNegocio: contexto,
      historial: historial,
    );
    final datos = _extraerJson(raw);
    if (datos == null) {
      return const RespuestaAsistente(
        'No pude interpretar los datos. Reformulá el pedido en una frase.',
      );
    }
    final accion =
        normalizarTexto(datos['accion']?.toString() ?? '').replaceAll(' ', '_');
    final camposRaw = datos['campos'];
    final datosRaw = datos['datos'];
    var campos = camposRaw is Map
        ? <String, dynamic>{
            ...datos,
            ...Map<String, dynamic>.from(camposRaw),
          }
        : datosRaw is Map
            ? <String, dynamic>{
                ...datos,
                ...Map<String, dynamic>.from(datosRaw),
              }
            : datos;
    final preguntaModelo = datos['pregunta']?.toString().trim();
    final faltan = datos['faltan'];
    final soloFaltaPropietario = faltan is List &&
        faltan.isNotEmpty &&
        faltan.every(
          (item) => normalizarTexto(item.toString()) == 'propietario',
        );
    if (preguntaModelo != null &&
        preguntaModelo.isNotEmpty &&
        !soloFaltaPropietario) {
      final intencion = switch (accion) {
        'crear_producto' => IntencionAsistente.producto,
        'ajustar_stock' => IntencionAsistente.ajusteStock,
        'registrar_venta' => IntencionAsistente.venta,
        _ => IntencionAsistente.fuera,
      };
      if (intencion != IntencionAsistente.fuera) {
        return InterpretacionAsistente(
          InterpretacionPregunta(
            intencion: intencion,
            pregunta: preguntaModelo,
          ),
        );
      }
      return RespuestaAsistente(preguntaModelo);
    }
    final ultimoTexto = historial.isEmpty ? '' : historial.last.content;
    switch (accion) {
      case 'consultar_informe':
        final informe = campos['informe']?.toString();
        switch (informe) {
          case 'stock_bajo':
            return RespuestaAsistente(
              await _informeStock(
                database,
                ultimoTexto,
                '${normalizarTexto(ultimoTexto)} stock bajo',
              ),
            );
          case 'stock_producto':
            return RespuestaAsistente(
              await _informeStock(
                database,
                ultimoTexto,
                normalizarTexto(ultimoTexto),
              ),
            );
          case 'deuda_por_persona':
            return RespuestaAsistente(await _informeDeudas(database));
          case 'pedidos_abiertos':
            return RespuestaAsistente(await _informePedidos(database));
          case 'resumen_capital':
            return RespuestaAsistente(await _informeCapital(database));
          default:
            return const RespuestaAsistente(alcanceAsistente);
        }
      case 'informe_stock':
        return RespuestaAsistente(
          await _informeStock(
            database,
            ultimoTexto,
            normalizarTexto(ultimoTexto),
          ),
        );
      case 'informe_deudas':
        return RespuestaAsistente(await _informeDeudas(database));
      case 'informe_pedidos':
        return RespuestaAsistente(await _informePedidos(database));
      case 'informe_capital':
        return RespuestaAsistente(await _informeCapital(database));
      case 'crear_producto':
        final stockInicial = campos['stockInicial'];
        if (stockInicial is Map) {
          campos = {
            ...campos,
            'cantidadInicial': stockInicial['cantidad'],
            'propietario': stockInicial['propietario'],
          };
        }
        return InterpretacionAsistente(
          await _enrutador.interpretarDatos(
            database: database,
            accion: accion,
            datos: campos,
          ),
        );
      case 'ajustar_stock':
        final movimientos = campos['movimientos'];
        if (movimientos is List && movimientos.isNotEmpty) {
          final primero = movimientos.first;
          if (primero is Map) {
            campos = {
              ...campos,
              ...Map<String, dynamic>.from(primero),
            };
          }
        }
        return InterpretacionAsistente(
          await _enrutador.interpretarDatos(
            database: database,
            accion: accion,
            datos: campos,
          ),
        );
      case 'registrar_venta':
        return InterpretacionAsistente(
          await _enrutador.interpretarDatos(
            database: database,
            accion: accion,
            datos: campos,
          ),
        );
      case 'pedir_dato':
        final pregunta = campos['pregunta']?.toString().trim();
        return RespuestaAsistente(
          pregunta == null || pregunta.isEmpty
              ? '¿Qué dato falta para completar la operación?'
              : pregunta,
        );
      case 'fuera_de_alcance':
      default:
        return const RespuestaAsistente(alcanceAsistente);
    }
  }

  Future<ResultadoAccion> confirmar({
    required AppDatabase database,
    required BorradorConfirmable borrador,
  }) {
    return _enrutador.confirmar(database: database, borrador: borrador);
  }

  Future<String> _informeStock(
    AppDatabase database,
    String texto,
    String normalizado,
  ) async {
    final todos = await NegocioContexto(database).listarProductosConStock();
    Iterable<ProductoConStock> productos = todos;
    String titulo = 'Stock actual';
    if (RegExp(r'\b(cero|sin stock|agotad[oa]s?)\b').hasMatch(normalizado)) {
      productos = productos.where((producto) => producto.stockTotal == 0);
      titulo = 'Productos sin stock';
    } else if (RegExp(r'\b(bajo|bajos|baja|poco|pocos)\b')
        .hasMatch(normalizado)) {
      productos = productos.where(
        (producto) => producto.stockTotal <= PromptsAsistente.umbralStockBajo,
      );
      titulo =
          'Stock bajo o en cero (${PromptsAsistente.umbralStockBajo} unidades o menos)';
    } else {
      final apuntados = todos
          .where(
            (producto) =>
                normalizado.contains(normalizarTexto(producto.nombre)),
          )
          .toList();
      if (apuntados.isNotEmpty) productos = apuntados;
    }
    final lista = productos.toList();
    if (lista.isEmpty) {
      return todos.isEmpty
          ? 'No hay productos cargados en el stock.'
          : 'No encontré productos para ese filtro.';
    }
    final buffer = StringBuffer('$titulo:');
    for (final producto in lista.take(40)) {
      buffer
        ..writeln()
        ..write(
          '• ${producto.nombre}: ${producto.stockTotal} unidades '
          '(Yo ${producto.stockYo}, Nildo ${producto.stockNildo}). '
          'Compra ${_moneda(producto.precioCompra)}; '
          'venta ${_moneda(producto.precioVenta)}.',
        );
      if (producto.stockOtros > 0) {
        buffer.write(' Otros ${producto.stockOtros}.');
      }
    }
    if (lista.length > 40) {
      buffer
        ..writeln()
        ..write('Mostré 40 de ${lista.length}.');
    }
    return buffer.toString();
  }

  Future<String> _informeDeudas(AppDatabase database) async {
    final repo = CapitalRepository(database);
    final movimientos = await repo.listar();
    final resumen = CapitalRepository.resumir([
      for (final movimiento in movimientos)
        MovimientoParaResumen(
          persona: movimiento.persona,
          monto: movimiento.monto,
          tipo: movimiento.tipo,
        ),
    ]).where((fila) => fila.saldoDeuda > 0).toList();
    if (resumen.isEmpty) return 'No hay saldos pendientes a cobrar.';
    final buffer = StringBuffer('Saldos a cobrar por persona:');
    for (final fila in resumen) {
      buffer
        ..writeln()
        ..write('• ${fila.persona}: ${_moneda(fila.saldoDeuda)}.');
    }
    return buffer.toString();
  }

  Future<String> _informePedidos(AppDatabase database) async {
    final pedidos =
        (await PedidoRepository(database).listarPedidos()).where((pedido) {
      final estado = PedidoEstados.leer(pedido.estado);
      return estado != PedidoEstado.entregado &&
          estado != PedidoEstado.cancelado;
    }).toList();
    if (pedidos.isEmpty) return 'No hay pedidos sin terminar.';
    final buffer = StringBuffer('Pedidos no terminados:');
    for (final pedido in pedidos.take(30)) {
      final productos = pedido.items
          .map((item) => '${item.nombre} x${item.cantidad}')
          .join(', ');
      buffer
        ..writeln()
        ..write(
          '• #${pedido.id} · ${pedido.clienteNombre} · '
          '${PedidoEstados.etiqueta(pedido.estado)} · '
          '${_moneda(pedido.montoTotal)}'
          '${productos.isEmpty ? '' : ' · $productos'}.',
        );
    }
    if (pedidos.length > 30) {
      buffer
        ..writeln()
        ..write('Mostré 30 de ${pedidos.length}.');
    }
    return buffer.toString();
  }

  Future<String> _informeCapital(AppDatabase database) async {
    final repo = CapitalRepository(database);
    final movimientos = await repo.listar();
    var entradas = 0.0;
    var salidas = 0.0;
    final resumen = CapitalRepository.resumir([
      for (final movimiento in movimientos)
        MovimientoParaResumen(
          persona: movimiento.persona,
          monto: movimiento.monto,
          tipo: movimiento.tipo,
        ),
    ]);
    for (final movimiento in movimientos) {
      switch (TiposCapital.normalizar(movimiento.tipo)) {
        case TiposCapital.entrada:
          entradas += movimiento.monto.abs();
        case TiposCapital.salida:
          salidas += movimiento.monto.abs();
      }
    }
    final aCobrar = resumen.fold<double>(
      0,
      (total, fila) => total + fila.saldoDeuda,
    );
    return 'Resumen de capital:\n'
        '• Entradas: ${_moneda(entradas)}.\n'
        '• Salidas: ${_moneda(salidas)}.\n'
        '• Saldo neto: ${_moneda(entradas - salidas)}.\n'
        '• Saldo a cobrar: ${_moneda(aCobrar)}.';
  }

  Future<Interpretacion?> _ajusteLocal(
    AppDatabase database,
    String normalizado,
  ) async {
    final tipo = _tipoMovimiento(normalizado);
    if (tipo == null) return null;
    final mencionaStock = RegExp(
      r'\b(stock|inventario|unidad|unidades|entrada|salida)\b',
    ).hasMatch(normalizado);
    final pareceAltaProducto =
        RegExp(r'\b(producto|articulo|mercaderia)\b').hasMatch(normalizado);
    if (!mencionaStock && pareceAltaProducto) return null;
    final cantidadMatch = RegExp(r'\b(\d+)\b').firstMatch(normalizado);
    final cantidad =
        cantidadMatch == null ? null : int.tryParse(cantidadMatch.group(1)!);
    final productos = await PedidoRepository(database).listarProductos();
    final candidatos = productos
        .where(
          (producto) => normalizado.contains(normalizarTexto(producto.nombre)),
        )
        .toList()
      ..sort((a, b) => b.nombre.length.compareTo(a.nombre.length));
    final nombre = candidatos.isEmpty
        ? _nombreDesdeAjuste(normalizado)
        : candidatos.first.nombre;
    return _enrutador.interpretarDatos(
      database: database,
      accion: 'ajustar_stock',
      datos: {
        'producto': nombre,
        'cantidad': cantidad,
        'tipo': tipo,
        'propietario':
            RegExp(r'\bnildo\b').hasMatch(normalizado) ? 'Nildo' : 'Yo',
      },
    );
  }

  Map<String, dynamic>? _productoLocal(String normalizado) {
    if (!RegExp(
      r'\b(crear|crea|creame|agregar|agrega|alta|cargar|carga|registrar)\b',
    ).hasMatch(normalizado)) {
      return null;
    }
    final compra = RegExp(
      r'(?:precio(?:\s+de)?\s+)?(?:compra|costo)\s*(?:a|de|:|=)?\s*\$?\s*([0-9]+(?:[.,][0-9]+)?)',
    ).firstMatch(normalizado);
    final venta = RegExp(
      r'(?:precio(?:\s+de)?\s+)?venta\s*(?:a|de|:|=)?\s*\$?\s*([0-9]+(?:[.,][0-9]+)?)',
    ).firstMatch(normalizado);
    if (compra == null || venta == null) return null;
    final nombreMatch = RegExp(
      r'(?:(?:producto|articulo|mercaderia)(?:\s+nuevo)?\s*:?\s*|(?:crear|crea|creame|agregar|agrega|cargar|carga|registrar)\s+(?:(?:un|una)\s+)?(?:(?:producto|articulo|mercaderia)(?:\s+nuevo)?\s*:?\s*)?(?:(?:el|la)\s+)?)(.+?)(?=\s*[,;]?\s+(?:con\s+)?(?:precio(?:\s+de)?\s+)?(?:compra|costo|venta)\b|$)',
    ).firstMatch(normalizado);
    final nombre = (nombreMatch?.group(1)?.trim() ?? '')
        .replaceAll(RegExp(r'[,;:]+$'), '')
        .trim();
    if (nombre.isEmpty) return null;
    final cantidad = RegExp(
      r'\b(?:con\s+)?(\d+)\s+(?:unidades?|de\s+stock|mios?|mias?|de\s+nildo|para\s+nildo)\b',
    ).firstMatch(normalizado);
    return {
      'nombre': nombre,
      'precioCompra': compra.group(1),
      'precioVenta': venta.group(1),
      'cantidadInicial': cantidad?.group(1),
      'propietario':
          RegExp(r'\bnildo\b').hasMatch(normalizado) ? 'Nildo' : 'Yo',
    };
  }
}

String normalizarTexto(String texto) {
  const origen = 'áéíóúüñ';
  const destino = 'aeiouun';
  var salida = texto.toLowerCase().trim();
  for (var i = 0; i < origen.length; i++) {
    salida = salida.replaceAll(origen[i], destino[i]);
  }
  return salida.replaceAll(RegExp(r'\s+'), ' ');
}

bool _esInformeStock(String texto) {
  final stock = RegExp(r'\b(stock|inventario|existencias)\b').hasMatch(texto);
  final stockBajo = RegExp(
    r'\b(que me queda poco|que queda poco|productos? bajos?|productos? agotados?|sin stock)\b',
  ).hasMatch(texto);
  final cantidad = RegExp(
    r'\b(cuanto|cuanta|cuantos|cuantas|mostrar|mostrame|informe|listar|lista|ver|queda|quedan|hay|bajo|bajos|cero|agotado|agotados|sin stock)\b',
  ).hasMatch(texto);
  return (stock && cantidad || stockBajo) && _tipoMovimiento(texto) == null;
}

bool _esInformeDeudas(String texto) => RegExp(
      r'\b(deuda|deudas|deudor|deudores|deben|debe|a cobrar|saldo a cobrar)\b',
    ).hasMatch(texto);

bool _esInformePedidos(String texto) {
  final pedido = RegExp(r'\b(pedido|pedidos)\b').hasMatch(texto);
  final informe = RegExp(
    r'\b(pendiente|pendientes|no terminados|sin terminar|sin entregar|abiertos|en curso|informe|mostrar|mostrame|listar|lista|ver)\b',
  ).hasMatch(texto);
  return pedido && informe;
}

bool _esInformeCapital(String texto) {
  final capital = RegExp(r'\b(capital|finanzas|financiero)\b').hasMatch(texto);
  final informe = RegExp(
    r'\b(resumen|informe|estado|mostrar|mostrame|cuanto|saldo|entradas|salidas|como vengo)\b',
  ).hasMatch(texto);
  return capital && informe;
}

bool _pareceDelDominio(String texto) => RegExp(
      r'\b(stock|inventario|producto|articulo|mercaderia|venta|vender|vendi|pedido|cliente|precio|compra|costo|deuda|capital|entrada|salida|unidades|entra\w*|suma\w*|agrega\w*|desconta\w*|saca\w*)\b',
    ).hasMatch(texto);

String? _tipoMovimiento(String texto) {
  if (RegExp(r'\b(entrada|entra\w*|suma\w*|agrega\w*|ingresa\w*)\b')
      .hasMatch(texto)) {
    return StockRepository.tipoEntrada;
  }
  if (RegExp(
    r'\b(salida|desconta\w*|resta\w*|saca\w*|retira\w*)\b',
  ).hasMatch(texto)) {
    return StockRepository.tipoSalida;
  }
  return null;
}

String _nombreDesdeAjuste(String texto) {
  var limpio = texto
      .replaceAll(
        RegExp(
          r'\b(entrada|salida|entra\w*|suma\w*|agrega\w*|ingresa\w*|desconta\w*|resta\w*|saca\w*|retira\w*|stock|inventario|unidad|unidades|yo|mi|mis|mio|mios|mia|mias|nildo|de|del|al|a|para|en|por|favor)\b',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\b\d+\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (limpio.startsWith('el ')) limpio = limpio.substring(3);
  if (limpio.startsWith('la ')) limpio = limpio.substring(3);
  return limpio;
}

Map<String, dynamic>? _extraerJson(String raw) {
  try {
    final directo = jsonDecode(raw);
    if (directo is Map) return Map<String, dynamic>.from(directo);
  } catch (_) {
    final inicio = raw.indexOf('{');
    final fin = raw.lastIndexOf('}');
    if (inicio >= 0 && fin > inicio) {
      try {
        final extraido = jsonDecode(raw.substring(inicio, fin + 1));
        if (extraido is Map) return Map<String, dynamic>.from(extraido);
      } catch (_) {}
    }
  }
  return null;
}

String _moneda(double valor) =>
    '\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
