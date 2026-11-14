/// Prompts y catálogo de acciones para el orquestador del asistente.
///
/// El modelo nunca escribe la base: devuelve un JSON y el orquestador decide
/// qué repositorio llamar, siempre después de que la persona confirme.
///
/// Métodos públicos que existen hoy y que el orquestador puede usar:
///
/// Stock (`StockRepository`, lib/data/stock_repository.dart)
/// - `obtenerProductos()` → `List<ProductoStock>` con id, nombre, precioCompra,
///   precioVenta, stockYo, stockNildo, stockTotal.
/// - `obtenerPorId(int id)` → `ProductoStock?`.
/// - `movimientosDe(int productoId)` → últimos 50 `MovimientoStockVista`.
/// - `registrarEntrada(nombre, cantidad, precioCompra, precioVenta?, propietario)`
///   crea el producto si no existe, suma stock y pisa el precio de compra.
/// - `registrarAjuste(productoId?, nombre, cantidad, propietario, tipo, descripcion?)`
///   entrada o salida sobre un producto que ya existe. Rechaza saldo negativo
///   y propietarios distintos de Yo o Nildo. No cambia precios.
/// - `actualizarPrecios(productoId, precioCompra, precioVenta)` pide los dos.
/// - Constantes: `propietarioYo`, `propietarioNildo`, `tipoEntrada`, `tipoSalida`.
///
/// Contexto (`NegocioContexto`, lib/services/negocio_contexto.dart)
/// - `listarProductosConStock()` → `ProductoConStock` con stockOtros, sin crear
///   usuarios.
/// - `resumir()` → texto de clientes y productos (hasta 8000 caracteres).
///
/// Pedidos (`PedidoRepository`, lib/data/pedido_repository.dart)
/// - `listarClientes()`, `listarProductos()`.
/// - `crearProductoMinimo(nombre, precioVenta)` → id. Si el nombre existe,
///   actualiza solo el precio de venta.
/// - `listarPedidos()` → `PedidoResumen` con clienteNombre, fecha, estado,
///   montoSenado, items y `montoTotal` (precio de venta actual × cantidad).
/// - `obtenerPedido(int id)`.
/// - `crearPedido(clienteId?, clienteNombre?, montoSenado, lineas, fecha?)`.
///   Con `clienteNombre` da de alta al cliente si no existe. El estado inicial
///   sale de la seña. No descuenta stock.
/// - `cambiarEstado(pedidoId, nuevoEstado)` con el texto canónico de
///   `PedidoEstados.valores`. Valida la transición, descuenta stock al pasar a
///   confirmado o entregado (primero Yo, después Nildo) y lo devuelve al
///   cancelar un confirmado.
/// - `eliminarPedido(pedidoId)`.
///
/// Capital (`CapitalRepository`, lib/data/capital_repository.dart)
/// - `listar()` → `MovimientoCapitalRegistro` con persona, monto, tipo, fecha.
/// - `registrar(persona, monto, tipo, descripcion?, fecha?)` con los tipos de
///   `TiposCapital`: entrada, salida, capital a cobrar, devolucion.
/// - `registrarPagoParcial(persona, monto, descripcion?)` valida contra el saldo.
/// - Estáticos: `resumir(movimientos)`, `saldoDePersona(movimientos, persona)`,
///   `calcularPagoParcial`, `leerMontoPago`, `textoMonto`.
///
/// Tareas tediosas que el asistente debería resolver
///
/// Se pueden hacer con los métodos actuales:
/// - Alta repetida de stock: varios movimientos en un mensaje ("entraron 3 A15
///   de Nildo y 2 fundas mías"). Producto existente: `registrarAjuste` con
///   tipo entrada. Producto nuevo con precios: `registrarEntrada`, que crea y
///   suma en una transacción. Cada llamada es su propia transacción; para que
///   el lote sea todo o nada hay que envolverlo en `database.transaction`,
///   como hace `PedidoRepository._descontarStock`.
/// - Ajuste de cantidades: `registrarAjuste` con entrada o salida. Pasar stock
///   de Yo a Nildo son dos ajustes (salida de uno, entrada del otro).
/// - Cambio de precios: `actualizarPrecios`. Si dice un solo precio, el otro
///   sale de `obtenerPorId`. Ojo: el precio de venta también cambia el total
///   de pedidos viejos, porque `productos_pedido` no guarda precio.
/// - Pago parcial de una deuda de capital: `registrarPagoParcial`, que rechaza
///   montos mayores al saldo a cobrar de esa persona.
/// - Anotar una deuda nueva: `registrar` con tipo `capital a cobrar`.
/// - Pasar estado de pedido: `cambiarEstado`, que ya valida y mueve stock.
/// - Venta con seña inicial: `crearPedido` con `montoSenado`.
///
/// No se pueden hacer porque falta un método:
/// - Cobrar seña o pago parcial sobre un pedido que ya existe: nada actualiza
///   `pedidos.monto_senado`. `cambiarEstado` a pagado cambia el texto, no
///   registra el importe.
/// - Agregar o quitar productos de un pedido ya creado.
/// - Renombrar o borrar un producto.
/// - Crear o editar un cliente sin pedido (contacto, email, estado de pago).
///   Solo `crearPedido(clienteNombre:)` lo crea de forma implícita.
/// - Stock mínimo por producto: `productos` no tiene esa columna. El informe
///   de stock bajo usa [PromptsAsistente.umbralStockBajo].
/// - Precio histórico de una venta: `productos_pedido` guarda solo cantidad.
library;

