import 'dart:convert';

import '../../data/app_database.dart';
import '../../data/funciones_asistente.dart';
import '../../data/vidriera_local.dart';
import '../negocio_local.dart';
import '../openai_chat_service.dart';
import '../prompts_asistente.dart';
import 'catalogo_asistente.dart';
import 'memoria_asistente.dart';
import 'metricas_asistente.dart';
import 'plan_asistente.dart';
import 'proveedor_ia_asistente.dart';
import 'resumen_asistente.dart';
import 'venta_asistente.dart';

/// Orquestador del asistente de operaciones.
///
/// El modelo no escribe SQL ni toca la base. Devuelve JSON y este orquestador
/// llama solo a estas herramientas: buscarProducto, crearProducto, agregarStock,
/// prepararVenta y confirmarVenta. Nada se escribe hasta [confirmar].
///
/// Esquema mínimo que tiene que devolver la IA (o que se puede pegar en el chat):
///
/// ```json
/// {
///   "acciones": [
///     {
///       "tipo": "entrada_stock",
///       "nombre": "iPhone 11",
///       "cantidad": 5,
///       "costo_unitario": 100,
///       "costo_total": null,
///       "precio_venta": 150
///     },
///     {
///       "tipo": "crear_producto",
///       "nombre": "Funda",
///       "categoria": "Accesorios",
///       "precio_compra": 100,
///       "precio_venta": 150,
///       "cantidad": 0
///     },
///     {
///       "tipo": "venta",
///       "nombre": "iPhone 11",
///       "cantidad": 2,
///       "medio": "efectivo",
///       "precio_venta": null,
///       "cliente": null
///     }
///   ]
/// }
/// ```
///
/// Si la frase trae costo total y cantidad, el unitario es total / cantidad.
/// Si también trae costo por producto, ese valor es el unitario.
/// El precio de venta, si no se dijo, es el que ya tiene el producto.
/// Al crear uno nuevo se pregunta. Si buscarProducto no da un único id, no se
/// carga stock: se pregunta solo esa parte y el resto queda pendiente.
class OrquestadorAsistente {
  OrquestadorAsistente({
    required this.database,
    CatalogoAsistente? catalogo,
    VentaAsistente? ventas,
    ProveedorIaAsistente? proveedor,
  })  : catalogo = catalogo ?? CatalogoAsistente(database),
        ventas = ventas ?? VentaAsistente(database),
        proveedor = proveedor ?? ProveedorOpenAiAsistente();

  final AppDatabase database;
  final CatalogoAsistente catalogo;
  final VentaAsistente ventas;
  final ProveedorIaAsistente proveedor;

  /// Alta que ya trae nombre y precios. Busca el producto y, si va a la página
  /// sin foto, el plan pide una antes de guardar.
  Future<ResultadoInterpretacion> desdeAltaLocal({
    required String nombre,
    required double precioCompra,
    required double precioVenta,
    int? cantidad,
  }) {
    return _resolver([
      AccionPlan(
        tipo: TipoAccionPlan.crearProducto,
        nombre: nombre,
        cantidad: cantidad,
        costoUnitario: precioCompra,
        precioVenta: precioVenta,
        precioVentaExplicito: true,
      ),
    ]);
  }

  /// Manda la frase al proveedor, arma el plan y no escribe.
  Future<ResultadoInterpretacion> interpretar(
    String frase, {
    List<MensajeChat> historial = const [],
  }) async {
    final ficha = await _fichaNegocio();
    final resumen = await const MemoriaAsistente().leerResumen();
    final respuesta = await proveedor.interpretar(
      frase: frase,
      contexto: armarFichaConResumen(ficha, resumen),
      historial: historial,
    );
    if (respuesta.faltaClave) {
      return const ResultadoInterpretacion(
        mensaje: mensajeFaltaApi,
        error: true,
      );
    }
    final error = respuesta.error;
    if (error != null && error.isNotEmpty) {
      if (respuesta.medible) {
        await _medir(respuesta, acciones: 0, error: true);
      }
      return ResultadoInterpretacion(mensaje: error, error: true);
    }
    final json = respuesta.json;
    if (json == null || json.trim().isEmpty) {
      await _medir(respuesta, acciones: 0, error: true);
      return const ResultadoInterpretacion(
        mensaje: 'La API no devolvió un plan. No guardé nada.',
        error: true,
      );
    }
    final parseo = parsearPlanJson(json);
    await _medir(
      respuesta,
      acciones: parseo is ParseoOk ? parseo.acciones.length : 0,
      error: parseo is ParseoError,
    );
    return _desdeJson(json, frase: frase);
  }

  /// Aplica un plan ya armado (pegado en el chat o devuelto por otro adaptador).
  Future<ResultadoInterpretacion> aplicarJson(String raw) {
    return _desdeJson(raw);
  }

  /// La persona tocó un producto, una categoría o un medio.
  Future<ResultadoInterpretacion> elegir(PlanAsistente plan, String opcionId) async {
    final indice = plan.indicePendiente;
    if (indice == null || indice < 0 || indice >= plan.acciones.length) {
      return _mostrar(plan);
    }
    OpcionPlan? opcion;
    for (final item in plan.opciones) {
      if (item.id == opcionId) {
        opcion = item;
        break;
      }
    }
    if (opcion == null) {
      return _mostrar(plan);
    }
    final acciones = [...plan.acciones];
    acciones[indice] = _aplicarOpcion(acciones[indice], plan.datoFaltante, opcion);
    return _resolver(acciones);
  }

