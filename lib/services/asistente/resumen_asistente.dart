import '../asistente_enrutador.dart';

/// Arma el texto que viaja junto con la ficha. No llama al modelo.
String armarFichaConResumen(String ficha, String resumen) {
  final texto = resumen.trim();
  if (texto.isEmpty) return ficha;
  return '$ficha\n<contexto_chat>$texto</contexto_chat>';
}

/// Última intención y productos mencionados, como máximo 500 caracteres.
String actualizarResumenAsistente({
  required String anterior,
  required String frase,
  List<String> productos = const [],
}) {
  final pedido = frase.trim();
  if (pedido.isEmpty) return _tope(anterior.trim());

  final intencion = intencionLocal(pedido);
  final nombres = <String>[];
  for (final nombre in [...productos, ..._productosPrevios(anterior)]) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) continue;
    final clave = limpio.toLowerCase();
    if (nombres.any((otro) => otro.toLowerCase() == clave)) continue;
    nombres.add(limpio);
    if (nombres.length == 8) break;
  }
  final lista = nombres.isEmpty ? 'ninguno' : nombres.join(', ');
  return _tope('Última intención: $intencion. Productos: $lista.');
}

String intencionLocal(String frase) {
  final t = frase.toLowerCase();
  if (RegExp(r'\b(vend[ií]|venta|pedido)\b').hasMatch(t)) return 'venta';
  if (RegExp(r'\b(entraron|entrada|sumale|sumá|agrega|agregá|cargá|carga|alta)\b')
      .hasMatch(t)) {
    return 'entrada de stock';
  }
  if (RegExp(r'\b(stock|queda|quedan|poco)\b').hasMatch(t)) {
    return 'consulta de stock';
  }
  if (RegExp(r'\b(debe|deuda|capital)\b').hasMatch(t)) return 'consulta';
  switch (clasificarIntencion(frase)) {
    case IntencionAsistente.venta:
      return 'venta';
    case IntencionAsistente.producto:
      return 'alta de producto';
    case IntencionAsistente.ajusteStock:
      return 'ajuste de stock';
    case IntencionAsistente.stock:
      return 'consulta de stock';
    case IntencionAsistente.fuera:
      return 'consulta';
  }
}

String _tope(String texto) {
  if (texto.length <= 500) return texto;
  return texto.substring(0, 500);
}

List<String> _productosPrevios(String anterior) {
  const marca = 'Productos:';
  final indice = anterior.indexOf(marca);
  if (indice < 0) return const [];
  var lista = anterior.substring(indice + marca.length).trim();
  if (lista.endsWith('.')) lista = lista.substring(0, lista.length - 1).trim();
  if (lista.isEmpty || lista.toLowerCase() == 'ninguno') return const [];
  return [
    for (final parte in lista.split(','))
      if (parte.trim().isNotEmpty) parte.trim(),
  ];
}
