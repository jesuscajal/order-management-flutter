import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/data/vidriera_local.dart';
import 'package:gestion_pedidos/services/asistente/foto_catalogo_asistente.dart';
import 'package:gestion_pedidos/services/asistente/plan_asistente.dart';
import 'package:gestion_pedidos/services/asistente_enrutador.dart';
import 'package:gestion_pedidos/services/openai_chat_service.dart';
import 'package:gestion_pedidos/services/orquestador_ia.dart';
import 'package:gestion_pedidos/services/asistente/resumen_asistente.dart';
import 'package:gestion_pedidos/data/funciones_asistente.dart';
import 'package:gestion_pedidos/data/instructivo_funciones.dart';
import 'package:gestion_pedidos/services/prompts_asistente.dart';

void main() {
  group('plan que devuelve el modelo', () {
    test('costo total y cantidad dan el costo por unidad', () {
      final parseo = parsearPlanJson(
        '{"acciones":[{"tipo":"entrada_stock","nombre":"iPhone 11",'
        '"cantidad":5,"costo_unitario":null,"costo_total":500000,'
        '"precio_venta":null}],"mensaje":null}',
      );
      expect(parseo, isA<ParseoOk>());
      final accion = (parseo as ParseoOk).acciones.single;
      expect(accion.tipo, TipoAccionPlan.entradaStock);
      expect(accion.costoUnitario, 100000);
      expect(accion.costoDesdeTotal, isTrue);
      expect(accion.precioVentaExplicito, isFalse);
    });

    test('el costo por unidad gana sobre el total', () {
      final parseo = parsearPlanJson(
        '{"acciones":[{"tipo":"entrada_stock","nombre":"Funda",'
        '"cantidad":4,"costo_unitario":3000,"costo_total":10000}]}',
      ) as ParseoOk;
      expect(parseo.acciones.single.costoUnitario, 3000);
      expect(parseo.acciones.single.costoDesdeTotal, isFalse);
    });

    test('una frase con venta y entrada trae las dos acciones en orden', () {
      final parseo = parsearPlanJson(
        '{"acciones":['
        '{"tipo":"venta","nombre":"fundas A15","cantidad":2,"medio":"transferencia"},'
        '{"tipo":"entrada_stock","nombre":"cargadores","cantidad":3,"costo_unitario":4000}'
        ']}',
      ) as ParseoOk;
      expect(parseo.acciones.map((a) => a.tipo), [
        TipoAccionPlan.venta,
        TipoAccionPlan.entradaStock,
      ]);
      expect(parseo.acciones.first.medio, 'transferencia');
    });

    test('un medio que no es efectivo ni transferencia queda sin elegir', () {
      final parseo = parsearPlanJson(
        '{"acciones":[{"tipo":"venta","nombre":"A15","cantidad":1,"medio":"tarjeta"}]}',
      ) as ParseoOk;
      expect(parseo.acciones.single.medio, isNull);
    });

    test('rechaza SQL', () {
      expect(parsearPlanJson('DELETE FROM productos'), isA<ParseoError>());
      expect(
        parsearPlanJson('{"sql":"update productos set precio = 0"}'),
        isA<ParseoError>(),
      );
    });

    test('rechaza acciones que no existen', () {
      expect(
        parsearPlanJson(
            '{"acciones":[{"tipo":"borrar_producto","nombre":"A15"}]}'),
        isA<ParseoError>(),
      );
    });

    test('no muestra el texto de ejemplo del prompt', () {
      final parseo = parsearPlanJson(
        '{"acciones":[],"mensaje":"una frase corta en voseo"}',
      ) as ParseoOk;
      expect(parseo.mensaje, isNot(contains('frase corta')));
      expect(parseo.acciones, isEmpty);
    });
  });

  group('lo que se resuelve sin gastar el cupo', () {
    test('ventas por período', () {
      expect(periodoVentasDe('¿Cuánto vendí hoy?'), PeriodoVentas.hoy);
      expect(periodoVentasDe('cuanto vendi ayer'), PeriodoVentas.ayer);
      expect(periodoVentasDe('ventas de la semana'), PeriodoVentas.semana);
      expect(periodoVentasDe('como me fue este mes'), PeriodoVentas.mes);
    });

    test('una venta para registrar no es un informe', () {
      expect(periodoVentasDe('vendí 2 iphone en efectivo'), isNull);
      expect(periodoVentasDe('agregar auriculares'), isNull);
      expect(ventaSola('vendí 2 iphone en efectivo'), isTrue);
      expect(ventaSola('vendí dos fundas y sumame 3 cargadores'), isFalse);
    });

    test('el horario y la dirección no inventan lo que falta', () {
      expect(parecePreguntaHorarioDireccion('¿Cuál es el horario?'), isTrue);
      expect(parecePreguntaHorarioDireccion('¿Dónde queda el local?'), isTrue);
      expect(parecePreguntaHorarioDireccion('vendí un A15'), isFalse);
      expect(
        textoHorarioDireccion(horario: '', direccion: ''),
        'Todavía no cargaste el horario ni la dirección del local.',
      );
      expect(
        textoHorarioDireccion(
          horario: 'Lunes a viernes de 9 a 18',
          direccion: 'San Martín 120, Rosario',
        ),
        contains('San Martín 120, Rosario'),
      );
    });

    test('apagada, la venta no se ofrece en el alcance', () {
      const apagada = FuncionesAsistente(anotarVenta: false, ventasHoy: false);
      final texto = alcanceConFunciones(apagada);
      expect(texto, isNot(contains('ventas:')));
      expect(texto, isNot(contains('ventas de hoy')));
      expect(texto, contains('entradas de stock'));
    });

    test('cómo usar el stock se responde con el instructivo', () {
      final texto = textoInstructivo(
        'como agrego stock',
        consultarStock: true,
        anotarVenta: true,
        horarioDireccion: true,
        ventasHoy: true,
      );
      expect(texto, contains('Añadir stock'));
      expect(texto, isNot(contains('apagada')));
    });

    test('si el asistente está apagado, el instructivo lo avisa', () {
      final texto = textoInstructivo(
        'como uso el asistente',
        consultarStock: true,
        anotarVenta: false,
        horarioDireccion: true,
        ventasHoy: true,
      );
      expect(texto, contains('apagada'));
    });

    test('sin interruptores guardados, las funciones quedan prendidas', () {
      expect(const FuncionesAsistente(), FuncionesAsistente.desde(null));
      expect(
        FuncionesAsistente.desde({
          'funcionesAsistente': {'anotarVenta': false},
        }).anotarVenta,
        isFalse,
      );
      expect(
        FuncionesAsistente.desde({
          'funcionesAsistente': {'anotarVenta': false},
        }).consultarStock,
        isTrue,
      );
    });

    test('crealos se lee junto con lo que ya pidió', () {
      expect(
        fraseConAntecedente(
          'Crea esos que te pedi',
          'Necesito agregar al stock 10 fundas de iphone 11',
        ),
        'Necesito agregar al stock 10 fundas de iphone 11. Crea esos que te pedi',
      );
      expect(
        fraseConAntecedente('agregar 10 fundas', 'otra cosa'),
        'agregar 10 fundas',
      );
    });
  });

  group('frases cortas', () {
    test('confirmar y cancelar', () {
      expect(esAfirmacion('dale'), isTrue);
      expect(esAfirmacion('sí'), isTrue);
      expect(esCancelacion('cancelar'), isTrue);
      expect(esCancelacion('vendí dos fundas'), isFalse);
    });

    test('vender y dar de alta se separan', () {
      expect(
        clasificarIntencion('vendí un A15 a Juan'),
        IntencionAsistente.venta,
      );
      expect(
        clasificarIntencion('chiste del día'),
        IntencionAsistente.fuera,
      );
    });
  });

  group('prompt', () {
    test('el prefijo fijo no lleva fecha ni datos del negocio', () {
      const prompt = PromptsAsistente.systemPrompt;
      expect(prompt, isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
      expect(prompt, isNot(contains('Novaceltec')));
      expect(prompt, isNot(contains('una frase corta en voseo')));
      expect(PromptsAsistente.versionPrompt, isNotEmpty);
    });
  });

  test('el resumen del chat cabe en 500 caracteres', () {
    final resumen = actualizarResumenAsistente(
      anterior: '',
      frase: 'vendí un iPhone 11',
      productos: [for (var i = 0; i < 40; i++) 'Producto con nombre largo $i'],
    );
    expect(resumen.length, lessThanOrEqualTo(500));
    expect(resumen, contains('Última intención: venta'));
    expect(resumen, contains('Producto con nombre largo'));
    final siguiente = actualizarResumenAsistente(
      anterior: 'Última intención: venta. Productos: iPhone 11.',
      frase: 'entraron 3 fundas',
      productos: const ['Funda A15'],
    );
    expect(siguiente, contains('entrada de stock'));
    expect(siguiente, contains('Funda A15'));
    expect(siguiente, contains('iPhone 11'));
    final largo = actualizarResumenAsistente(
      anterior: '',
      frase: 'vendí uno',
      productos: ['a' * 600],
    );
    expect(largo.length, 500);
  });

  test('lee el consumo de tokens de la respuesta', () {
    final uso = UsoOpenAi.desde(
      {
        'prompt_tokens': 1200,
        'completion_tokens': 80,
        'prompt_tokens_details': {'cached_tokens': 1024},
      },
      milisegundos: 900,
    );
    expect(uso?.entrada, 1200);
    expect(uso?.salida, 80);
    expect(uso?.enCache, 1024);
    expect(UsoOpenAi.desde(null, milisegundos: 0), isNull);
  });

  test('el fallo de la foto de catálogo se lee en español', () {
    final clave = motivoFalloFotoOpenAi(
      status: 401,
      codigo: 'invalid_api_key',
    );
    expect(clave.mensaje, contains('no es válida'));
    expect(clave.probarOtroModelo, isFalse);

    final saldo = motivoFalloFotoOpenAi(
      status: 429,
      codigo: 'insufficient_quota',
      detalle:
          'You exceeded your current quota, please check your plan and billing details.',
    );
    expect(saldo.mensaje, contains('saldo'));
    expect(saldo.probarOtroModelo, isFalse);

    final limite = motivoFalloFotoOpenAi(
      status: 429,
      codigo: 'rate_limit_exceeded',
    );
    expect(limite.mensaje, contains('limitó'));
    expect(limite.probarOtroModelo, isFalse);

    final modelo = motivoFalloFotoOpenAi(
      status: 400,
      codigo: 'model_not_found',
      detalle:
          'The model `gpt-image-1` does not exist or you do not have access to it.',
    );
    expect(modelo.mensaje, contains('no está disponible'));
    expect(modelo.probarOtroModelo, isTrue);

    final apagado = motivoFalloFotoOpenAi(
      status: 400,
      detalle: 'The model gpt-image-1 was shut down.',
    );
    expect(apagado.probarOtroModelo, isTrue);

    final pesada = motivoFalloFotoOpenAi(
      status: 413,
      detalle: 'The image is too large',
    );
    expect(pesada.mensaje, mensajeFotoPesada);
    expect(pesada.probarOtroModelo, isFalse);

    final otroParametro = motivoFalloFotoOpenAi(
      status: 400,
      parametro: 'size',
      detalle: 'Invalid size',
    );
    expect(otroParametro.probarOtroModelo, isFalse);
  });
}
