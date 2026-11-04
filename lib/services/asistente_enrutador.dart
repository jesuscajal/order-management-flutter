import 'dart:convert';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/pedido_repository.dart';
import '../data/stock_repository.dart';
import 'negocio_contexto.dart';
import 'openai_chat_service.dart';

/// Lo único que el prototipo deja pasar hacia el modelo o hacia la base.
enum IntencionAsistente { venta, producto, ajusteStock, stock, fuera }

const alcanceAsistente =
    'Puedo informar stock, deudas, pedidos y capital; crear productos, '
    'ajustar stock y registrar ventas.';

const mensajeSinCupo = 'Se acabaron los mensajes de prueba.';

IntencionAsistente clasificarIntencion(String texto) {
  final t = _clave(texto);
  if (t.isEmpty) return IntencionAsistente.fuera;

  final alta = _esAltaProducto(t);
  final venta = _esVenta(t);
  final stock = _esConsultaStock(t);

  if (venta && !alta) return IntencionAsistente.venta;
  if (alta && !venta) return IntencionAsistente.producto;
  if (venta && alta) {
    final fuerte = RegExp(
      r'\b(pedido|pedidos|vendi\w*|vender|vende\w*|encarg\w*|sena)\b',
    ).hasMatch(_sinPrecioDeVenta(t));
    final esLaVenta = RegExp(
      r'\b(una venta|la venta|el pedido|registrar venta|registrar una venta|anotar una venta|anota una venta|anotar un pedido|anota un pedido)\b',
    ).hasMatch(t);
    final hablaDeCompra = RegExp(
      r'\b(precio de compra|precio de costo|precio costo|de compra|compra|costo)\b',
    ).hasMatch(t);
    if ((fuerte || esLaVenta) && !hablaDeCompra) {
      return IntencionAsistente.venta;
    }
    return IntencionAsistente.producto;
  }
  if (_esMovimientoStock(t)) return IntencionAsistente.fuera;
  if (stock) return IntencionAsistente.stock;
  return IntencionAsistente.fuera;
}

String respuestaFueraDeAlcance(String texto) {
  if (mencionaFoto(texto)) {
    return '$alcanceAsistente La carga por foto queda fuera de este prototipo.';
  }
  return alcanceAsistente;
}

bool mencionaFoto(String texto) {
  return RegExp(r'\b(foto|imagen|camara|galeria)\b').hasMatch(_clave(texto));
}

bool esCancelacion(String texto) {
  final t = _clave(texto).trim();
  if (t.isEmpty || t.length > 40) return false;
  return RegExp(
    r'^(cancelar|cancela|cancelo|olvidate|olvida|deja|dejalo|mejor no|no guardes)\.?$',
  ).hasMatch(t);
}

bool esAfirmacion(String texto) {
  final t = _clave(texto).trim();
  if (t.isEmpty || t.length > 24) return false;
  return RegExp(
    r'^(si|dale|ok|okay|confirmo|confirmar|guardar|guardalo|de una)\.?$',
  ).hasMatch(t);
}

/// Charla que no completa una venta ni un producto, aunque haya un borrador abierto.
bool esTemaFuera(String texto) {
  final t = _clave(texto);
  if (mencionaFoto(texto)) return true;
  return RegExp(
    r'\b(chiste|clima|pronostico|capital|deuda|deudores|dolar|bitcoin|btc|hola|buenas|buenos dias|gracias|chau|adios|ayuda|quien sos|que podes|cotizacion|factura)\b',
  ).hasMatch(t);
}

class LineaVenta {
  const LineaVenta({
    required this.producto,
    required this.cantidad,
    this.precioVenta,
  });

  final String producto;
  final int cantidad;
  final double? precioVenta;
}

sealed class BorradorConfirmable {
  const BorradorConfirmable({required this.resumen});

  final String resumen;
}

class BorradorVenta extends BorradorConfirmable {
  const BorradorVenta({
    required this.cliente,
    required this.montoSena,
    required this.lineas,
    required super.resumen,
  });

  final String cliente;
  final double montoSena;
  final List<LineaVenta> lineas;
}

class BorradorProducto extends BorradorConfirmable {
  const BorradorProducto({
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    this.cantidadInicial,
    this.propietario = StockRepository.propietarioYo,
    required super.resumen,
  });

  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final int? cantidadInicial;
  final String propietario;
}

class BorradorAjusteStock extends BorradorConfirmable {
  const BorradorAjusteStock({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.tipo,
    required this.propietario,
    required super.resumen,
  });

  final int productoId;
  final String nombre;
  final int cantidad;
  final String tipo;
  final String propietario;
}

sealed class Interpretacion {
  const Interpretacion();
}

class InterpretacionPregunta extends Interpretacion {
  const InterpretacionPregunta({
    required this.intencion,
    required this.pregunta,
  });

  final IntencionAsistente intencion;
  final String pregunta;
}

class InterpretacionLista extends Interpretacion {
  const InterpretacionLista(this.borrador);

