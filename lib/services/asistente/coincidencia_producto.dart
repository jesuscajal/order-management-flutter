import 'dart:typed_data';

/// Resultado de una búsqueda de catálogo. No elige un producto si hay varios.
class CoincidenciaProducto {
  const CoincidenciaProducto({
    required this.id,
    required this.nombre,
    this.categoria = '',
    this.categorias = const [],
    required this.stock,
    required this.precioCompra,
    required this.precioVenta,
    required this.activo,
    this.fotoUrl,
    this.fotoBytes,
  });

  final int id;
  final String nombre;

  /// Vacía si el producto no tiene categoría en la ficha local.
  final String categoria;
  final List<String> categorias;
  final int stock;
  final double precioCompra;
  final double precioVenta;

  /// true si se muestra en la vidriera, o si todavía no tiene ficha.
  final bool activo;

  /// URL http(s) pública (`productos.imagen_url` o `fotos_producto.url`).
  /// Si está presente, tiene prioridad sobre [fotoBytes].
  final String? fotoUrl;

  /// Primera foto general de la vidriera local, solo cuando no hay URL.
  final Uint8List? fotoBytes;

  CoincidenciaProducto conFoto({String? fotoUrl, Uint8List? fotoBytes}) {
    final url = fotoUrl?.trim();
    final publica = url == null || url.isEmpty ? null : url;
    final bytes = fotoBytes == null || fotoBytes.isEmpty ? null : fotoBytes;
    return CoincidenciaProducto(
      id: id,
      nombre: nombre,
      categoria: categoria,
      categorias: categorias,
      stock: stock,
      precioCompra: precioCompra,
      precioVenta: precioVenta,
      activo: activo,
      fotoUrl: publica,
      fotoBytes: publica == null ? bytes : null,
    );
  }
}

/// Separa el nombre igual del que solo se parece.
///
/// [esUnico] es true con un exacto y ningún parecido, o con un solo parecido
/// y ningún exacto. Si hay más de uno, [unico] queda en null para que la
/// interfaz pregunte.
class ResultadoBusquedaProducto {
  const ResultadoBusquedaProducto({
    this.exactos = const [],
    this.parecidos = const [],
  });

  /// Nombre normalizado igual al texto buscado.
  final List<CoincidenciaProducto> exactos;

  /// Contiene el texto o es muy cercano. No repite los [exactos].
  final List<CoincidenciaProducto> parecidos;

  bool get esUnico =>
      exactos.length == 1 && parecidos.isEmpty ||
      (exactos.isEmpty && parecidos.length == 1);

  CoincidenciaProducto? get unico =>
      esUnico ? (exactos.isNotEmpty ? exactos.first : parecidos.first) : null;

  bool get vacio => exactos.isEmpty && parecidos.isEmpty;
}
