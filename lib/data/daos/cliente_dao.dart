import 'package:drift/drift.dart';

import '../../backend/clientes_remoto.dart';
import '../../backend/stock_remoto.dart';
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
  Future<int> insertCliente(ClientesCompanion cliente) async {
    final id = await into(clientes).insert(cliente);
    await _empujarCliente(id);
    return id;
  }

  // Actualiza solo los campos presentes. replace exigía también la fecha.
  Future<bool> updateCliente(ClientesCompanion cliente) async {
    if (!cliente.id.present) {
      throw ArgumentError('Falta el id del cliente.');
    }
    final filas = await (update(clientes)
          ..where((c) => c.id.equals(cliente.id.value)))
        .write(cliente.copyWith(id: const Value.absent()));
    if (filas > 0) await _empujarCliente(cliente.id.value);
    return filas > 0;
  }

  // Eliminar un cliente. El historial se borra antes para no chocar la clave.
  Future<bool> deleteCliente(int id) async {
    await (delete(historialClientes)..where((h) => h.clienteId.equals(id)))
        .go();
    final deleted =
        await (delete(clientes)..where((c) => c.id.equals(id))).go();
    if (deleted > 0) {
      ReplicaScope.diferir(() => ClientesRemoto.borrar(id));
    }
    return deleted > 0;
  }

  // Registrar cambio de estado en el historial
  Future<int> registrarCambioEstado(
      int clienteId, String estadoAnterior, String estadoNuevo) async {
    final id = await into(historialClientes).insert(
      HistorialClientesCompanion.insert(
        clienteId: clienteId,
        estadoAnterior: estadoAnterior,
        estadoNuevo: estadoNuevo,
      ),
    );
    await _empujarCliente(clienteId);
    ReplicaScope.diferir(
      () => ClientesRemoto.replicarHistorial(
        historialLocalId: id,
        clienteLocalId: clienteId,
        anterior: estadoAnterior,
        nuevo: estadoNuevo,
      ),
    );
    return id;
  }

  Future<void> _empujarCliente(int id) async {
    final fila = await (select(clientes)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (fila == null) return;
    ReplicaScope.diferir(
      () => ClientesRemoto.replicar(
        localId: fila.id,
        nombre: fila.nombre,
        telefono: fila.contacto,
        email: fila.email,
        notas: fila.notas,
        esPotencial: fila.esPotencial,
        estadoPago: fila.estadoPago,
      ),
    );
  }
}