  final BorradorConfirmable borrador;
}

class ResultadoAccion {
  const ResultadoAccion({required this.guardo, required this.mensaje});

  final bool guardo;
  final String mensaje;
}

/// Filtra la charla, pide el JSON al modelo y recién al confirmar escribe
/// con los repositorios que ya existen.
class AsistenteEnrutador {
  final OpenAiChatService _chat;

  AsistenteEnrutador({OpenAiChatService? chat})
      : _chat = chat ?? OpenAiChatService();

  Future<Interpretacion> interpretar({
    required AppDatabase database,
    required String apiKey,
    required String contextoNegocio,
    required List<MensajeChat> historial,
    required IntencionAsistente intencion,
  }) async {
    final crudo = await _chat.responder(
      apiKey: apiKey,
      contextoNegocio: contextoNegocio,
      historial: historial,
      intencion: intencion.name,
    );
    final datos = _extraerJson(crudo);
    if (datos == null) {
      return InterpretacionPregunta(
        intencion: intencion,
        pregunta:
            'No pude leer los datos. Repetime el nombre y los importes en una frase.',
      );
    }
    if (intencion == IntencionAsistente.producto) {
      return _interpretarProducto(database, datos);
    }
    return _interpretarVenta(database, datos);
  }

  Future<String> consultarStock({
    required AppDatabase database,
    required String texto,
  }) async {
    final productos = await NegocioContexto(database).listarProductosConStock();
    if (productos.isEmpty) {
      return 'No hay productos cargados en el stock.';
    }

    final consulta = _clave(texto);
    final especificos = productos
        .where((producto) => _consultaApuntaA(consulta, producto.nombre))
        .toList();
    if (especificos.isNotEmpty) {
      return _formatearStock(especificos, general: false);
    }
    if (_sobraConsulta(consulta).isEmpty) {
      return _formatearStock(productos, general: true);
    }
    final nombres =
        productos.take(15).map((producto) => producto.nombre).join(', ');
    return 'No encontré ese producto en el stock. Los cargados son: $nombres.';
  }

  Future<ResultadoAccion> confirmar({
    required AppDatabase database,
    required BorradorConfirmable borrador,
  }) {
    if (borrador is BorradorProducto) {
      return _confirmarProducto(database, borrador);
    }
    if (borrador is BorradorAjusteStock) {
      return _confirmarAjuste(database, borrador);
    }
    return _confirmarVenta(database, borrador as BorradorVenta);
  }

  Future<Interpretacion> interpretarDatos({
    required AppDatabase database,
    required String accion,
    required Map<String, dynamic> datos,
  }) {
    switch (accion) {
      case 'crear_producto':
        return _interpretarProducto(database, datos);
      case 'ajustar_stock':
        return _interpretarAjuste(database, datos);
      case 'registrar_venta':
        return _interpretarVenta(database, datos);
      default:
        return Future.value(
          const InterpretacionPregunta(
            intencion: IntencionAsistente.fuera,
            pregunta: alcanceAsistente,
          ),
        );
    }
  }
}

Future<Interpretacion> _interpretarProducto(
  AppDatabase database,
  Map<String, dynamic> datos,
) async {
  final nombre = _texto(datos['nombre'] ?? datos['producto']);
  final compra = _leerPrecio(
      datos['precioCompra'] ?? datos['precio_compra'] ?? datos['costo']);
  final venta = _leerPrecio(datos['precioVenta'] ?? datos['precio_venta']);
  final cantidad = _leerCantidad(
    datos['cantidadInicial'] ?? datos['cantidad_inicial'],
  );
  final propietario = _propietario(datos['propietario']);

  if (nombre.isEmpty) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.producto,
      pregunta: '¿Cómo se llama el producto?',
    );
  }
  if (compra == null && venta == null) {
    return InterpretacionPregunta(
      intencion: IntencionAsistente.producto,
      pregunta: 'Pasame el precio de compra y el precio de venta de $nombre.',
    );
  }
  if (compra == null) {
    return InterpretacionPregunta(
      intencion: IntencionAsistente.producto,
      pregunta: '¿Cuál es el precio de compra de $nombre?',
    );
  }
  if (venta == null) {
    return InterpretacionPregunta(
      intencion: IntencionAsistente.producto,
      pregunta: '¿Cuál es el precio de venta de $nombre?',
    );
  }
  if (!_precioValido(compra) || !_precioValido(venta)) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.producto,
      pregunta:
          'Los precios tienen que ser números desde cero. Pasamelos de nuevo.',
    );
  }
  if (cantidad != null && cantidad <= 0) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.producto,
      pregunta: 'La cantidad inicial tiene que ser un entero mayor a cero.',
    );
  }

  final productos = await PedidoRepository(database).listarProductos();
  final resolucion = _resolverNombre(
    productos.map((producto) => producto.nombre).toList(),
    nombre,
  );
  if (resolucion.opciones.length > 1) {
    return InterpretacionPregunta(
      intencion: IntencionAsistente.producto,
      pregunta:
          'Hay más de un producto para "$nombre": ${resolucion.opciones.join(', ')}. Decime el nombre completo.',
    );
  }

  final nombreFinal = resolucion.unico ?? nombre;
  final yaEstaba = resolucion.unico != null;
  final resumen = StringBuffer()
    ..writeln('Revisá el producto. Todavía no guardé nada.')
    ..writeln('Nombre: $nombreFinal')
    ..writeln('Precio de compra: ${_precio(compra)}')
    ..writeln('Precio de venta: ${_precio(venta)}');
  if (cantidad != null) {
    resumen.writeln('Cantidad inicial: $cantidad ($propietario).');
  }
  if (yaEstaba) {
    resumen.writeln(
      'Ya hay un producto con ese nombre. Al confirmar actualizo los dos precios.',
    );
  } else {
    resumen.writeln('Al confirmar lo agrego con el nombre y los dos precios.');
  }
  resumen.write(
    'Se guardan el nombre, el precio de compra y el precio de venta.',
  );

  return InterpretacionLista(
    BorradorProducto(
      nombre: nombreFinal,
      precioCompra: compra,
      precioVenta: venta,
      cantidadInicial: cantidad,
      propietario: propietario,
      resumen: resumen.toString(),
    ),
  );
}

