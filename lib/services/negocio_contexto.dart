import '../data/app_database.dart';

/// Producto con el stock leído de las tablas, sin crear usuarios.
class ProductoConStock {
  const ProductoConStock({
    required this.nombre,
    required this.precioCompra,
    required this.precioVenta,
    required this.stockYo,
    required this.stockNildo,
    required this.stockOtros,
  });

  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final int stockYo;
  final int stockNildo;
  final int stockOtros;

  int get stockTotal => stockYo + stockNildo + stockOtros;
}

/// Resume clientes, productos y stock para el asistente del prototipo.
/// No incluye capital, deudas ni datos que el prototipo no consulta.
class NegocioContexto {
  final AppDatabase database;

  NegocioContexto(this.database);

  Future<List<ProductoConStock>> listarProductosConStock() async {
    final productos = await database.select(database.productos).get();
    final stock = await database.select(database.stock).get();
    final usuarios = await database.select(database.usuarios).get();
    int? idYo;
    int? idNildo;
    for (final usuario in usuarios) {
      final nombre = usuario.nombre.trim().toLowerCase();
      if (nombre == 'yo' && (idYo == null || usuario.id < idYo)) {
        idYo = usuario.id;
      } else if (nombre == 'nildo' && (idNildo == null || usuario.id < idNildo)) {
        idNildo = usuario.id;
      }
    }
    final acumulado = <int, _StockAcum>{};

    for (final fila in stock) {
      final item = acumulado.putIfAbsent(fila.productoId, () => _StockAcum());
      if (idYo != null && fila.usuarioId == idYo) {
        item.yo += fila.cantidadActual;
      } else if (idNildo != null && fila.usuarioId == idNildo) {
        item.nildo += fila.cantidadActual;
      } else {
        item.otros += fila.cantidadActual;
      }
    }

    final lista = [
      for (final producto in productos)
        ProductoConStock(
          nombre: producto.nombre,
          precioCompra: producto.precioCompra,
          precioVenta: producto.precioVenta,
          stockYo: acumulado[producto.id]?.yo ?? 0,
          stockNildo: acumulado[producto.id]?.nildo ?? 0,
          stockOtros: acumulado[producto.id]?.otros ?? 0,
        ),
    ];
    lista.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return lista;
  }

  Future<String> resumir() async {
    final buffer = StringBuffer();
    final clientes = await database.select(database.clientes).get();
    final productos = await listarProductosConStock();
    clientes.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );

    buffer.writeln('Clientes (${clientes.length}):');
    if (clientes.isEmpty) {
      buffer.writeln('- sin registros');
    } else {
      for (final cliente in clientes.take(80)) {
        buffer.writeln('- ${cliente.nombre}');
      }
    }

    buffer.writeln('Productos (${productos.length}):');
    if (productos.isEmpty) {
      buffer.writeln('- sin registros');
    } else {
      for (final producto in productos.take(80)) {
        buffer.writeln(
          '- ${producto.nombre} | compra: ${producto.precioCompra} | '
          'venta: ${producto.precioVenta} | stock Yo: ${producto.stockYo} | '
          'Nildo: ${producto.stockNildo} | otros: ${producto.stockOtros}',
        );
      }
    }

    final texto = buffer.toString().trim();
    if (texto.length <= 8000) return texto;
    return texto.substring(0, 8000);
  }
}

class _StockAcum {
  int yo = 0;
  int nildo = 0;
  int otros = 0;
}
