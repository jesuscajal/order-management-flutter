import 'dart:convert';

import '../data/app_database.dart';
import '../data/capital_repository.dart';
import '../data/funciones_asistente.dart';
import '../data/instructivo_funciones.dart';
import 'instructivo_remoto.dart';
import '../data/pedido_repository.dart';
import '../data/stock_repository.dart';
import '../models/pedido_estado.dart';
import 'asistente/metricas_asistente.dart';
import 'asistente_enrutador.dart';
import 'negocio_contexto.dart';
import 'negocio_local.dart';
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

    final funciones = await NegocioStore().leerFuncionesAsistente();
    final guias = await const InstructivoRemoto().leer();
    final ayuda = textoInstructivo(
      normalizado,
      consultarStock: funciones.consultarStock,
      anotarVenta: funciones.anotarVenta,
      horarioDireccion: funciones.horarioDireccion,
      ventasHoy: funciones.ventasHoy,
      guias: guias,
    );
    if (ayuda.isNotEmpty) return RespuestaAsistente(ayuda);

    if (_esInformeConsumo(normalizado)) {
      return RespuestaAsistente(await _informeConsumo());
    }
    final periodo = _periodoVentas(normalizado);
    if (periodo != null) {
      if (periodo == PeriodoVentas.hoy && !funciones.ventasHoy) {
        return const RespuestaAsistente(mensajeVentasHoyApagado);
      }
      return RespuestaAsistente(await _informeVentas(database, periodo));
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
    if (_esInformeStock(normalizado) ||
        clasificarIntencion(texto) == IntencionAsistente.stock) {
      if (!funciones.consultarStock) {
        return const RespuestaAsistente(mensajeConsultarStockApagado);
      }
      if (_esInformeStock(normalizado)) {
        return RespuestaAsistente(
          await _informeStock(database, texto, normalizado),
        );
      }
      return RespuestaAsistente(
        await _enrutador.consultarStock(database: database, texto: texto),
      );
    }
    if (parecePreguntaHorarioDireccion(texto)) {
      if (!funciones.horarioDireccion) {
        return const RespuestaAsistente(mensajeHorarioApagado);
      }
      final negocio = await NegocioStore().leer();
      return RespuestaAsistente(
        textoHorarioDireccion(
          horario: negocio?.horario ?? '',
          direccion: negocio?.mapsUrl ?? '',
        ),
      );
    }
    if (!funciones.anotarVenta && ventaSola(texto)) {
      return const RespuestaAsistente(mensajeAnotarVentaApagado);
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

    if (mencionaFoto(texto) &&
        clasificarIntencion(texto) == IntencionAsistente.fuera &&
        esperando == null) {
      return RespuestaAsistente(respuestaFueraDeAlcance(texto));
    }
    if (esperando != null || _pareceDelDominio(normalizado)) {
      return const RequiereModelo();
    }
    return RespuestaAsistente(alcanceConFunciones(funciones));
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
      systemPrompt: PromptsAsistente.systemPrompt,
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

  Future<String> _informeVentas(AppDatabase database, PeriodoVentas periodo) async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final desde = switch (periodo) {
      PeriodoVentas.hoy => hoy,
      PeriodoVentas.ayer => hoy.subtract(const Duration(days: 1)),
      PeriodoVentas.semana => hoy.subtract(Duration(days: hoy.weekday - 1)),
      PeriodoVentas.mes => DateTime(hoy.year, hoy.month),
    };
    final hasta = periodo == PeriodoVentas.ayer ? hoy : null;
    final titulo = switch (periodo) {
      PeriodoVentas.hoy => 'hoy',
      PeriodoVentas.ayer => 'ayer',
      PeriodoVentas.semana => 'esta semana',
      PeriodoVentas.mes => 'este mes',
    };
    final pedidos = (await PedidoRepository(database).listarPedidos()).where(
      (pedido) {
        final estado = PedidoEstados.leer(pedido.estado);
        if (estado == PedidoEstado.cancelado ||
            estado == PedidoEstado.pendiente) {
          return false;
        }
        if (pedido.fecha.isBefore(desde)) return false;
        if (hasta != null && !pedido.fecha.isBefore(hasta)) return false;
        return true;
      },
    ).toList();
    if (pedidos.isEmpty) return 'No registré ventas $titulo.';
    var total = 0.0;
    final unidades = <String, int>{};
    for (final pedido in pedidos) {
      total += pedido.montoTotal;
      for (final item in pedido.items) {
        unidades[item.nombre] = (unidades[item.nombre] ?? 0) + item.cantidad;
      }
    }
    final masVendidos = unidades.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final buffer = StringBuffer(
      'Vendiste ${_moneda(total)} $titulo, en ${pedidos.length} '
      '${pedidos.length == 1 ? 'venta' : 'ventas'}.',
    );
    if (masVendidos.isNotEmpty) {
      buffer.write(
        ' Lo que más salió: ${masVendidos.take(3).map((e) => '${e.key} (${e.value})').join(', ')}.',
      );
    }
    buffer.write(' El total usa el precio de venta actual de cada producto.');
    return buffer.toString();
  }

  Future<String> _informeConsumo() async {
    final resumen = await const MetricasAsistente().resumir();
    if (resumen.turnos == 0) {
      return 'Todavía no consulté al modelo desde este teléfono.';
    }
    final segundos = (resumen.msPromedio / 1000).toStringAsFixed(1);
    return 'Consulté al modelo ${resumen.turnos} '
        '${resumen.turnos == 1 ? 'vez' : 'veces'}: '
        '${resumen.entrada} tokens de entrada (${resumen.enCache} en caché) y '
        '${resumen.salida} de salida. Demora promedio $segundos s. '
        '${resumen.utiles} de ${resumen.turnos} terminaron en un plan.';
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
    r'\b(cuanto|cuanta|cuantos|cuantas|mostrar|mostrame|informa|informame|informar|informe|decime|pasame|listar|lista|ver|queda|quedan|hay|bajo|bajos|cero|agotado|agotados|sin stock)\b',
  ).hasMatch(texto);
  return (stock && cantidad || stockBajo) && _tipoMovimiento(texto) == null;
}