Future<Interpretacion> _interpretarAjuste(
  AppDatabase database,
  Map<String, dynamic> datos,
) async {
  final nombre = _texto(datos['nombre'] ?? datos['producto']);
  final cantidad = _leerCantidad(datos['cantidad']);
  final tipo = _tipoMovimiento(datos['tipo'] ?? datos['movimiento']);
  final propietario = _propietario(datos['propietario']);
  if (nombre.isEmpty) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.ajusteStock,
      pregunta: '¿Qué producto querés ajustar?',
    );
  }
  if (cantidad == null || cantidad <= 0) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.ajusteStock,
      pregunta:
          '¿Cuántas unidades querés mover? Tiene que ser un entero mayor a cero.',
    );
  }
  if (tipo == null) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.ajusteStock,
      pregunta: '¿Es una entrada o una salida de stock?',
    );
  }

  final productos = await PedidoRepository(database).listarProductos();
  final resolucion = _resolverNombre(
    productos.map((producto) => producto.nombre).toList(),
    nombre,
  );
  if (resolucion.opciones.length > 1) {
    return InterpretacionPregunta(
      intencion: IntencionAsistente.ajusteStock,
      pregunta:
          'Hay más de un producto para "$nombre": ${resolucion.opciones.join(', ')}. Decime el nombre completo.',
    );
  }
  if (resolucion.unico == null) {
    return InterpretacionPregunta(
      intencion: IntencionAsistente.ajusteStock,
      pregunta:
          'No encontré "$nombre" en el stock. Primero crealo con precio de compra y venta.',
    );
  }
  final producto = productos.firstWhere(
    (item) => _clave(item.nombre) == _clave(resolucion.unico!),
  );
  final etiqueta = tipo == StockRepository.tipoEntrada ? 'Entrada' : 'Salida';
  return InterpretacionLista(
    BorradorAjusteStock(
      productoId: producto.id,
      nombre: producto.nombre,
      cantidad: cantidad,
      tipo: tipo,
      propietario: propietario,
      resumen: 'Revisá el ajuste. Todavía no guardé nada.\n'
          '$etiqueta: $cantidad unidades de ${producto.nombre}.\n'
          'Propietario: $propietario.',
    ),
  );
}