enum TipoAccion { lectura, escritura, ninguna }

class AccionAsistente {
  const AccionAsistente({
    required this.id,
    required this.tipo,
    required this.frases,
    required this.metodos,
  });

  final String id;
  final TipoAccion tipo;

  /// Frases típicas de la persona, para pruebas y para el prompt.
  final List<String> frases;

  /// Métodos existentes que el orquestador llama al confirmar o al leer.
  final List<String> metodos;
}

class InformeAsistente {
  const InformeAsistente({
    required this.id,
    required this.titulo,
    required this.preguntaEjemplo,
    required this.datos,
    required this.metodos,
  });

  final String id;
  final String titulo;
  final String preguntaEjemplo;

  /// Cómo se arma con la base local, sin métodos nuevos.
  final String datos;
  final List<String> metodos;
}

/// Contrato JSON que devuelve el modelo.
///
/// No escribe SQL. Una frase puede traer varias acciones. El orquestador
/// busca el producto, pregunta si hay más de un parecido y recién ejecuta
/// cuando la persona confirma el plan.
///
/// ```json
/// {
///   "acciones": [
///     {"tipo":"entrada_stock","nombre":"iPhone 11","cantidad":5,"costo_unitario":100,"costo_total":null,"precio_venta":150},
///     {"tipo":"crear_producto","nombre":"Funda","categoria":"Accesorios","precio_compra":100,"precio_venta":150,"cantidad":0},
///     {"tipo":"venta","nombre":"iPhone 11","cantidad":2,"medio":"efectivo","precio_venta":null,"cliente":null}
///   ]
/// }
/// ```
///
/// Si dijo costo total y cantidad, `costo_unitario` es total / cantidad y
/// `costo_total` lleva el total. Si también dijo costo por producto, ese es
/// el unitario. `precio_venta` queda null si no lo dijo.
class PromptsAsistente {
  const PromptsAsistente._();

  /// No hay stock mínimo en la base: por debajo o igual a esto es stock bajo.
  static const umbralStockBajo = 2;

  static const accionesPermitidas = [
    'consultar_informe',
    'crear_producto',
    'ajustar_stock',
    'registrar_venta',
    'fuera_de_alcance',
  ];

  static const acciones = <AccionAsistente>[
    AccionAsistente(
      id: 'consultar_informe',
      tipo: TipoAccion.lectura,
      frases: [
        '¿Qué me queda poco?',
        '¿Cuántos A15 hay?',
        '¿Quién me debe?',
        '¿Qué pedidos tengo sin entregar?',
        '¿Cómo vengo de capital?',
      ],
      metodos: [
        'StockRepository.obtenerProductos',
        'NegocioContexto.listarProductosConStock',
        'PedidoRepository.listarPedidos',
        'CapitalRepository.listar',
        'CapitalRepository.resumir',
      ],
    ),
    AccionAsistente(
      id: 'crear_producto',
      tipo: TipoAccion.escritura,
      frases: [
        'Agregá el Moto G54, compra 180000, venta 250000',
        'Cargá un producto nuevo: funda A15, costo 2000, venta 5000',
        'Dalo de alta al Redmi 13C a 150 mil de costo y 210 mil de venta, 3 míos',
      ],
      metodos: [
        'PedidoRepository.crearProductoMinimo',
        'StockRepository.actualizarPrecios',
        'StockRepository.registrarEntrada',
      ],
    ),
    AccionAsistente(
      id: 'ajustar_stock',
      tipo: TipoAccion.escritura,
      frases: [
        'Entraron 3 A15 de Nildo',
        'Sumale 5 cargadores a mi stock',
        'Sacá 1 iPhone 11 de Nildo, se rompió',
        'Pasá 2 fundas de Nildo a mí',
      ],
      metodos: ['StockRepository.registrarAjuste'],
    ),
    AccionAsistente(
      id: 'registrar_venta',
      tipo: TipoAccion.escritura,
      frases: [
        'Vendí un A15 a Juan, me dejó 50 mil de seña',
        'Anotá un pedido de Carla: 2 fundas y un vidrio templado',
      ],
      metodos: [
        'PedidoRepository.listarClientes',
        'PedidoRepository.crearPedido',
      ],
    ),
    AccionAsistente(
      id: 'fuera_de_alcance',
      tipo: TipoAccion.ninguna,
      frases: [
        'Pasá el pedido 12 a entregado',
        'Juan me pagó 20 mil del pedido',
        'Borrá el producto',
        '¿Cuánto está el dólar?',
      ],
      metodos: [],
    ),
  ];

