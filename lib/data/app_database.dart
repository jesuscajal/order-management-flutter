import 'package:drift/drift.dart';

part 'app_database.g.dart';

// Tabla de usuarios
class Usuarios extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get tipo => text().withDefault(const Constant('usuario'))();
}

// Tabla de clientes
class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get contacto => text().nullable()();
  TextColumn get email => text().nullable()();
  BoolColumn get esPotencial => boolean().withDefault(const Constant(false))();
  TextColumn get notas => text().nullable()();
  TextColumn get estadoPago =>
      text().withDefault(const Constant('pendiente'))();
  DateTimeColumn get fechaCreacion =>
      dateTime().withDefault(currentDateAndTime)();
}

// Tabla de productos
class Productos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  RealColumn get precioCompra => real().withDefault(const Constant(0.0))();
  RealColumn get precioVenta => real().withDefault(const Constant(0.0))();
  DateTimeColumn get fechaCreacion =>
      dateTime().withDefault(currentDateAndTime)();
}

// Tabla de stock
class Stock extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  IntColumn get cantidadActual => integer().withDefault(const Constant(0))();
}

// Movimientos de stock
class MovimientosStock extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get usuarioId => integer().references(Usuarios, #id)();
  TextColumn get tipo => text()(); // entrada, salida
  IntColumn get cantidad => integer()();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get fechaCarga => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get fechaSalida => dateTime().nullable()();
}

// Tabla de pedidos
class Pedidos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  DateTimeColumn get fecha => dateTime().withDefault(currentDateAndTime)();
  TextColumn get estado => text().withDefault(const Constant('pendiente'))();
  RealColumn get montoSenado => real().withDefault(const Constant(0.0))();
}

// Productos en cada pedido
class ProductosPedido extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pedidoId => integer().references(Pedidos, #id)();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get cantidad => integer()();
}

// Historial de cambios de estado de pedidos
class HistorialPedidos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pedidoId => integer().references(Pedidos, #id)();
  TextColumn get estadoAnterior => text()();
  TextColumn get estadoNuevo => text()();
  DateTimeColumn get fechaCambio =>
      dateTime().withDefault(currentDateAndTime)();
}

// Historial de cambios de estado de clientes
class HistorialClientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  TextColumn get estadoAnterior => text()();
  TextColumn get estadoNuevo => text()();
  DateTimeColumn get fechaCambio =>
      dateTime().withDefault(currentDateAndTime)();
}

// Movimientos de capital y deuda
class MovimientosCapital extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get persona => text()(); // nombre o referencia
  RealColumn get monto => real()();
  TextColumn get tipo =>
      text()(); // entrada, salida, capital a cobrar, devolucion, etc.
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get fecha => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Usuarios,
  Clientes,
  Productos,
  Stock,
  MovimientosStock,
  Pedidos,
  ProductosPedido,
  HistorialPedidos,
  HistorialClientes,
  MovimientosCapital,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}