Future<Interpretacion> _interpretarVenta(
  AppDatabase database,
  Map<String, dynamic> datos,
) async {
  final cliente = _texto(datos['cliente'] ?? datos['clienteNombre']);
  final sena = _leerPrecio(
          datos['montoSena'] ?? datos['montoSenado'] ?? datos['sena']) ??
      0;
  if (cliente.isEmpty) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.venta,
      pregunta:
          '¿A nombre de qué cliente registro la venta? Tiene que estar cargado.',
    );
  }
  if (!_precioValido(sena)) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.venta,
      pregunta: 'La seña tiene que ser un número desde cero.',
    );
  }

  final crudas =
      _lista(datos['lineas'] ?? datos['items'] ?? datos['productos']);
  if (crudas.isEmpty) {
    return const InterpretacionPregunta(
      intencion: IntencionAsistente.venta,
      pregunta: '¿Qué producto y qué cantidad incluye la venta?',
    );
  }

  final repo = PedidoRepository(database);
  final productos = await repo.listarProductos();
  final lineas = <LineaVenta>[];
  final notas = <String>[];

  for (final cruda in crudas) {
    if (cruda is! Map) {
      return const InterpretacionPregunta(
        intencion: IntencionAsistente.venta,
        pregunta: 'Repetime el producto y la cantidad de la venta.',
      );
    }
    final mapa = Map<String, dynamic>.from(cruda);
    final nombre = _texto(mapa['producto'] ?? mapa['nombre']);
    if (nombre.isEmpty) {
      return const InterpretacionPregunta(
        intencion: IntencionAsistente.venta,
        pregunta: '¿Qué producto incluye la venta?',
      );
    }
    final cantidadLeida = _leerCantidad(mapa['cantidad']);
    if (mapa['cantidad'] != null && cantidadLeida == null) {
      return InterpretacionPregunta(
        intencion: IntencionAsistente.venta,
        pregunta: 'La cantidad de $nombre tiene que ser un número entero.',
      );
    }
    if (cantidadLeida == null) {
      return InterpretacionPregunta(
        intencion: IntencionAsistente.venta,
        pregunta: '¿Cuántas unidades de $nombre anoto?',
      );
    }
    if (cantidadLeida <= 0) {
      return InterpretacionPregunta(
        intencion: IntencionAsistente.venta,
        pregunta: 'La cantidad de $nombre tiene que ser mayor a cero.',
      );
    }
    final precioDicho =
        _leerPrecio(mapa['precioVenta'] ?? mapa['precio_venta']);
    if (precioDicho != null && !_precioValido(precioDicho)) {
      return InterpretacionPregunta(
        intencion: IntencionAsistente.venta,
        pregunta:
            'El precio de venta de $nombre tiene que ser un número desde cero.',
      );
    }

    final resolucion = _resolverNombre(
      productos.map((producto) => producto.nombre).toList(),
      nombre,
    );
    if (resolucion.opciones.length > 1) {
      return InterpretacionPregunta(
        intencion: IntencionAsistente.venta,
        pregunta:
            'Hay más de un producto para "$nombre": ${resolucion.opciones.join(', ')}. Decime cuál va en la venta.',
      );
    }
    if (resolucion.unico == null && precioDicho == null) {
      return InterpretacionPregunta(
        intencion: IntencionAsistente.venta,
        pregunta:
            '$nombre no está cargado. Pasame el precio de venta para poder agregarlo al pedido.',
      );
    }

    final nombreFinal = resolucion.unico ?? nombre;
    final catalogo = resolucion.unico == null
        ? null
        : _buscarProducto(productos, resolucion.unico!);
    lineas.add(
      LineaVenta(
        producto: nombreFinal,
        cantidad: cantidadLeida,
        precioVenta: catalogo == null ? precioDicho : null,
      ),
    );
    if (catalogo != null) {
      notas.add(
        '$nombreFinal x$cantidadLeida, precio de venta del producto ${_precio(catalogo.precioVenta)}.',
      );
      if (precioDicho != null && precioDicho != catalogo.precioVenta) {
        notas.add(
          'El precio ${_precio(precioDicho)} que dijiste queda afuera: la línea del pedido guarda producto y cantidad.',
        );
      }
    } else {
      notas.add(
        '$nombreFinal x$cantidadLeida. No está cargado: al confirmar se crea con precio de venta ${_precio(precioDicho!)} y precio de compra 0.',
      );
    }
  }

  final clientes = await repo.listarClientes();
  final clienteResuelto = _resolverNombre(
    clientes.map((clienteItem) => clienteItem.nombre).toList(),
    cliente,
  );
  if (clienteResuelto.opciones.length > 1) {
    return InterpretacionPregunta(
      intencion: IntencionAsistente.venta,
      pregunta:
          'Encontré más de un cliente para "$cliente": ${clienteResuelto.opciones.join(', ')}. Decime cuál es.',
    );
  }

  final nombreCliente = clienteResuelto.unico ?? cliente;
  final resumen = StringBuffer()
    ..writeln('Revisá la venta. Todavía no guardé nada.')
    ..writeln('Cliente: $nombreCliente');
  if (clienteResuelto.unico == null) {
    resumen.writeln(
      'Ese cliente no está cargado. Al confirmar también lo creo.',
    );
  }
  resumen
    ..writeln('Estado: pendiente')
    ..writeln('Seña: ${_precio(sena)}')
    ..writeln('Productos:');
  for (final nota in notas) {
    resumen.writeln('- $nota');
  }
  resumen.write('El pedido guarda el cliente, los productos y las cantidades.');

  return InterpretacionLista(
    BorradorVenta(
      cliente: nombreCliente,
      montoSena: sena,
      lineas: lineas,
      resumen: resumen.toString(),
    ),
  );
}

