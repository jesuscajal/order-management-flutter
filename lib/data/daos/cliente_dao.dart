import 'package:drift/drift.dart';
import '../app_database.dart';

part 'cliente_dao.g.dart';

@DriftAccessor(tables: [Clientes, HistorialClientes])
class ClienteDao extends DatabaseAccessor<AppDatabase> with _$ClienteDaoMixin {
  ClienteDao(AppDatabase db) : super(db);

  // Obtener todos los clientes
  Future<List<Cliente>> getAllClientes() => select(clientes).get();

  // Obtener clientes filtrados
  Future<List<Cliente>> getClientesFiltrados(bool soloPotenciales) {
    final query = select(clientes);
    if (soloPotenciales) {
      query.where((c) => c.esPotencial.equals(true));
    }
    return query.get();
  }

  // Insertar un nuevo cliente
  Future<int> insertCliente(ClientesCompanion cliente) {
    return into(clientes).insert(cliente);
  }

  // Actualizar un cliente existente
  Future<bool> updateCliente(ClientesCompanion cliente) {
    return update(clientes).replace(cliente);
  }

  // Eliminar un cliente
  Future<bool> deleteCliente(int id) async {
    final deleted =
        await (delete(clientes)..where((c) => c.id.equals(id))).go();
    return deleted > 0;
  }

  // Registrar cambio de estado en el historial
  Future<int> registrarCambioEstado(
      int clienteId, String estadoAnterior, String estadoNuevo) {
    return into(historialClientes).insert(HistorialClientesCompanion.insert(
      clienteId: clienteId,
      estadoAnterior: estadoAnterior,
      estadoNuevo: estadoNuevo,
    ));
  }
}
