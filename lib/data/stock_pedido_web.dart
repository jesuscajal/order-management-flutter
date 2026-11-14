/// Marca de la salida que escribe `crear_pedido_tienda`.
///
/// El teléfono la reconoce para bajar el stock local una sola vez
/// y para no volver a descontarlo al confirmar el pedido.
class StockPedidoWeb {
  const StockPedidoWeb._();

  static const prefijo = 'Salida por pedido web ';

  static String descripcion(String pedidoUuid) {
    final id = pedidoUuid.trim().toLowerCase();
    return '$prefijo$id';
  }

  /// Uuid del pedido, o null si el texto no es una salida de la página.
  static String? uuidDe(String? descripcion) {
    final texto = (descripcion ?? '').trim();
    if (texto.length <= prefijo.length) return null;
    if (!texto.toLowerCase().startsWith(prefijo.toLowerCase())) return null;
    final id = texto.substring(prefijo.length).trim().toLowerCase();
    if (id.isEmpty || id.contains(' ')) return null;
    return id;
  }
}