Future<ResultadoAccion> _confirmarProducto(
  AppDatabase database,
  BorradorProducto borrador,
) async {
  if (borrador.nombre.trim().isEmpty) {
    return const ResultadoAccion(
      guardo: false,
      mensaje: 'Falta el nombre del producto. La confirmación sigue visible.',
    );
  }
  if (!_precioValido(borrador.precioCompra) ||
      !_precioValido(borrador.precioVenta)) {
    return const ResultadoAccion(
      guardo: false,
      mensaje: 'Los precios no son válidos. La confirmación sigue visible.',
    );
  }

  final pedidos = PedidoRepository(database);
  final stock = StockRepository(database);
  try {
    final cantidad = borrador.cantidadInicial;
    if (cantidad != null) {
      if (cantidad <= 0) {
        return const ResultadoAccion(
          guardo: false,
          mensaje:
              'La cantidad inicial debe ser mayor a cero. La confirmación sigue visible.',
        );
      }
      await stock.registrarEntrada(
        nombre: borrador.nombre,
        cantidad: cantidad,
        precioCompra: borrador.precioCompra,
        precioVenta: borrador.precioVenta,
        propietario: borrador.propietario,
      );
      return ResultadoAccion(
        guardo: true,
        mensaje: 'Guardé "${borrador.nombre}" y sumé $cantidad unidades a '
            '${borrador.propietario}.\n'
            'Compra: ${_precio(borrador.precioCompra)}. '
            'Venta: ${_precio(borrador.precioVenta)}.',
      );
    }
    final productos = await pedidos.listarProductos();
    final resolucion = _resolverNombre(
      productos.map((producto) => producto.nombre).toList(),
      borrador.nombre,
    );
    if (resolucion.opciones.length > 1) {
      return ResultadoAccion(
        guardo: false,
        mensaje:
            'Hay más de un producto con ese nombre (${resolucion.opciones.join(', ')}). No actualicé precios. La confirmación sigue visible.',
      );
    }

    if (resolucion.unico != null) {
      final existente = _buscarProducto(productos, resolucion.unico!);
      if (existente == null) {
        return const ResultadoAccion(
          guardo: false,
          mensaje:
              'No encontré el producto para actualizar los precios. La confirmación sigue visible.',
        );
      }
      await stock.actualizarPrecios(
        productoId: existente.id,
        precioCompra: borrador.precioCompra,
        precioVenta: borrador.precioVenta,
      );
      return ResultadoAccion(
        guardo: true,
        mensaje: 'Actualicé "${existente.nombre}".\n'
            'Precio de compra: ${_precio(borrador.precioCompra)}\n'
            'Precio de venta: ${_precio(borrador.precioVenta)}',
      );
    }

    final id = await pedidos.crearProductoMinimo(
      nombre: borrador.nombre,
      precioVenta: borrador.precioVenta,
    );
    try {
      await stock.actualizarPrecios(
        productoId: id,
        precioCompra: borrador.precioCompra,
        precioVenta: borrador.precioVenta,
      );
    } on StockException catch (error) {
      return ResultadoAccion(
        guardo: false,
        mensaje:
            'El producto quedó cargado (id $id) con el precio de venta ${_precio(borrador.precioVenta)}. '
            'El precio de compra no se actualizó: ${error.mensaje} Podés confirmar de nuevo. La confirmación sigue visible.',
      );
    }
    return ResultadoAccion(
      guardo: true,
      mensaje: 'Agregué "${borrador.nombre.trim()}" (id $id).\n'
          'Precio de compra: ${_precio(borrador.precioCompra)}\n'
          'Precio de venta: ${_precio(borrador.precioVenta)}',
    );
  } on ArgumentError catch (error) {
    return ResultadoAccion(
      guardo: false,
      mensaje:
          'No lo guardé. ${error.message ?? error} La confirmación sigue visible.',
    );
  } on StockException catch (error) {
    return ResultadoAccion(
      guardo: false,
      mensaje: 'No lo guardé. ${error.mensaje} La confirmación sigue visible.',
    );
  } catch (error) {
    return ResultadoAccion(
      guardo: false,
      mensaje: 'No lo guardé. $error La confirmación sigue visible.',
    );
  }
}

Future<ResultadoAccion> _confirmarAjuste(
  AppDatabase database,
  BorradorAjusteStock borrador,
) async {
  try {
    await StockRepository(database).registrarAjuste(
      productoId: borrador.productoId,
      nombre: borrador.nombre,
      cantidad: borrador.cantidad,
      propietario: borrador.propietario,
      tipo: borrador.tipo,
      descripcion: 'Ajuste desde el asistente',
    );
    final movimiento =
        borrador.tipo == StockRepository.tipoEntrada ? 'Sumé' : 'Desconté';
    return ResultadoAccion(
      guardo: true,
      mensaje:
          '$movimiento ${borrador.cantidad} unidades de "${borrador.nombre}" '
          'para ${borrador.propietario}.',
    );
  } on StockException catch (error) {
    return ResultadoAccion(
      guardo: false,
      mensaje:
          'No ajusté el stock. ${error.mensaje} La confirmación sigue visible.',
    );
  } catch (error) {
    return ResultadoAccion(
      guardo: false,
      mensaje: 'No ajusté el stock. $error La confirmación sigue visible.',
    );
  }
}

