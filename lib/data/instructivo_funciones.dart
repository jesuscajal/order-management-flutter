/// Guía de cada función de Gexi. La versión local acompaña a la app.
///
/// Si una función cambia, subí [version], actualizá esta lista y volvé a
/// escribir las filas de `instructivo_funciones`. El asistente usa la copia
/// más nueva entre el teléfono y la base.
class GuiaFuncion {
  const GuiaFuncion({
    required this.clave,
    required this.titulo,
    required this.texto,
    required this.palabras,
    this.interruptor = '',
  });

  final String clave;
  final String titulo;
  final String texto;
  final List<String> palabras;

  /// Si esta función del asistente está apagada, se avisa al final.
  final String interruptor;

  factory GuiaFuncion.desde(Map<String, dynamic> fila) {
    final palabras = fila['palabras'];
    return GuiaFuncion(
      clave: fila['clave'] as String? ?? '',
      titulo: fila['titulo'] as String? ?? '',
      texto: fila['texto'] as String? ?? '',
      palabras: [
        for (final palabra in palabras is List ? palabras : const <Object?>[])
          if (palabra is String && palabra.trim().isNotEmpty) palabra.trim(),
      ],
      interruptor: fila['interruptor'] as String? ?? '',
    );
  }
}

const instructivoVersion = 6;

const instructivoLocal = <GuiaFuncion>[
  GuiaFuncion(
    clave: 'inicio',
    titulo: 'Inicio',
    palabras: ['inicio', 'resumen', 'visitantes', 'pagina'],
    texto:
        'El inicio muestra el logo y el resumen: ventas de hoy, ventas del mes, visitantes de la página y pedidos que salieron de la página. Tocá el resumen para abrir Ventas. Debajo están los accesos a cada parte.',
  ),
  GuiaFuncion(
    clave: 'pedidos',
    titulo: 'Pedidos',
    palabras: ['pedido', 'pedidos', 'nuevo pedido', 'venta directa'],
    texto:
        'En Pedidos ves los encargos y su estado. El botón verde Nuevo pedido carga uno a mano. El botón chico de la caja registra una venta directa. Un pedido de la página llega solo y descuenta el stock.',
  ),
  GuiaFuncion(
    clave: 'stock',
    titulo: 'Stock',
    interruptor: 'consultarStock',
    palabras: ['stock', 'producto', 'productos', 'anadir stock', 'agregar stock', 'foto'],
    texto:
        'En Stock buscás un producto por nombre. Cada fila muestra el precio de venta y la cantidad. Si está en rojo, está bajo. Añadir stock, el botón azul, carga uno nuevo y te muestra las categorías que ya existen, o te deja crear una. Tocá el producto para cambiar nombre, precios o anotar una entrada o una salida. La cámara de la fila agrega hasta 4 fotos.',
  ),
  GuiaFuncion(
    clave: 'clientes',
    titulo: 'Clientes',
    palabras: ['cliente', 'clientes', 'contacto', 'whatsapp'],
    texto:
        'En Clientes buscás por nombre, teléfono o mail. Los filtros son Todos, Activos, Potenciales y Deben. Cada fila muestra el contacto y, si debe, el saldo a cobrar. Tocá la persona para escribirle por WhatsApp, llamarla, editarla, cambiar el estado de pago o eliminarla. Añadir cliente, el botón azul, carga una ficha nueva. Si tiene pedidos, no se puede borrar.',
  ),
  GuiaFuncion(
    clave: 'ventas',
    titulo: 'Ventas',
    interruptor: 'ventasHoy',
    palabras: ['venta', 'ventas', 'cuanto vendi', 'ganancia'],
    texto:
        'Ventas resume hoy, los últimos 7 días y el mes, con la ganancia si los productos tienen precio de compra. Abajo están los más vendidos y las últimas ventas. El filtro de arriba achica la lista por estado, medio u origen.',
  ),
  GuiaFuncion(
    clave: 'cierre',
    titulo: 'Cierre de caja',
    palabras: ['cierre', 'caja', 'efectivo', 'arqueo'],
    texto:
        'Cierre de caja muestra lo que entró y salió hoy, y el efectivo por separado. Contás el efectivo y la app lo compara con las entradas en efectivo. Las salidas no se restan. Anotar diferencia deja el registro; no borra movimientos.',
  ),
  GuiaFuncion(
    clave: 'compra',
    titulo: 'Compra',
    palabras: ['compra', 'proveedor', 'mercaderia'],
    texto:
        'Para reponer mercadería usá Añadir stock. No hace falta anotar un proveedor: el stock entra directo al local.',
  ),
  GuiaFuncion(
    clave: 'capital',
    titulo: 'Capital',
    palabras: ['capital', 'socio', 'aporte'],
    texto:
        'Capital anota entradas y salidas de cada persona. El saldo de cada una es lo que entró menos lo que salió. Está en Más.',
  ),
  GuiaFuncion(
    clave: 'deudores',
    titulo: 'Deudores',
    palabras: ['deuda', 'deudas', 'deudor', 'deudores', 'fiado', 'debe', 'cobro'],
    texto:
        'En Deudores ves a quién le vendiste fiado. Arriba está lo que te deben en total, cuántas personas y cuántas están vencidas. Podés buscar por nombre y filtrar Todos o Vencidos. Tocá la persona para anotar un pago parcial, el día de cobro, el teléfono o avisarle por WhatsApp.',
  ),
  GuiaFuncion(
    clave: 'categorias',
    titulo: 'Categorías',
    palabras: ['categoria', 'categorias', 'catalogo'],
    texto:
        'Categorías ordena el catálogo de la página. El cliente ve los productos agrupados en ese orden. Para borrar una, la app pregunta si estás seguro. Si todavía tiene productos, no se puede eliminar.',
  ),
  GuiaFuncion(
    clave: 'pagina',
    titulo: 'Tu página web',
    interruptor: 'horarioDireccion',
    palabras: ['pagina', 'tienda web', 'direccion', 'horario', 'logo', 'slug', 'maps'],
    texto:
        'Tu página web publica el catálogo en gexi.com.ar y tu dirección. Ahí cargás el nombre, el mensaje, el logo, el alias de cobro, el horario y la calle con numeración. Si hay coordenadas, Cómo llegar abre Google Maps en ese punto. Los interruptores del asistente también están en esa pantalla.',
  ),
  GuiaFuncion(
    clave: 'asistente',
    titulo: 'Asistente',
    interruptor: 'anotarVenta',
    palabras: ['asistente', 'chat', 'gecko'],
    texto:
        'El asistente responde con los datos del teléfono: ventas, stock, deudas, pedidos, capital, horario y dirección. Esas respuestas no gastan chats. Para anotar una venta o una entrada de stock arma un plan y recién guarda cuando tocás Confirmar. Preguntale cómo se usa cualquier parte de la app.',
  ),
  GuiaFuncion(
    clave: 'equipo',
    titulo: 'Equipo',
    palabras: ['equipo', 'empleado', 'codigo', 'vendedor'],
    texto:
        'Equipo invita a otra persona con un código. Al entrar, el empleado carga nombre y apellido. Quien crea el negocio carga nombre, apellido y el WhatsApp del local. Un administrador puede desactivar el acceso.',
  ),
  GuiaFuncion(
    clave: 'moneda',
    titulo: 'País y moneda',
    palabras: ['moneda', 'pais', 'cambiar moneda'],
    texto:
        'País y moneda, en Más, cambia la moneda en la que se muestran los importes. Si confirmás el cambio, los precios guardados se convierten.',
  ),
  GuiaFuncion(
    clave: 'actividad',
    titulo: 'Actividad',
    palabras: ['actividad', 'historial', 'movimientos'],
    texto:
        'Actividad es el historial de este teléfono: pedidos, stock, clientes y capital. Podés filtrar por hoy, por 7 días o por tipo, y buscar por la persona.',
  ),
  GuiaFuncion(
    clave: 'cuenta',
    titulo: 'Borrar cuenta',
    palabras: ['borrar cuenta', 'eliminar cuenta', 'cerrar sesion'],
    texto:
        'Cerrar sesión sale sin borrar nada. Borrar cuenta, en Más, pide que escribas BORRAR. Ahí se eliminan las fotos, el negocio si sos el dueño y la cuenta con la que entraste. No se puede deshacer.',
  ),
];