  /// La persona escribió el dato que faltaba. No se vuelve a llamar a la IA.
  Future<ResultadoInterpretacion> completar(
    PlanAsistente plan,
    String texto,
  ) async {
    final indice = plan.indicePendiente;
    final dato = plan.datoFaltante;
    if (indice == null || dato == null) {
      return _resolver(plan.acciones);
    }
    final acciones = [...plan.acciones];
    final actual = acciones[indice];
    final aplicada = await _aplicarTexto(actual, dato, texto, plan.opciones);
    if (aplicada == null) {
      final pregunta = plan.pregunta ?? 'Me falta un dato.';
      return ResultadoInterpretacion(
        mensaje: 'No entendí ese dato. $pregunta',
        plan: plan,
      );
    }
    acciones[indice] = aplicada;
    return _resolver(acciones);
  }

  /// Crea productos, suma stock y confirma ventas, en ese orden.
  ///
  /// Cada venta se confirma en la transacción de [VentaAsistente.confirmarVenta].
  /// Si una venta falla, esa venta no queda a medias. Las entradas de stock que
  /// ya se habían guardado quedan dichas en el mensaje.
  Future<ResultadoEjecucion> confirmar(
    PlanAsistente plan, {
    Map<int, String> fotosBase64 = const {},
  }) async {
    if (!plan.listo) {
      return const ResultadoEjecucion(
        guardo: false,
        parcial: false,
        mensaje: 'El plan todavía está incompleto. No guardé nada.',
      );
    }
    final funciones = await _leerFunciones();
    final ocultoVenta = !funciones.anotarVenta &&
        plan.acciones.any(
          (accion) => accion.tipo == TipoAccionPlan.venta && !accion.omitir,
        );
    final acciones = [
      for (final accion in plan.acciones)
        if (funciones.anotarVenta || accion.tipo != TipoAccionPlan.venta)
          accion,
    ];
    if (!acciones.any((accion) => !accion.omitir)) {
      return ResultadoEjecucion(
        guardo: false,
        parcial: false,
        mensaje: ocultoVenta
            ? mensajeAnotarVentaApagado
            : 'No había nada nuevo para guardar.',
      );
    }

    final hechos = <String>[];
    var escribio = false;
    try {
      final idsPorClave = <String, int>{};
      for (final accion in acciones) {
        final id = accion.productoId;
        if (id == null) continue;
        idsPorClave[_clave(accion.nombreConfirmado ?? accion.nombre)] = id;
      }

      for (var i = 0; i < acciones.length; i++) {
        final accion = acciones[i];
        if (accion.omitir || accion.productoId != null) continue;
        if (!accion.crear && accion.tipo != TipoAccionPlan.crearProducto) {
          continue;
        }
        final clave = _clave(accion.nombreConfirmado ?? accion.nombre);
        final ya = idsPorClave[clave];
        if (ya != null) {
          acciones[i] = accion.copiar(productoId: ya, crear: false);
          continue;
        }
        final id = await catalogo.crearProducto(
          nombre: accion.nombreConfirmado ?? accion.nombre,
          categoria: accion.categoria!,
          precioCompra: accion.costoUnitario!,
          precioVenta: accion.precioVenta!,
        );
        escribio = true;
        idsPorClave[clave] = id;
        acciones[i] = accion.copiar(productoId: id);
        hechos.add('Creé "${accion.nombreConfirmado ?? accion.nombre}" (id $id).');
      }

      for (var i = 0; i < acciones.length; i++) {
        final accion = acciones[i];
        if (accion.productoId != null) continue;
        final id = idsPorClave[_clave(accion.nombreConfirmado ?? accion.nombre)];
        if (id == null) {
          throw StateError(
            'Falta el id de "${accion.nombre}". No seguí con esa parte.',
          );
        }
        acciones[i] = accion.copiar(productoId: id);
      }

      await _guardarFotos(acciones, fotosBase64, hechos);

      for (final accion in acciones) {
        if (!_sumaStock(accion, acciones)) continue;
        final id = accion.productoId;
        if (id == null) {
          throw StateError(
            'Falta el id de "${accion.nombre}" para cargar el stock.',
          );
        }
        await catalogo.agregarStock(
          productoId: id,
          cantidad: accion.cantidad!,
          costoUnitario: accion.costoUnitario!,
          precioVenta: accion.precioVentaExplicito ? accion.precioVenta : null,
        );
        escribio = true;
        hechos.add(
          'Sumé ${accion.cantidad} ${_unidades(accion.cantidad!)} de '
          '"${accion.nombreConfirmado ?? accion.nombre}".',
        );
      }

      final grupos = _agruparVentas(acciones);
      for (final grupo in grupos) {
        final borrador = await ventas.prepararVenta(
          lineas: [
            for (final accion in grupo)
              (
                productoId: accion.productoId!,
                cantidad: accion.cantidad!,
                precioVenta:
                    accion.precioVentaExplicito ? accion.precioVenta : null,
              ),
          ],
          medio: grupo.first.medio == 'transferencia'
              ? MedioVentaSimple.transferencia
              : MedioVentaSimple.efectivo,
          clienteNombre: _cliente(grupo.first),
        );
        final id = await ventas.confirmarVenta(borrador);
        escribio = true;
        hechos.add('Registré la venta #$id.\n${borrador.resumen()}');
      }

      final texto = hechos.join('\n');
      return ResultadoEjecucion(
        guardo: true,
        parcial: false,
        mensaje: ocultoVenta ? '$texto\n\n$mensajeAnotarVentaApagado' : texto,
      );
    } on StateError catch (error) {
      return ResultadoEjecucion(
        guardo: false,
        parcial: escribio,
        mensaje: _mensajeFallo(hechos, error.message.toString()),
      );
    } catch (error) {
      return ResultadoEjecucion(
        guardo: false,
        parcial: escribio,
        mensaje: _mensajeFallo(hechos, '$error'),
      );
    }
  }