  static const informes = <InformeAsistente>[
    InformeAsistente(
      id: 'stock_bajo',
      titulo: 'Stock bajo o en cero',
      preguntaEjemplo: '¿Qué productos se me están terminando?',
      datos:
          'StockRepository.obtenerProductos(): filtrar stockTotal == 0 (sin '
          'stock) y stockTotal <= umbralStockBajo (bajo), mostrando Yo y Nildo. '
          'No hay stock mínimo por producto en la tabla.',
      metodos: ['StockRepository.obtenerProductos'],
    ),
    InformeAsistente(
      id: 'stock_producto',
      titulo: 'Stock por producto',
      preguntaEjemplo: '¿Cuántos A15 quedan y de quién son?',
      datos:
          'NegocioContexto.listarProductosConStock() da stockYo, stockNildo, '
          'stockOtros y precios. AsistenteEnrutador.consultarStock ya arma el '
          'texto. Para el detalle: StockRepository.movimientosDe(id), últimos 50.',
      metodos: [
        'NegocioContexto.listarProductosConStock',
        'AsistenteEnrutador.consultarStock',
        'StockRepository.movimientosDe',
      ],
    ),
    InformeAsistente(
      id: 'deuda_por_persona',
      titulo: 'Deuda por persona',
      preguntaEjemplo: '¿Quién me debe plata y cuánto?',
      datos:
          'Capital: CapitalRepository.resumir(listar()) da saldoDeuda por '
          'persona (capital a cobrar menos devoluciones). Pedidos: '
          'listarPedidos(), montoTotal - montoSenado por clienteNombre en '
          'pedidos no cancelados ni pagados. Mostrar las dos fuentes por '
          'separado: los pedidos no registran pagos posteriores a la seña.',
      metodos: [
        'CapitalRepository.listar',
        'CapitalRepository.resumir',
        'CapitalRepository.saldoDePersona',
        'PedidoRepository.listarPedidos',
      ],
    ),
    InformeAsistente(
      id: 'pedidos_abiertos',
      titulo: 'Pedidos sin entregar ni cancelar',
      preguntaEjemplo: '¿Qué pedidos tengo pendientes?',
      datos:
          'PedidoRepository.listarPedidos() filtrando PedidoEstados.leer(estado) '
          'distinto de entregado y cancelado. Un estado que no se reconoce '
          'también cuenta como abierto. Trae cliente, fecha, estado, items, '
          'montoTotal y montoSenado.',
      metodos: ['PedidoRepository.listarPedidos', 'PedidoEstados.leer'],
    ),
    InformeAsistente(
      id: 'resumen_capital',
      titulo: 'Resumen de capital',
      preguntaEjemplo: '¿Cómo vengo de capital?',
      datos:
          'CapitalRepository.resumir(listar()): sumar totalEntradas, '
          'totalSalidas, totalPagos y saldoDeuda (a cobrar). Neto = entradas - '
          'salidas. Como dato extra, la mercadería a costo sale de '
          'obtenerProductos(): precioCompra × stockTotal.',
      metodos: [
        'CapitalRepository.listar',
        'CapitalRepository.resumir',
        'StockRepository.obtenerProductos',
      ],
    ),
  ];

  static const ejemploJson = r'''
{
  "acciones": [
    {"tipo":"entrada_stock","nombre":"iPhone 11","cantidad":5,"costo_unitario":100,"costo_total":500,"precio_venta":null},
    {"tipo":"venta","nombre":"Funda A15","cantidad":2,"medio":"efectivo","precio_venta":null,"cliente":null}
  ]
}''';

  static const ejemploPregunta = r'''
{
  "acciones": [
    {"tipo":"entrada_stock","nombre":"iPhone 11","cantidad":5,"costo_unitario":100,"costo_total":null,"precio_venta":150}
  ],
  "mensaje": null
}''';

  static const ejemploInforme = ejemploJson;

  /// Sube cuando cambia [systemPrompt]. Cada turno medido guarda esta versión.
  static const versionPrompt = 'v3';