Future<ResultadoAccion> _confirmarVenta(
  AppDatabase database,
  BorradorVenta borrador,
) async {
  if (borrador.lineas.isEmpty) {
    return const ResultadoAccion(
      guardo: false,
      mensaje: 'La venta no tiene productos. La confirmación sigue visible.',
    );
  }
  if (!_precioValido(borrador.montoSena)) {
    return const ResultadoAccion(
      guardo: false,
      mensaje: 'La seña no es válida. La confirmación sigue visible.',
    );
  }

  final repo = PedidoRepository(database);
  try {
    final clientes = await repo.listarClientes();
    final clienteResuelto = _resolverNombre(
      clientes.map((cliente) => cliente.nombre).toList(),
      borrador.cliente,
    );
    if (clienteResuelto.opciones.length > 1) {
      return ResultadoAccion(
        guardo: false,
        mensaje:
            'Hay más de un cliente para "${borrador.cliente}". No guardé la venta. La confirmación sigue visible.',
      );
    }
    final cliente = clienteResuelto.unico == null
        ? null
        : _clientePorNombre(clientes, clienteResuelto.unico!);
    if (clienteResuelto.unico != null && cliente == null) {
      return const ResultadoAccion(
        guardo: false,
        mensaje:
            'No guardé la venta. No pude ubicar el cliente en la base. La confirmación sigue visible.',
      );
    }

    final productos = await repo.listarProductos();
    final lineas = <LineaPedidoBorrador>[];
    final creados = <String>[];
    for (final linea in borrador.lineas) {
      if (linea.cantidad <= 0) {
        return const ResultadoAccion(
          guardo: false,
          mensaje:
              'Hay una cantidad que no es válida. La confirmación sigue visible.',
        );
      }
      final resolucion = _resolverNombre(
        productos.map((producto) => producto.nombre).toList(),
        linea.producto,
      );
      if (resolucion.opciones.length > 1) {
        return ResultadoAccion(
          guardo: false,
          mensaje:
              'Hay más de un producto para "${linea.producto}". No guardé la venta. La confirmación sigue visible.',
        );
      }
      if (resolucion.unico != null) {
        final existente = _buscarProducto(productos, resolucion.unico!);
        if (existente == null) {
          return ResultadoAccion(
            guardo: false,
            mensaje:
                'No encontré "${linea.producto}" para armar el pedido. La confirmación sigue visible.',
          );
        }
        lineas.add(
          LineaPedidoBorrador(
            productoId: existente.id,
            cantidad: linea.cantidad,
          ),
        );
        continue;
      }
      final precio = linea.precioVenta;
      if (precio == null || !_precioValido(precio)) {
        return ResultadoAccion(
          guardo: false,
          mensaje:
              '"${linea.producto}" no está cargado y falta el precio de venta para crearlo. La confirmación sigue visible.',
        );
      }
      lineas.add(
        LineaPedidoBorrador(
          nombreNuevo: linea.producto,
          precioVenta: precio,
          cantidad: linea.cantidad,
        ),
      );
      creados.add(
        '${linea.producto} queda con precio de venta ${_precio(precio)} y precio de compra 0, porque el alta del pedido solo recibe el precio de venta.',
      );
    }

    final id = await repo.crearPedido(
      clienteId: cliente?.id,
      clienteNombre: cliente == null ? borrador.cliente : null,
      montoSenado: borrador.montoSena,
      lineas: lineas,
    );
    final precios = <int, double>{};
    for (final linea in lineas) {
      final productoId = linea.productoId;
      final precio = linea.precioVenta;
      if (productoId != null && precio != null) precios[productoId] = precio;
    }
    await const AmpliacionLocal().marcarPedido(
      pedidoId: id,
      origen: 'asistente',
      precios: precios,
    );
    final detalle = lineas.map((linea) {
      if (linea.productoId != null) {
        final producto = _productoPorId(productos, linea.productoId!);
        final nombre = producto?.nombre ?? 'producto ${linea.productoId}';
        return '$nombre x${linea.cantidad}';
      }
      return '${linea.nombreNuevo} x${linea.cantidad}';
    }).join(', ');
    final extra = creados.isEmpty ? '' : '\n${creados.join('\n')}';
    return ResultadoAccion(
      guardo: true,
      mensaje:
          'Guardé el pedido #$id para ${cliente?.nombre ?? borrador.cliente}.\n'
          'Quedó pendiente. Seña: ${_precio(borrador.montoSena)}.\n'
          'Productos: $detalle.$extra',
    );
  } on ArgumentError catch (error) {
    return ResultadoAccion(
      guardo: false,
      mensaje:
          'No guardé la venta. ${error.message ?? error} La confirmación sigue visible.',
    );
  } on StateError catch (error) {
    return ResultadoAccion(
      guardo: false,
      mensaje:
          'No guardé la venta. ${error.message} La confirmación sigue visible.',
    );
  } catch (error) {
    return ResultadoAccion(
      guardo: false,
      mensaje: 'No guardé la venta. $error La confirmación sigue visible.',
    );
  }
}