  Future<ResultadoInterpretacion> _desdeJson(String raw, {String? frase}) async {
    final parseo = parsearPlanJson(raw);
    if (parseo is ParseoError) {
      return ResultadoInterpretacion(mensaje: parseo.mensaje, error: true);
    }
    final ok = parseo as ParseoOk;
    final funciones = await _leerFunciones();
    if (ok.acciones.isEmpty) {
      final recuperada = frase == null ? null : _recuperarFraseCorta(frase);
      if (recuperada != null) {
        if (recuperada.tipo == TipoAccionPlan.venta &&
            !funciones.anotarVenta) {
          return const ResultadoInterpretacion(
            mensaje: mensajeAnotarVentaApagado,
          );
        }
        return _resolver([recuperada]);
      }
      return ResultadoInterpretacion(mensaje: ok.mensaje ?? 'No guardé nada.');
    }
    final leidas = frase == null
        ? ok.acciones
        : _corregirCostos(ok.acciones, frase);
    final ocultoVenta = !funciones.anotarVenta &&
        leidas.any(
          (accion) => accion.tipo == TipoAccionPlan.venta && !accion.omitir,
        );
    final acciones = [
      for (final accion in leidas)
        if (funciones.anotarVenta || accion.tipo != TipoAccionPlan.venta)
          accion,
    ];
    if (acciones.isEmpty) {
      return const ResultadoInterpretacion(mensaje: mensajeAnotarVentaApagado);
    }
    final resultado = await _resolver(acciones);
    if (!ocultoVenta) return resultado;
    return ResultadoInterpretacion(
      mensaje: '${resultado.mensaje}\n\n$mensajeAnotarVentaApagado',
      plan: resultado.plan,
      error: resultado.error,
    );
  }

  Future<ResultadoInterpretacion> _resolver(List<AccionPlan> entrada) async {
    final acciones = [...entrada];
    for (var i = 0; i < acciones.length; i++) {
      final paso = await _identificar(acciones, i);
      acciones[i] = paso.accion;
      if (paso.opciones.isNotEmpty) {
        return ResultadoInterpretacion(
          mensaje: paso.pregunta!,
          plan: PlanAsistente(
            acciones: acciones,
            estado: EstadoPlanAsistente.ambiguo,
            indicePendiente: i,
            pregunta: paso.pregunta,
            opciones: paso.opciones,
            datoFaltante: DatoFaltante.producto,
          ),
        );
      }
    }
    _propagar(acciones);
    for (var i = 0; i < acciones.length; i++) {
      final falta = acciones[i].omitir ? null : _primerFalta(acciones[i]);
      if (falta == null) continue;
      final plan = await _planConFalta(acciones, i, falta);
      return ResultadoInterpretacion(mensaje: plan.pregunta ?? '', plan: plan);
    }
    await _marcarFotos(acciones);
    final plan = PlanAsistente(
      acciones: acciones,
      estado: EstadoPlanAsistente.listo,
    );
    if (!plan.tieneEscritura) {
      return ResultadoInterpretacion(mensaje: _resumen(plan));
    }
    return ResultadoInterpretacion(mensaje: _resumen(plan), plan: plan);
  }

  Future<_Identificacion> _identificar(List<AccionPlan> acciones, int indice) async {
    var accion = acciones[indice];
    if (accion.omitir || accion.productoId != null || accion.origenCreacion != null) {
      return _Identificacion(accion);
    }
    final ancla = _ancla(acciones, indice);
    if (ancla != null) {
      final base = acciones[ancla];
      if (base.productoId != null) {
        return _Identificacion(
          accion.copiar(
            productoId: base.productoId,
            nombreConfirmado: base.nombreConfirmado ?? base.nombre,
            crear: false,
            buscado: true,
            costoHistorico: base.costoHistorico,
            stockConocido: base.stockConocido,
            precioVenta: accion.precioVentaExplicito
                ? accion.precioVenta
                : base.precioVenta,
            categoria: accion.categoria ?? base.categoria,
          ),
        );
      }
      if (base.buscado && (base.crear || base.tipo == TipoAccionPlan.crearProducto)) {
        return _Identificacion(
          accion.copiar(
            origenCreacion: ancla,
            crear: false,
            buscado: true,
            nombreConfirmado: base.nombreConfirmado ?? accion.nombreConfirmado,
          ),
        );
      }
    }
    if (accion.buscado && accion.crear) return _Identificacion(accion);
    if (accion.nombre.trim().isEmpty) return _Identificacion(accion);

    final busqueda = await catalogo.buscarProducto(accion.nombre);
    final unico = busqueda.unico;
    if (busqueda.vacio) {
      return _Identificacion(
        accion.copiar(crear: true, buscado: true),
      );
    }
    if (unico != null) {
      return _Identificacion(_conProducto(accion, unico));
    }
    final opciones = _opcionesProducto(busqueda);
    return _Identificacion(
      accion.copiar(buscado: true),
      opciones: opciones,
      pregunta: _preguntaProducto(accion, acciones.length),
    );
  }