/// Respuesta para el dueño. Vacía si la frase no pide una explicación.
String textoInstructivo(
  String normalizado, {
  required bool consultarStock,
  required bool anotarVenta,
  required bool horarioDireccion,
  required bool ventasHoy,
  List<GuiaFuncion> guias = instructivoLocal,
}) {
  if (!_pideAyuda(normalizado) || guias.isEmpty) return '';
  final mejor = _mejorGuia(normalizado, guias);
  if (mejor == null) {
    final lista = guias.map((guia) => guia.titulo).join(', ');
    return 'Puedo explicarte: $lista. Decime cuál.';
  }
  final aviso = _avisoApagado(
    mejor.interruptor,
    consultarStock: consultarStock,
    anotarVenta: anotarVenta,
    horarioDireccion: horarioDireccion,
    ventasHoy: ventasHoy,
  );
  if (aviso.isEmpty) return mejor.texto;
  return '${mejor.texto}\n\n$aviso';
}

bool _pideAyuda(String texto) {
  return RegExp(
    r'\b(como|donde|instructivo|explicame|explica|ensename|pasos|ayuda)\b',
  ).hasMatch(texto) ||
      texto.contains('para que') ||
      texto.contains('que es') ||
      texto.contains('que hace');
}

GuiaFuncion? _mejorGuia(String texto, List<GuiaFuncion> guias) {
  GuiaFuncion? mejor;
  var puntaje = 0;
  for (final guia in guias) {
    var marca = 0;
    for (final palabra in guia.palabras) {
      if (texto.contains(palabra)) marca += palabra.contains(' ') ? 3 : 1;
    }
    if (marca > puntaje) {
      puntaje = marca;
      mejor = guia;
    }
  }
  return puntaje == 0 ? null : mejor;
}

String _avisoApagado(
  String interruptor, {
  required bool consultarStock,
  required bool anotarVenta,
  required bool horarioDireccion,
  required bool ventasHoy,
}) {
  final apagada = switch (interruptor) {
    'consultarStock' => !consultarStock,
    'anotarVenta' => !anotarVenta,
    'horarioDireccion' => !horarioDireccion,
    'ventasHoy' => !ventasHoy,
    _ => false,
  };
  if (!apagada) return '';
  return 'Esa parte del asistente está apagada. La volvés a prender en Tu página web.';
}