String _formatearStock(List<ProductoConStock> lista, {required bool general}) {
  final buffer = StringBuffer(
    general ? 'Este es el stock cargado:' : 'Stock:',
  );
  final visibles = lista.take(40);
  for (final producto in visibles) {
    buffer
      ..writeln()
      ..write(
        '${producto.nombre}: total ${producto.stockTotal}. '
        'Yo ${producto.stockYo}. Nildo ${producto.stockNildo}.',
      );
    if (producto.stockOtros > 0) {
      buffer.write(' Otros ${producto.stockOtros}.');
    }
    buffer.write(
      ' Compra ${_precio(producto.precioCompra)}. Venta ${_precio(producto.precioVenta)}.',
    );
  }
  if (lista.length > 40) {
    buffer
      ..writeln()
      ..write('Mostré 40 de ${lista.length}.');
  }
  return buffer.toString();
}

bool _consultaApuntaA(String consulta, String nombre) {
  final claveNombre = _clave(nombre);
  if (claveNombre.isEmpty) return false;
  if (claveNombre.length < 3) return _sobraConsulta(consulta) == claveNombre;
  if (consulta.contains(claveNombre)) return true;
  final sobra = _sobraConsulta(consulta);
  if (sobra.isEmpty) return false;
  final singular = _singular(sobra);
  return claveNombre == sobra ||
      claveNombre == singular ||
      claveNombre.startsWith('$sobra ') ||
      claveNombre.startsWith('$singular ');
}

String _sobraConsulta(String consulta) {
  final limpio = consulta.replaceAll(
    RegExp(
      r'\b(stock|inventario|existencias|cuanto|cuanta|cuantos|cuantas|hay|queda|quedan|tengo|tenes|tenemos|de|del|la|el|los|las|un|una|en|por|favor|consultar|consulta|ver|mostrar|decime|decir|total|unidades|unidad|producto|productos|que|cual|cuales|me|mi|mis|para|porfa|gexi|asistente|hola)\b',
    ),
    ' ',
  );
  return limpio.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _singular(String texto) {
  if (texto.endsWith('s') && texto.length > 3) {
    return texto.substring(0, texto.length - 1);
  }
  return texto;
}

bool _esAltaProducto(String t) {
  final verbo = RegExp(
    r'\b(agregar|agrega|agregame|agregalo|agreguen|anadir|anadi|anadime|cargar|carga|cargame|cargalo|crear|crea|creame|crealo|alta|registrar)\b',
  ).hasMatch(t);
  final producto = RegExp(r'\b(producto|articulo|mercaderia)\b').hasMatch(t);
  final compra = RegExp(
    r'\b(precio de compra|precio de costo|precio costo|de compra|compra|costo)\b',
  ).hasMatch(t);
  final ventaPrecio = RegExp(r'\b(precio de venta|de venta)\b').hasMatch(t) ||
      (RegExp(r'\bventa\b').hasMatch(t) && compra);
  if (RegExp(r'\b(nuevo|nueva) producto\b').hasMatch(t)) return true;
  if (RegExp(r'\b(dar de alta|de alta)\b').hasMatch(t) && producto) return true;
  if (verbo && producto && !RegExp(r'\b(pedido|stock)\b').hasMatch(t)) {
    return true;
  }
  if (compra && ventaPrecio && RegExp(r'\d').hasMatch(t)) return true;
  if (verbo && producto && compra) return true;
  return false;
}

bool _esVenta(String t) {
  final limpio = _sinPrecioDeVenta(t);
  return RegExp(
    r'\b(venta|vender|vendi\w*|vende\w*|pedido|pedidos|encarg\w*|sena)\b',
  ).hasMatch(limpio);
}

bool _esConsultaStock(String t) {
  final mencionaStock =
      RegExp(r'\b(stock|inventario|existencias)\b').hasMatch(t);
  final preguntaCantidad = RegExp(
    r'\b(cuant[oa]s?\s+(hay|queda|quedan|tengo|tenes|tenemos)|que queda|que quedan)\b',
  ).hasMatch(t);
  if (!mencionaStock && !preguntaCantidad) return false;
  if (!mencionaStock &&
      RegExp(r'\b(capital|deuda|deudor|pago|plata|dinero|factura)\b')
          .hasMatch(t)) {
    return false;
  }
  return true;
}

bool _esMovimientoStock(String t) {
  final verbo = RegExp(
    r'\b(agrega\w*|suma\w*|sumar|desconta\w*|resta\w*|saca\w*|sacar|ajuste|entrada|salida)\b',
  ).hasMatch(t);
  final destino = RegExp(r'\b(stock|unidades)\b').hasMatch(t);
  return verbo && destino && !_esAltaProducto(t);
}

String _sinPrecioDeVenta(String t) {
  return t.replaceAll(RegExp(r'precio de venta'), ' ');
}

class _Resolucion {
  const _Resolucion.unico(this.unico) : opciones = const [];
  const _Resolucion.ninguno()
      : unico = null,
        opciones = const [];
  const _Resolucion.varios(this.opciones) : unico = null;

  final String? unico;
  final List<String> opciones;
}

_Resolucion _resolverNombre(List<String> nombres, String consulta) {
  final clave = _clave(consulta);
  if (clave.isEmpty) return const _Resolucion.ninguno();

  final exactos = _unicos(
    nombres.where((nombre) => _clave(nombre) == clave).toList(),
  );
  if (exactos.length == 1) return _Resolucion.unico(exactos.first);
  if (exactos.length > 1) return _Resolucion.varios(exactos);

  final parecidos = _unicos(
    nombres.where((nombre) => _clave(nombre).startsWith('$clave ')).toList(),
  );
  if (parecidos.length == 1) return _Resolucion.unico(parecidos.first);
  if (parecidos.length > 1) return _Resolucion.varios(parecidos);
  return const _Resolucion.ninguno();
}

List<String> _unicos(List<String> nombres) {
  final vistos = <String>{};
  final salida = <String>[];
  for (final nombre in nombres) {
    final clave = _clave(nombre);
    if (clave.isEmpty || !vistos.add(clave)) continue;
    salida.add(nombre);
  }
  return salida;
}

ProductoPedidoOpcion? _buscarProducto(
    List<ProductoPedidoOpcion> productos, String nombre) {
  final clave = _clave(nombre);
  for (final producto in productos) {
    if (_clave(producto.nombre) == clave) return producto;
  }
  return null;
}

ClientePedido? _clientePorNombre(List<ClientePedido> clientes, String nombre) {
  final clave = _clave(nombre);
  for (final cliente in clientes) {
    if (_clave(cliente.nombre) == clave) return cliente;
  }
  return null;
}

ProductoPedidoOpcion? _productoPorId(
    List<ProductoPedidoOpcion> productos, int id) {
  for (final producto in productos) {
    if (producto.id == id) return producto;
  }
  return null;
}

Map<String, dynamic>? _extraerJson(String raw) {
  final limpio = raw.trim();
  final directo = _decodificarMapa(limpio);
  if (directo != null) return directo;
  final inicio = limpio.indexOf('{');
  final fin = limpio.lastIndexOf('}');
  if (inicio < 0 || fin <= inicio) return null;
  return _decodificarMapa(limpio.substring(inicio, fin + 1));
}

Map<String, dynamic>? _decodificarMapa(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
  return null;
}

List<dynamic> _lista(dynamic raw) {
  if (raw is List) return raw;
  if (raw is Map) return [raw];
  return const [];
}

String _texto(dynamic raw) {
  if (raw == null) return '';
  return raw.toString().trim();
}

String _propietario(dynamic raw) {
  final clave = _clave(_texto(raw));
  if (clave == 'nildo') return StockRepository.propietarioNildo;
  return StockRepository.propietarioYo;
}

String? _tipoMovimiento(dynamic raw) {
  final clave = _clave(_texto(raw));
  if (RegExp(r'\b(entrada|sumar|suma|agregar|agrega|ingreso)\b')
      .hasMatch(clave)) {
    return StockRepository.tipoEntrada;
  }
  if (RegExp(r'\b(salida|restar|resta|descontar|desconta|sacar|saca)\b')
      .hasMatch(clave)) {
    return StockRepository.tipoSalida;
  }
  return null;
}

double? _leerPrecio(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) {
    final valor = raw.toDouble();
    if (valor.isNaN || valor.isInfinite) return null;
    return valor;
  }
  if (raw is! String) return null;
  return _parsePrecio(raw);
}