enum PeriodoVentas { hoy, ayer, semana, mes }

/// Lo que el asistente ofrece, según los interruptores de la página.
String alcanceConFunciones(FuncionesAsistente funciones) {
  final informes = <String>[
    if (funciones.ventasHoy) 'ventas de hoy',
    if (funciones.consultarStock) 'stock',
    if (funciones.horarioDireccion) 'el horario y la dirección',
    'deudas',
    'pedidos',
    'capital',
  ];
  final escritura = funciones.anotarVenta
      ? 'También armo entradas de stock y ventas: te muestro el plan y recién guardo cuando confirmás.'
      : 'También armo entradas de stock: te muestro el plan y recién guardo cuando confirmás.';
  return 'Puedo informar ${informes.join(', ')}. $escritura';
}

/// "¿Cuánto vendí hoy?" se responde con la base, sin gastar el cupo.
PeriodoVentas? periodoVentasDe(String texto) =>
    _periodoVentas(normalizarTexto(texto));

/// Una venta para anotar, sin una entrada de stock en la misma frase.
bool ventaSola(String texto) {
  if (clasificarIntencion(texto) != IntencionAsistente.venta) return false;
  final plano = normalizarTexto(texto);
  return !RegExp(r'\b(agrega\w*|suma\w*|entra\w*|carga\w*)\b').hasMatch(plano);
}

PeriodoVentas? _periodoVentas(String texto) {
  final ventas = RegExp(
    r'\b(cuanto vendi|que vendi|vendi algo|ventas|vendimos|facture|facturamos|como me fue|como vengo de ventas)\b',
  ).hasMatch(texto);
  if (!ventas) return null;
  if (RegExp(r'\b(vendi|vende)\s+\d').hasMatch(texto)) return null;
  if (RegExp(r'\bayer\b').hasMatch(texto)) return PeriodoVentas.ayer;
  if (RegExp(r'\b(semana|semanal)\b').hasMatch(texto)) {
    return PeriodoVentas.semana;
  }
  if (RegExp(r'\b(mes|mensual)\b').hasMatch(texto)) return PeriodoVentas.mes;
  if (RegExp(r'\b(hoy|el dia)\b').hasMatch(texto)) return PeriodoVentas.hoy;
  if (RegExp(r'\b(cuanto vendi|como me fue|ventas)\b').hasMatch(texto)) {
    return PeriodoVentas.hoy;
  }
  return null;
}

bool _esInformeConsumo(String texto) => RegExp(
      r'\b(tokens|consumo del asistente|cuanto gaste de ia|consumo de ia|cuanto gasta el asistente)\b',
    ).hasMatch(texto);

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

/// "Crealos" o "esos que te pedí" no traen el producto. Se lee junto con la
/// frase anterior.
String fraseConAntecedente(String frase, String? anterior) {
  final previo = anterior?.trim() ?? '';
  if (previo.isEmpty) return frase;
  final texto = normalizarTexto(frase);
  final refiere = RegExp(
    r'\b(esos|esas|eso|esa|este|esta|estos|estas|crealo|crealos|crealas|creame|aquel|aquellos|que te pedi|lo que te dije|el que te dije)\b',
  ).hasMatch(texto);
  if (!refiere || normalizarTexto(previo) == texto) return frase;
  return '$previo. $frase';
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