  AccionPlan _conProducto(AccionPlan accion, CoincidenciaProducto producto) {
    final conId = accion.copiar(
      productoId: producto.id,
      nombreConfirmado: producto.nombre,
      crear: false,
      buscado: true,
      origenCreacion: null,
      costoHistorico: producto.precioCompra,
      stockConocido: producto.stock,
      precioVenta:
          accion.precioVentaExplicito ? accion.precioVenta : producto.precioVenta,
      categoria: accion.categoria ??
          (producto.categoria.trim().isEmpty ? null : producto.categoria),
    );
    if (accion.tipo != TipoAccionPlan.crearProducto) return conId;
    if ((accion.cantidad ?? 0) > 0) {
      return conId.copiar(tipo: TipoAccionPlan.entradaStock);
    }
    return conId.copiar(omitir: true);
  }

  Future<PlanAsistente> _planConFalta(
    List<AccionPlan> acciones,
    int indice,
    DatoFaltante dato,
  ) async {
    final accion = acciones[indice];
    final prefijo = _prefijo(accion, acciones.length);
    switch (dato) {
      case DatoFaltante.nombre:
        return _pregunta(
          acciones,
          indice,
          dato,
          '$prefijo¿Cómo se llama el producto?',
        );
      case DatoFaltante.cantidad:
        return _pregunta(
          acciones,
          indice,
          dato,
          '$prefijo¿Cuántas unidades de "${_nombre(accion)}"?',
        );
      case DatoFaltante.costo:
        return _pregunta(
          acciones,
          indice,
          dato,
          '$prefijo¿Cuál es el costo por unidad de "${_nombre(accion)}"?',
        );
      case DatoFaltante.precioVenta:
        return _pregunta(
          acciones,
          indice,
          dato,
          '$prefijo¿A qué precio vas a vender "${_nombre(accion)}"?',
        );
      case DatoFaltante.medio:
        return _pregunta(
          acciones,
          indice,
          dato,
          '$prefijo¿El cobro de "${_nombre(accion)}" fue en efectivo o por transferencia?',
          opciones: const [
            OpcionPlan(id: 'medio:efectivo', etiqueta: 'Efectivo'),
            OpcionPlan(id: 'medio:transferencia', etiqueta: 'Transferencia'),
          ],
        );
      case DatoFaltante.categoria:
        final categorias = await catalogo.categoriasDelNegocio();
        final sugerida = await catalogo.sugerirCategoria(_nombre(accion));
        if (categorias.isEmpty) {
          return _pregunta(
            acciones,
            indice,
            dato,
            '${prefijo}No encontré "${_nombre(accion)}". '
            'Puedo crearlo. El negocio todavía no tiene categorías: escribí el nombre de una.',
          );
        }
        final ordenadas = [...categorias];
        if (sugerida != null) {
          ordenadas.removeWhere(
            (item) => normalizarPlan(item) == normalizarPlan(sugerida),
          );
          ordenadas.insert(0, sugerida);
        }
        return _pregunta(
          acciones,
          indice,
          dato,
          '${prefijo}No encontré "${_nombre(accion)}". '
          'Puedo crearlo. Elegí una categoría del negocio.',
          opciones: [
            for (var i = 0; i < ordenadas.length; i++)
              OpcionPlan(
                id: 'cat:$i',
                etiqueta: ordenadas[i],
                detalle: sugerida != null && ordenadas[i] == sugerida
                    ? 'Sugerida'
                    : '',
                categoria: ordenadas[i],
              ),
          ],
        );
      case DatoFaltante.producto:
        return _pregunta(
          acciones,
          indice,
          dato,
          _preguntaProducto(accion, acciones.length),
        );
    }
  }

  DatoFaltante? _primerFalta(AccionPlan accion) {
    if (accion.nombre.trim().isEmpty && accion.nombreConfirmado == null) {
      return DatoFaltante.nombre;
    }
    final alta = accion.esAltaNueva;
    if (alta && (accion.categoria == null || accion.categoria!.trim().isEmpty)) {
      return DatoFaltante.categoria;
    }
    final pideCantidad = accion.tipo == TipoAccionPlan.entradaStock ||
        accion.tipo == TipoAccionPlan.venta;
    if (pideCantidad && (accion.cantidad == null || accion.cantidad! <= 0)) {
      return DatoFaltante.cantidad;
    }
    final pideCosto = alta || accion.tipo == TipoAccionPlan.entradaStock;
    if (pideCosto && !_importeValido(accion.costoUnitario)) {
      return DatoFaltante.costo;
    }
    if (alta && !_importeValido(accion.precioVenta)) {
      return DatoFaltante.precioVenta;
    }
    if (accion.tipo == TipoAccionPlan.venta && accion.medio == null) {
      return DatoFaltante.medio;
    }
    if (accion.costoUnitario != null && !_importeValido(accion.costoUnitario)) {
      return DatoFaltante.costo;
    }
    if (accion.precioVentaExplicito && !_importeValido(accion.precioVenta)) {
      return DatoFaltante.precioVenta;
    }
    return null;
  }