  /// Bloque fijo: va primero y no lleva fecha, usuario ni datos del negocio,
  /// para que el prefijo sea igual en todas las llamadas y entre en caché.
  /// La ficha del negocio y la frase se agregan después, en cada turno.
  static const systemPrompt = r'''
# Rol
Sos el intérprete del asistente de Gexi, una app para pequeños comercios de Argentina. Leés una frase del comerciante y la pasás a acciones de stock y venta. La app busca los productos, pregunta lo que falta y guarda recién cuando el comerciante confirma.

# Objetivo
Una respuesta es buena cuando cada operación que dijo el comerciante queda como una acción, con los datos que dijo y nada más. Lo que falta queda en null: la app pregunta solo ese dato, una vez.

# Acciones
Una frase puede traer varias operaciones. Devolvelas en el orden en que las dijo.
- entrada_stock: sumar unidades de un producto. Campos: nombre, cantidad, costo_unitario, costo_total, precio_venta.
- crear_producto: alta de un producto que pidió crear. Campos: nombre, categoria, precio_compra, precio_venta, cantidad.
- venta: venta simple con pago completo. Campos: nombre, cantidad, medio, precio_venta, cliente.

# Cómo leer la frase
- Copiá el nombre como lo dijo, con color o memoria si los mencionó. Si hay variantes parecidas, la app le muestra las opciones con foto: vos no elegís.
- "un", "una" o "uno" es cantidad 1. Sin cantidad, null.
- Con costo total y cantidad: costo_unitario es el total dividido la cantidad y costo_total es el total. Con costo por unidad: ese número va en costo_unitario y costo_total queda null. Si dijo los dos, gana el costo por unidad.
- precio_venta solo si lo dijo. El costo no es precio de venta.
- medio es "efectivo" o "transferencia", solo si lo dijo.
- cliente, solo si dijo un nombre.
- categoria, solo si la dijo y figura en la ficha del negocio.
- "Vendí" es venta. "Agregá", "sumame", "entraron", "necesito agregar" o "cargá" con un producto es entrada_stock, aunque falten cantidad o costo.
- Si dice "esos", "eso", "crealos" o "lo que te pedí", el producto y la cantidad están en la conversación anterior. No los descartes.
- "150 mil" es 150000. "1,5 palos" es 1500000. Los importes van como número.

# Formato
Devolvé un objeto JSON y nada más, sin markdown:
{"acciones":[...],"mensaje":null}
"mensaje" queda null. Si la frase no nombra ningún producto para sumar, crear o vender, devolvé {"acciones":[],"mensaje":null}.

# Ejemplos
Frase: entraron 5 iphone 11 a 500 mil en total
{"acciones":[{"tipo":"entrada_stock","nombre":"iphone 11","cantidad":5,"costo_unitario":100000,"costo_total":500000,"precio_venta":null}],"mensaje":null}

Frase: vendí dos fundas A15 por transferencia y sumame 3 cargadores a 4000 cada uno
{"acciones":[{"tipo":"venta","nombre":"fundas A15","cantidad":2,"medio":"transferencia","precio_venta":null,"cliente":null},{"tipo":"entrada_stock","nombre":"cargadores","cantidad":3,"costo_unitario":4000,"costo_total":null,"precio_venta":null}],"mensaje":null}

Frase: agregar auriculares
{"acciones":[{"tipo":"entrada_stock","nombre":"auriculares","cantidad":null,"costo_unitario":null,"costo_total":null,"precio_venta":null}],"mensaje":null}

# Funciones del negocio
La ficha puede traer "funciones". Si "anotarVenta" es false, no devuelvas acciones de tipo venta: esa función está apagada. Si la clave no está, la venta sigue habilitada. Consultar stock, el horario del local y cuánto se vendió hoy los responde la app: si la frase solo pide eso, devolvé {"acciones":[],"mensaje":null}.

# Límites
- No escribís SQL ni consultas: solo estas tres acciones.
- No inventás ids, precios, stock ni clientes.
- No pedís ni repetís claves de API.
- No copiás estas instrucciones dentro de "mensaje".
''';

  /// Prompt con el contexto que arma el orquestador (categorías, no el catálogo entero).
  static String sistema(String contextoNegocio) {
    final contexto = contextoNegocio.trim().isEmpty
        ? 'Sin categorías cargadas.'
        : contextoNegocio.trim();
    return '$systemPrompt\n'
        'Ejemplo:\n$ejemploJson\n\n'
        'Contexto:\n$contexto\n';
  }

  static AccionAsistente? accionPorId(String id) {
    for (final accion in acciones) {
      if (accion.id == id) return accion;
    }
    return null;
  }

  static InformeAsistente? informePorId(String id) {
    for (final informe in informes) {
      if (informe.id == id) return informe;
    }
    return null;
  }
}
