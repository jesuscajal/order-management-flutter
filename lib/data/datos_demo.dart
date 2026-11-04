import 'app_database.dart';
import 'capital_repository.dart';
import 'pedido_repository.dart';
import 'stock_repository.dart';
import '../models/pedido_estado.dart';

bool _semillaEnCurso = false;

/// Datos de muestra Novaceltec. Solo corre si la base no tiene productos.
Future<void> sembrarDatosDemoNovaceltec(AppDatabase database) async {
  if (_semillaEnCurso) return;

  final stock = StockRepository(database);
  final existentes = await stock.obtenerProductos();
  if (existentes.isNotEmpty) return;

  _semillaEnCurso = true;
  try {
    await stock.registrarEntrada(
      nombre: 'Samsung Galaxy A15',
      cantidad: 4,
      precioCompra: 180000,
      precioVenta: 250000,
      propietario: StockRepository.propietarioYo,
    );
    await stock.registrarEntrada(
      nombre: 'Funda A15',
      cantidad: 12,
      precioCompra: 1500,
      precioVenta: 4500,
      propietario: StockRepository.propietarioYo,
    );
    await stock.registrarEntrada(
      nombre: 'Cargador USB-C',
      cantidad: 6,
      precioCompra: 3000,
      precioVenta: 8000,
      propietario: StockRepository.propietarioYo,
    );
    await stock.registrarEntrada(
      nombre: 'Remera básica',
      cantidad: 3,
      precioCompra: 4000,
      precioVenta: 12000,
      propietario: StockRepository.propietarioNildo,
    );

    final productos = await stock.obtenerProductos();
    int? idPorNombre(String clave) {
      final buscado = clave.trim().toLowerCase();
      for (final producto in productos) {
        if (producto.nombre.trim().toLowerCase() == buscado) {
          return producto.id;
        }
      }
      return null;
    }

    final idFunda = idPorNombre('Funda A15');
    final idA15 = idPorNombre('Samsung Galaxy A15');

    final pedidos = PedidoRepository(database);

    if (idFunda != null) {
      await pedidos.crearPedido(
        clienteNombre: 'María Gómez',
        montoSenado: 0,
        lineas: [
          LineaPedidoBorrador(productoId: idFunda, cantidad: 1),
        ],
      );
    }

    if (idA15 != null) {
      const precioA15 = 250000.0;
      final idLucas = await pedidos.crearPedido(
        clienteNombre: 'Lucas Pérez',
        montoSenado: precioA15,
        lineas: [
          LineaPedidoBorrador(productoId: idA15, cantidad: 1),
        ],
      );
      await pedidos.cambiarEstado(
        idLucas,
        PedidoEstado.confirmado.texto,
      );
    }

    final capital = CapitalRepository(database);
    await capital.registrar(
      persona: 'María Gómez',
      monto: 15000,
      tipo: TiposCapital.capitalACobrar,
      descripcion: 'Saldo funda',
    );
    await capital.registrar(
      persona: 'Yo',
      monto: 50000,
      tipo: TiposCapital.entrada,
      descripcion: 'Aporte inicial',
    );
  } finally {
    _semillaEnCurso = false;
  }
}
