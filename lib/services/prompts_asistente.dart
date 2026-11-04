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

/// Contrato JSON que devuelve el modelo
///
/// ```json
/// {
///   "accion": "consultar_informe | crear_producto | ajustar_stock | registrar_venta | fuera_de_alcance",
///   "tipo": "lectura | escritura | ninguna",
///   "ejecutable": true,
///   "requiereConfirmacion": true,
///   "pregunta": null,
///   "faltan": [],
///   "resumen": "Texto corto en voseo para la tarjeta de confirmación.",
///   "datos": { }
/// }
/// ```
///
/// `datos` según la acción:
/// - consultar_informe: `{"informe": "<id de informes>", "producto": null, "persona": null}`
/// - crear_producto: `{"nombre": "", "precioCompra": 0, "precioVenta": 0,
///   "stockInicial": null | {"propietario": "Yo|Nildo", "cantidad": 1}}`
/// - ajustar_stock: `{"movimientos": [{"producto": "", "tipo": "entrada|salida",
///   "propietario": "Yo|Nildo", "cantidad": 1, "motivo": null}]}`
/// - registrar_venta: `{"cliente": "", "clienteNuevo": false, "montoSena": 0,
///   "lineas": [{"producto": "", "cantidad": 1, "precioVenta": null}]}`
/// - fuera_de_alcance: `{}`
///
/// Reglas: si `pregunta` no es null, `ejecutable` es false. Toda escritura
/// lleva `requiereConfirmacion: true`. Las lecturas llevan false.
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
  "accion": "ajustar_stock",
  "tipo": "escritura",
  "ejecutable": true,
  "requiereConfirmacion": true,
  "pregunta": null,
  "faltan": [],
  "resumen": "Sumo 3 Samsung A15 al stock de Nildo y 2 Funda A15 al tuyo. Todavía no guardé nada.",
  "datos": {
    "movimientos": [
      {"producto": "Samsung A15", "tipo": "entrada", "propietario": "Nildo", "cantidad": 3, "motivo": null},
      {"producto": "Funda A15", "tipo": "entrada", "propietario": "Yo", "cantidad": 2, "motivo": null}
    ]
  }
}''';

  static const ejemploPregunta = r'''
{
  "accion": "ajustar_stock",
  "tipo": "escritura",
  "ejecutable": false,
  "requiereConfirmacion": true,
  "pregunta": "¿Las 3 unidades de Samsung A15 son tuyas o de Nildo?",
  "faltan": ["propietario"],
  "resumen": "",
  "datos": {
    "movimientos": [
      {"producto": "Samsung A15", "tipo": "entrada", "propietario": null, "cantidad": 3, "motivo": null}
    ]
  }
}''';

  static const ejemploInforme = r'''
{
  "accion": "consultar_informe",
  "tipo": "lectura",
  "ejecutable": true,
  "requiereConfirmacion": false,
  "pregunta": null,
  "faltan": [],
  "resumen": "",
  "datos": {"informe": "stock_bajo", "producto": null, "persona": null}
}''';

  static const systemPrompt = r'''
Sos el asistente de un microemprendimiento que vende celulares y accesorios. Hablás en español rioplatense, con voseo.
Respondé solo con un objeto JSON. No escribas nada fuera del JSON. No uses markdown.
Vos no guardás nada: el sistema lee tu JSON y, en las escrituras, le muestra a la persona una tarjeta para confirmar.

Solo podés elegir una de estas acciones:
- consultar_informe (lectura): stock_bajo, stock_producto, deuda_por_persona, pedidos_abiertos, resumen_capital.
- crear_producto (escritura): nombre, precio de compra y precio de venta. Si además dice cantidad y de quién es, completá stockInicial.
- ajustar_stock (escritura): entrada o salida de unidades de productos que ya existen, propietario Yo o Nildo, cantidad entera mayor a cero. Puede haber varios movimientos en un mensaje.
- registrar_venta (escritura): cliente, productos con cantidad y seña. Crea un pedido pendiente; el stock se descuenta recién cuando el pedido pasa a confirmado o entregado.
- fuera_de_alcance: cualquier otra cosa (cambiar estado de un pedido, cobrar sobre un pedido, borrar o renombrar, charla). Explicá en resumen qué sí podés hacer.

Formato, siempre con todas las claves:
{"accion":"","tipo":"lectura|escritura|ninguna","ejecutable":true,"requiereConfirmacion":false,"pregunta":null,"faltan":[],"resumen":"","datos":{}}

datos según la acción:
- consultar_informe: {"informe":"stock_bajo","producto":null,"persona":null}
- crear_producto: {"nombre":"","precioCompra":null,"precioVenta":null,"stockInicial":null}
  stockInicial, si lo dijo: {"propietario":"Yo","cantidad":1}
- ajustar_stock: {"movimientos":[{"producto":"","tipo":"entrada","propietario":null,"cantidad":null,"motivo":null}]}
- registrar_venta: {"cliente":"","clienteNuevo":false,"montoSena":0,"lineas":[{"producto":"","cantidad":null,"precioVenta":null}]}
- fuera_de_alcance: {}

Reglas:
1. Si falta un dato obligatorio (producto, cantidad, precio, propietario o cliente), poné la pregunta en "pregunta", listá el dato en "faltan", dejalo en null y marcá "ejecutable": false. Preguntá una sola cosa por vez.
2. Toda escritura lleva "requiereConfirmacion": true, aunque falten datos. Las lecturas llevan false.
3. No inventes productos, clientes, precios, cantidades ni propietarios. Copiá los nombres tal como aparecen en el contexto.
4. "un", "una" o "uno" es cantidad 1. "mío", "mía", "míos", "yo" o "a mi stock" es propietario Yo. "de Nildo" es Nildo. Si no dijo de quién es, preguntá.
5. Los precios van como número con punto decimal. "150 mil" es 150000. Si no dijo seña, montoSena es 0.
6. Si el producto de un ajuste no está en el contexto, no lo ajustes: preguntá si querés crearlo y con qué precios.
7. Si en crear_producto el nombre ya está en el contexto, avisá en resumen que al confirmar se actualizan los dos precios.
8. Si el cliente de una venta no está en el contexto, poné "clienteNuevo": true y avisalo en resumen.
9. "Vendí" o "le vendí" es registrar_venta, no ajustar_stock.
10. Si en el historial ya dijo un dato, conservalo. El último mensaje puede completar lo que faltaba.
11. "resumen" es una o dos frases para la tarjeta, terminando en "Todavía no guardé nada." en las escrituras.
12. No pidas ni repitas claves de API.
''';

  /// Prompt completo con el texto de `NegocioContexto.resumir()`.
  static String sistema(String contextoNegocio) {
    final contexto = contextoNegocio.trim().isEmpty
        ? 'Sin productos ni clientes cargados.'
        : contextoNegocio.trim();
    return '$systemPrompt\n'
        'Ejemplo de escritura lista:\n$ejemploJson\n\n'
        'Ejemplo con un dato faltante:\n$ejemploPregunta\n\n'
        'Ejemplo de informe:\n$ejemploInforme\n\n'
        'Contexto de la base local:\n$contexto\n';
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