int? _leerCantidad(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) {
    if (raw.isNaN || raw.isInfinite) return null;
    if (raw == raw.roundToDouble()) return raw.toInt();
    return null;
  }
  if (raw is! String) return null;
  final precio = _parsePrecio(raw);
  if (precio == null) return null;
  if (precio == precio.roundToDouble()) return precio.toInt();
  return null;
}

bool _precioValido(double valor) {
  return !valor.isNaN && !valor.isInfinite && valor >= 0;
}

double? _parsePrecio(String raw) {
  var texto = raw.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (texto.isEmpty || texto == '-' || texto == ',' || texto == '.') {
    return null;
  }
  final negativo = texto.startsWith('-');
  texto = texto.replaceAll('-', '');
  if (texto.contains(',') && texto.contains('.')) {
    if (texto.lastIndexOf(',') > texto.lastIndexOf('.')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    } else {
      texto = texto.replaceAll(',', '');
    }
  } else if (texto.contains(',')) {
    texto = texto.replaceAll(',', '.');
  }
  final valor = double.tryParse(texto);
  if (valor == null) return null;
  return negativo ? -valor : valor;
}

String _precio(double valor) {
  final texto = valor.toStringAsFixed(2).replaceAll('.', ',');
  return '\$ $texto';
}

String _clave(String texto) {
  const origen = 'áéíóúüñ';
  const destino = 'aeiouun';
  var salida = texto.toLowerCase();
  for (var i = 0; i < origen.length; i++) {
    salida = salida.replaceAll(origen[i], destino[i]);
  }
  return salida;
}
