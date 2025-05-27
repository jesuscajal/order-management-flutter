import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Importar las clases de la base de datos
import 'lib/data/app_database.dart';

void main() async {
  print('🔍 Verificando datos en la base de datos...\n');

  try {
    // Obtener el directorio de documentos
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, 'limpieza_app.db');

    // Crear conexión a la base de datos
    final database = AppDatabase(NativeDatabase(File(dbPath)));

    // Verificar si el archivo de base de datos existe
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      print('❌ El archivo de base de datos no existe en: $dbPath');
      print('💡 Esto es normal si nunca has ejecutado la aplicación.');
      return;
    }

    print('✅ Archivo de base de datos encontrado en: $dbPath');
    print('📊 Tamaño del archivo: ${dbFile.lengthSync()} bytes\n');

    // Verificar clientes
    print('📋 CLIENTES:');
    final clientes = await database.select(database.clientes).get();

    if (clientes.isEmpty) {
      print('❌ No hay clientes en la base de datos');
    } else {
      print('✅ Encontrados ${clientes.length} clientes:');
      for (final cliente in clientes) {
        print('  - ID: ${cliente.id}');
        print('    Nombre: ${cliente.nombre}');
        print('    Contacto: ${cliente.contacto ?? "Sin contacto"}');
        print('    Email: ${cliente.email ?? "Sin email"}');
        print('    Es Potencial: ${cliente.esPotencial ? "Sí" : "No"}');
        print('    Estado Pago: ${cliente.estadoPago}');
        print('    Fecha Creación: ${cliente.fechaCreacion}');
        if (cliente.notas != null) {
          print('    Notas: ${cliente.notas}');
        }
        print('');
      }
    }

    // Verificar historial de cambios de estado de clientes
    print('\n📈 HISTORIAL DE CAMBIOS DE CLIENTES:');
    final cambiosClientes =
        await database.select(database.historialClientes).get();

    if (cambiosClientes.isEmpty) {
      print('❌ No hay historial de cambios de clientes');
    } else {
      print('✅ Encontrados ${cambiosClientes.length} cambios de estado:');
      for (final cambio in cambiosClientes) {
        print('  - Cliente ID: ${cambio.clienteId}');
        print('    De: ${cambio.estadoAnterior} → A: ${cambio.estadoNuevo}');
        print('    Fecha: ${cambio.fechaCambio}');
        print('');
      }
    }

    // Verificar pedidos
    print('\n📦 PEDIDOS:');
    final pedidos = await database.select(database.pedidos).get();

    if (pedidos.isEmpty) {
      print('❌ No hay pedidos en la base de datos');
    } else {
      print('✅ Encontrados ${pedidos.length} pedidos:');
      for (final pedido in pedidos) {
        print('  - ID: ${pedido.id}');
        print('    Cliente ID: ${pedido.clienteId}');
        print('    Estado: ${pedido.estado}');
        print('    Monto Señado: \$${pedido.montoSenado}');
        print('    Fecha: ${pedido.fecha}');
        print('');
      }
    }

    // Verificar productos
    print('\n🧽 PRODUCTOS:');
    final productos = await database.select(database.productos).get();

    if (productos.isEmpty) {
      print('❌ No hay productos en la base de datos');
    } else {
      print('✅ Encontrados ${productos.length} productos:');
      for (final producto in productos) {
        print('  - ID: ${producto.id}');
        print('    Nombre: ${producto.nombre}');
        print('    Precio Compra: \$${producto.precioCompra}');
        print('    Precio Venta: \$${producto.precioVenta}');
        print('    Fecha Creación: ${producto.fechaCreacion}');
        print('');
      }
    }

    // Cerrar conexión
    await database.close();

    print('✅ Verificación completada exitosamente');
    print(
        '💡 Si no ves datos, es porque aún no has creado ningún registro en la aplicación.');
  } catch (e) {
    print('❌ Error al verificar la base de datos: $e');
    print('💡 Esto puede ser normal si la aplicación nunca se ha ejecutado.');
  }
}