  AccionPlan _aplicarOpcion(
    AccionPlan accion,
    DatoFaltante? dato,
    OpcionPlan opcion,
  ) {
    switch (dato) {
      case DatoFaltante.producto:
        final id = opcion.productoId;
        if (id == null) return accion;
        return accion.copiar(
          productoId: id,
          nombreConfirmado: opcion.etiqueta,
          crear: false,
          buscado: true,
          origenCreacion: null,
          costoHistorico: opcion.precioCompra,
          stockConocido: opcion.stock,
          precioVenta:
              accion.precioVentaExplicito ? accion.precioVenta : opcion.precioVenta,
          categoria: accion.categoria ?? opcion.categoria,
        );
      case DatoFaltante.categoria:
        final categoria = opcion.categoria ?? opcion.etiqueta;
        return accion.copiar(categoria: categoria, crear: true, buscado: true);
      case DatoFaltante.medio:
        final medio = opcion.id == 'medio:transferencia' ? 'transferencia' : 'efectivo';
        return accion.copiar(medio: medio);
      default:
        return accion;
    }
  }

  Future<AccionPlan?> _aplicarTexto(
    AccionPlan accion,
    DatoFaltante dato,
    String texto,
    List<OpcionPlan> opciones,
  ) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return null;
    switch (dato) {
      case DatoFaltante.producto:
        final elegida = _opcionPorTexto(opciones, limpio);
        if (elegida == null) return null;
        return _aplicarOpcion(accion, dato, elegida);
      case DatoFaltante.categoria:
        final porOpcion = _opcionPorTexto(opciones, limpio);
        if (porOpcion != null) return _aplicarOpcion(accion, dato, porOpcion);
        final categorias = await catalogo.categoriasDelNegocio();
        if (categorias.isEmpty) {
          return accion.copiar(categoria: limpio, crear: true, buscado: true);
        }
        for (final categoria in categorias) {
          if (normalizarPlan(categoria) == normalizarPlan(limpio)) {
            return accion.copiar(
              categoria: categoria,
              crear: true,
              buscado: true,
            );
          }
        }
        return null;
      case DatoFaltante.medio:
        final medio = leerMedioTexto(limpio);
        if (medio == null) return null;
        return accion.copiar(medio: medio);
      case DatoFaltante.nombre:
        return accion.copiar(nombre: limpio, buscado: false);
      case DatoFaltante.cantidad:
        final cantidad = leerCantidadTexto(limpio);
        if (cantidad == null || cantidad <= 0) return null;
        return accion.copiar(cantidad: cantidad);
      case DatoFaltante.costo:
        final importe = leerImporte(limpio);
        if (importe == null || !_importeValido(importe)) return null;
        final esTotal = mencionaCostoTotal(limpio) && !mencionaCostoPorProducto(limpio);
        final cantidad = accion.cantidad;
        if (esTotal && cantidad != null && cantidad > 0) {
          return accion.copiar(
            costoUnitario: importe / cantidad,
            costoDesdeTotal: true,
          );
        }
        return accion.copiar(costoUnitario: importe, costoDesdeTotal: false);
      case DatoFaltante.precioVenta:
        final importe = leerImporte(limpio);
        if (importe == null || !_importeValido(importe)) return null;
        return accion.copiar(precioVenta: importe, precioVentaExplicito: true);
    }
  }

  List<AccionPlan> _corregirCostos(List<AccionPlan> acciones, String frase) {
    final porProducto = mencionaCostoPorProducto(frase);
    final totalFrase = importeCostoTotal(frase);
    final unitarioFrase = importeCostoPorProducto(frase);
    final conCosto = [
      for (var i = 0; i < acciones.length; i++)
        if (acciones[i].tipo != TipoAccionPlan.venta) i,
    ];
    if (conCosto.isEmpty) return acciones;
    final copia = [...acciones];
    if (porProducto && unitarioFrase != null && conCosto.length == 1) {
      final i = conCosto.first;
      copia[i] = copia[i].copiar(
        costoUnitario: unitarioFrase,
        costoDesdeTotal: false,
      );
      return copia;
    }
    if (porProducto || totalFrase == null) return copia;
    for (final i in conCosto) {
      final accion = copia[i];
      final cantidad = accion.cantidad;
      if (cantidad == null || cantidad <= 0 || accion.costoDesdeTotal) continue;
      final actual = accion.costoUnitario;
      if (actual == null && conCosto.length != 1) continue;
      if (actual != null && !_cerca(actual, totalFrase)) continue;
      copia[i] = accion.copiar(
        costoUnitario: totalFrase / cantidad,
        costoDesdeTotal: true,
      );
    }
    return copia;
  }

  void _propagar(List<AccionPlan> acciones) {
    for (var i = 0; i < acciones.length; i++) {
      final origen = acciones[i].origenCreacion;
      if (origen == null || origen < 0 || origen >= acciones.length) continue;
      final base = acciones[origen];
      final actual = acciones[i];
      acciones[i] = actual.copiar(
        categoria: actual.categoria ?? base.categoria,
        costoUnitario: actual.costoUnitario ?? base.costoUnitario,
        costoHistorico: actual.costoHistorico ?? base.costoUnitario ?? base.costoHistorico,
        precioVenta: actual.precioVentaExplicito
            ? actual.precioVenta
            : (base.precioVenta ?? actual.precioVenta),
        nombreConfirmado: actual.nombreConfirmado ?? base.nombreConfirmado,
      );
    }
  }

  bool _sumaStock(AccionPlan accion, List<AccionPlan> todas) {
    if (accion.omitir) return false;
    if (accion.tipo == TipoAccionPlan.entradaStock) return true;
    if (accion.tipo == TipoAccionPlan.crearProducto && (accion.cantidad ?? 0) > 0) {
      return !_hayEntradaIgual(todas, accion);
    }
    if (accion.tipo == TipoAccionPlan.venta && accion.crear) {
      return !_hayEntradaIgual(todas, accion);
    }
    final origen = accion.origenCreacion;
    if (accion.tipo == TipoAccionPlan.venta &&
        origen != null &&
        accion.crear == false &&
        !_hayEntradaIgual(todas, accion) &&
        _laAltaNoCargaStock(todas, origen)) {
      return true;
    }
    return false;
  }

  bool _laAltaNoCargaStock(List<AccionPlan> todas, int origen) {
    if (origen < 0 || origen >= todas.length) return false;
    final alta = todas[origen];
    if (alta.tipo == TipoAccionPlan.entradaStock) return false;
    if ((alta.cantidad ?? 0) > 0 && alta.tipo == TipoAccionPlan.crearProducto) {
      return false;
    }
    return alta.crear || alta.tipo == TipoAccionPlan.crearProducto;
  }

  bool _hayEntradaIgual(List<AccionPlan> todas, AccionPlan accion) {
    final clave = _clave(accion.nombreConfirmado ?? accion.nombre);
    for (final otra in todas) {
      if (identical(otra, accion)) continue;
      if (otra.tipo != TipoAccionPlan.entradaStock || otra.omitir) continue;
      if (_clave(otra.nombreConfirmado ?? otra.nombre) == clave) return true;
    }
    return false;
  }

  List<List<AccionPlan>> _agruparVentas(List<AccionPlan> acciones) {
    final grupos = <String, List<AccionPlan>>{};
    final orden = <String>[];
    for (final accion in acciones) {
      if (accion.tipo != TipoAccionPlan.venta || accion.omitir) continue;
      final clave = '${accion.medio}|${_cliente(accion)}';
      final lista = grupos.putIfAbsent(clave, () {
        orden.add(clave);
        return <AccionPlan>[];
      });
      lista.add(accion);
    }
    return [for (final clave in orden) grupos[clave]!];
  }

  int? _ancla(List<AccionPlan> acciones, int indice) {
    final clave = _clave(acciones[indice].nombre);
    if (clave.isEmpty) return null;
    for (var i = 0; i < indice; i++) {
      final previa = acciones[i];
      final otra = _clave(previa.nombreConfirmado ?? previa.nombre);
      if (otra == clave) return i;
    }
    return null;
  }

  List<OpcionPlan> _opcionesProducto(ResultadoBusquedaProducto busqueda) {
    final vistos = <int>{};
    final opciones = <OpcionPlan>[];
    for (final producto in [...busqueda.exactos, ...busqueda.parecidos]) {
      if (!vistos.add(producto.id)) continue;
      final partes = <String>[];
      if (producto.categoria.trim().isNotEmpty) partes.add(producto.categoria);
      partes.add('stock ${producto.stock}');
      partes.add('compra ${_moneda(producto.precioCompra)}');
      partes.add('venta ${_moneda(producto.precioVenta)}');
      if (!producto.activo) partes.add('oculto en la vidriera');
      opciones.add(
        OpcionPlan(
          id: 'prod:${producto.id}',
          etiqueta: producto.nombre,
          detalle: partes.join(' · '),
          productoId: producto.id,
          precioCompra: producto.precioCompra,
          precioVenta: producto.precioVenta,
          stock: producto.stock,
          categoria: producto.categoria.trim().isEmpty ? null : producto.categoria,
          fotoUrl: producto.fotoUrl,
          fotoBytes: producto.fotoBytes,
        ),
      );
    }
    return opciones;
  }

  OpcionPlan? _opcionPorTexto(List<OpcionPlan> opciones, String texto) {
    if (opciones.isEmpty) return null;
    final numero = int.tryParse(texto.trim());
    if (numero != null && numero >= 1 && numero <= opciones.length) {
      return opciones[numero - 1];
    }
    final clave = normalizarPlan(texto);
    final exactas = [
      for (final opcion in opciones)
        if (normalizarPlan(opcion.etiqueta) == clave) opcion,
    ];
    if (exactas.length == 1) return exactas.first;
    if (exactas.length > 1) return null;
    final contiene = [
      for (final opcion in opciones)
        if (normalizarPlan(opcion.etiqueta).contains(clave) ||
            clave.contains(normalizarPlan(opcion.etiqueta)))
          opcion,
    ];
    if (contiene.length == 1) return contiene.first;
    return null;
  }

  /// "Agregar iPhone" no trae cantidad. Igual es una entrada y se pregunta el resto.
  AccionPlan? _recuperarFraseCorta(String frase) {
    final texto = normalizarPlan(frase);
    if (texto.isEmpty || RegExp(r'\d').hasMatch(texto)) return null;
    final entrada = RegExp(
      r'^(?:agrega\w*|suma\w*|entra\w*|carga\w*)\s+(?:de\s+|el\s+|la\s+|un\s+|una\s+)?(.+)$',
    ).firstMatch(texto);
    if (entrada != null) {
      final nombre = _nombreRecuperado(entrada.group(1) ?? '');
      if (nombre == null) return null;
      return AccionPlan(
        tipo: TipoAccionPlan.entradaStock,
        nombre: nombre,
      );
    }
    final venta = RegExp(
      r'^(?:vendi\w*|vende\w*|venta\s+de)\s+(?:de\s+|el\s+|la\s+|un\s+|una\s+)?(.+)$',
    ).firstMatch(texto);
    if (venta == null) return null;
    final nombre = _nombreRecuperado(venta.group(1) ?? '');
    if (nombre == null) return null;
    return AccionPlan(tipo: TipoAccionPlan.venta, nombre: nombre);
  }

  String? _nombreRecuperado(String resto) {
    final nombre = resto
        .replaceAll(RegExp(r'\b(por favor|porfa|che)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (nombre.length < 2) return null;
    return nombre;
  }

  Future<void> _marcarFotos(List<AccionPlan> acciones) async {
    final ids = <int>{
      for (final accion in acciones)
        if (accion.productoId != null && !accion.omitir) accion.productoId!,
    };
    final sinFoto = await catalogo.idsVisiblesSinFoto(ids);
    final vistos = <String>{};
    for (var i = 0; i < acciones.length; i++) {
      final accion = acciones[i];
      if (accion.omitir) continue;
      final id = accion.productoId;
      final nueva = accion.esAltaNueva;
      if (!nueva && (id == null || !sinFoto.contains(id))) continue;
      final clave = id == null
          ? 'nuevo:${_clave(accion.nombreConfirmado ?? accion.nombre)}'
          : 'id:$id';
      if (!vistos.add(clave)) continue;
      acciones[i] = accion.copiar(pideFoto: true);
    }
  }

  Future<void> _guardarFotos(
    List<AccionPlan> acciones,
    Map<int, String> fotosBase64,
    List<String> hechos,
  ) async {
    for (final entrada in fotosBase64.entries) {
      final indice = entrada.key;
      if (indice < 0 || indice >= acciones.length) continue;
      final accion = acciones[indice];
      final id = accion.productoId;
      final foto = entrada.value.trim();
      if (id == null || foto.isEmpty) continue;
      final rechazo = motivoRechazoFoto(foto);
      if (rechazo != null) {
        hechos.add(
          'Guardé "${accion.nombreConfirmado ?? accion.nombre}", pero la foto no entró: $rechazo',
        );
        continue;
      }
      try {
        final actual = await const VidrieraLocal().de(id);
        final variantes = [
          for (final item in actual.galeria)
            if (item.variante.trim().isNotEmpty) item,
        ];
        await const VidrieraLocal().guardar(
          productoId: id,
          descripcion: actual.descripcion,
          fotoBase64: '',
          fotos: [
            FotoVidriera(base64: foto),
            ...variantes,
          ],
        );
        hechos.add(
          'Dejé la foto de "${accion.nombreConfirmado ?? accion.nombre}" lista para la página.',
        );
      } on VidrieraRechazada catch (error) {
        hechos.add(
          'Guardé "${accion.nombreConfirmado ?? accion.nombre}", pero la foto no entró: ${error.mensaje}',
        );
      }
    }
  }

  ResultadoInterpretacion _mostrar(PlanAsistente plan) {
    if (plan.listo) {
      return ResultadoInterpretacion(mensaje: _resumen(plan), plan: plan);
    }
    return ResultadoInterpretacion(
      mensaje: plan.pregunta ?? 'Me falta un dato. Todavía no guardé nada.',
      plan: plan,
    );
  }

  String _resumen(PlanAsistente plan) {
    final buffer = StringBuffer('Revisá el plan. Todavía no guardé nada.');
    for (final accion in plan.acciones) {
      buffer
        ..writeln()
        ..write('• ${_linea(accion, plan.acciones)}');
    }
    if (plan.tieneEscritura) {
      buffer
        ..writeln()
        ..write(
          'Al confirmar creo lo que falte, cargo el stock y después registro las ventas.',
        );
    }
    if (plan.acciones.any((accion) => accion.pideFoto)) {
      buffer
        ..writeln()
        ..write(
          'Abajo podés subir una foto, generar una con fondo blanco o dejarla para después.',
        );
    }
    return buffer.toString();
  }

  String _linea(AccionPlan accion, List<AccionPlan> todas) {
    final nombre = _nombre(accion);
    if (accion.omitir) {
      return '$nombre ya está cargado. No lo creo otra vez.';
    }
    switch (accion.tipo) {
      case TipoAccionPlan.crearProducto:
        final cantidad = accion.cantidad ?? 0;
        final extra = cantidad > 0
            ? ' Después sumo $cantidad ${_unidades(cantidad)} a ${_moneda(accion.costoUnitario ?? 0)} c/u.'
            : '';
        return 'Creo "$nombre" en ${accion.categoria}. '
            'Compra ${_moneda(accion.costoUnitario ?? 0)}. '
            'Venta ${_moneda(accion.precioVenta ?? 0)}.$extra';
      case TipoAccionPlan.entradaStock:
        final cantidad = accion.cantidad ?? 0;
        final costo = accion.costoUnitario ?? 0;
        final total = costo * cantidad;
        final venta = accion.precioVentaExplicito
            ? 'Precio de venta nuevo: ${_moneda(accion.precioVenta ?? 0)}.'
            : 'Dejo el precio de venta que ya tiene'
                '${accion.precioVenta == null ? '' : ' (${_moneda(accion.precioVenta!)})'}.';
        final alta = accion.crear ? ' No está cargado: primero lo creo en ${accion.categoria}.' : '';
        return 'Entrada de $cantidad ${_unidades(cantidad)} de "$nombre" '
            'a ${_moneda(costo)} c/u (costo total ${_moneda(total)}). '
            '$venta$alta';
      case TipoAccionPlan.venta:
        final cantidad = accion.cantidad ?? 0;
        final precio = accion.precioVenta;
        final costo = accion.costoHistorico ?? accion.costoUnitario;
        final ganancia = precio == null || costo == null
            ? ''
            : ' Ganancia estimada ${_moneda((precio - costo) * cantidad)} '
                '(venta menos costo histórico).';
        final alta = accion.crear || accion.origenCreacion != null
            ? ' Si todavía no existe, lo creo y cargo el stock antes de vender.'
            : '';
        final cobro = accion.medio == 'transferencia' ? 'transferencia' : 'efectivo';
        return 'Venta de $cantidad ${_unidades(cantidad)} de "$nombre" '
            'por $cobro, cliente ${_cliente(accion)}. '
            'Precio ${_moneda(precio ?? 0)}.'
            '${costo == null ? '' : ' Costo histórico ${_moneda(costo)}.'}'
            '$ganancia$alta';
    }
  }

  String _preguntaProducto(AccionPlan accion, int total) {
    return '${_prefijo(accion, total)}'
        'Encontré varios parecidos a "${_nombre(accion)}". '
        'Elegí cuál es. No elijo por vos. Todavía no guardé nada.';
  }

  String _prefijo(AccionPlan accion, int total) {
    if (total <= 1) return '';
    final cual = switch (accion.tipo) {
      TipoAccionPlan.entradaStock => 'la entrada',
      TipoAccionPlan.crearProducto => 'el alta',
      TipoAccionPlan.venta => 'la venta',
    };
    return 'Para $cual de "${_nombre(accion)}": ';
  }

  PlanAsistente _pregunta(
    List<AccionPlan> acciones,
    int indice,
    DatoFaltante dato,
    String texto, {
    List<OpcionPlan> opciones = const [],
  }) {
    final pregunta = texto.endsWith('Todavía no guardé nada.')
        ? texto
        : '$texto Todavía no guardé nada.';
    return PlanAsistente(
      acciones: acciones,
      estado: dato == DatoFaltante.producto
          ? EstadoPlanAsistente.ambiguo
          : EstadoPlanAsistente.incompleto,
      indicePendiente: indice,
      pregunta: pregunta,
      opciones: opciones,
      datoFaltante: dato,
    );
  }

  Future<void> _medir(
    ResultadoProveedorIa respuesta, {
    required int acciones,
    required bool error,
  }) async {
    try {
      await const MetricasAsistente().registrar(
        uso: respuesta.uso,
        modelo: OpenAiChatService.modelo,
        versionPrompt: PromptsAsistente.versionPrompt,
        acciones: acciones,
        error: error,
      );
    } catch (_) {
      // La medición no frena el plan.
    }
  }

  /// Ficha corta del negocio como datos. No lleva catálogo, clientes ni fecha.
  Future<String> _fichaNegocio() async {
    try {
      final negocio = await NegocioStore().leer();
      final categorias = await catalogo.categoriasDelNegocio();
      final funciones = negocio?.funciones ?? const FuncionesAsistente();
      return jsonEncode({
        if (negocio != null) 'nombre': negocio.nombre,
        if (negocio != null && negocio.rubros.isNotEmpty)
          'rubros': negocio.rubros,
        'categorias': categorias,
        if (negocio != null) 'moneda': negocio.moneda,
        'funciones': {'anotarVenta': funciones.anotarVenta},
      });
    } catch (_) {
      return '{}';
    }
  }

  Future<FuncionesAsistente> _leerFunciones() {
    return NegocioStore().leerFuncionesAsistente();
  }

  String _mensajeFallo(List<String> hechos, String error) {
    if (hechos.isEmpty) return 'No guardé nada. $error';
    return 'El plan no terminó. La venta que falló no quedó a medias.\n'
        'Esto sí se guardó:\n${hechos.join('\n')}\n'
        'Acá se frenó: $error';
  }

  String _cliente(AccionPlan accion) {
    final cliente = accion.cliente?.trim();
    if (cliente == null || cliente.isEmpty) return 'Mostrador';
    return cliente;
  }

  String _nombre(AccionPlan accion) =>
      accion.nombreConfirmado ?? accion.nombre;

  String _clave(String nombre) => normalizarPlan(nombre);

  String _unidades(int cantidad) => cantidad == 1 ? 'unidad' : 'unidades';

  String _moneda(double valor) =>
      '\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  bool _importeValido(double? valor) {
    if (valor == null) return false;
    return !valor.isNaN && !valor.isInfinite && valor >= 0;
  }

  bool _cerca(double a, double b) => (a - b).abs() < 0.009;
}

class _Identificacion {
  const _Identificacion(this.accion, {this.opciones = const [], this.pregunta});

  final AccionPlan accion;
  final List<OpcionPlan> opciones;
  final String? pregunta;
}

class ResultadoInterpretacion {
  const ResultadoInterpretacion({
    required this.mensaje,
    this.plan,
    this.error = false,
  });

  final String mensaje;
  final PlanAsistente? plan;
  final bool error;
}

class ResultadoEjecucion {
  const ResultadoEjecucion({
    required this.guardo,
    required this.parcial,
    required this.mensaje,
  });

  final bool guardo;

  /// true si una parte ya se escribió y otra se frenó.
  final bool parcial;
  final String mensaje;
}
