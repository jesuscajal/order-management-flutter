import 'dart:io';

void main() async {
  print('🔍 Verificando archivos de base de datos...\n');

  // Posibles ubicaciones de la base de datos
  final possiblePaths = [
    // Android
    '/data/data/com.example.limpieza_app/databases/limpieza_app.db',
    '/storage/emulated/0/Android/data/com.example.limpieza_app/databases/limpieza_app.db',

    // Directorio actual (para desarrollo)
    './limpieza_app.db',
    './database.db',

    // Directorio de documentos (Windows)
    '${Platform.environment['USERPROFILE']}\\Documents\\limpieza_app.db',

    // Directorio temporal
    '${Directory.systemTemp.path}/limpieza_app.db',
  ];

  bool foundDatabase = false;

  for (final path in possiblePaths) {
    final file = File(path);
    if (file.existsSync()) {
      foundDatabase = true;
      final size = file.lengthSync();
      final modified = file.lastModifiedSync();

      print('✅ Base de datos encontrada:');
      print('   📍 Ubicación: $path');
      print('   📊 Tamaño: $size bytes');
      print('   📅 Última modificación: $modified');

      if (size > 0) {
        print('   💾 El archivo contiene datos');
      } else {
        print('   ⚠️  El archivo está vacío');
      }
      print('');
    }
  }

  if (!foundDatabase) {
    print('❌ No se encontró ningún archivo de base de datos');
    print('💡 Esto significa que:');
    print('   • La aplicación nunca se ha ejecutado');
    print('   • O la base de datos está en una ubicación diferente');
    print('   • O hay problemas de permisos');
    print('');
    print('🔧 Para crear datos de prueba, ejecuta la aplicación y:');
    print('   1. Ve a la pantalla de Clientes');
    print('   2. Presiona el botón + para agregar un cliente');
    print('   3. Llena los datos y guarda');
  }

  // Verificar si hay archivos relacionados
  print('\n🔍 Buscando archivos relacionados...');
  final currentDir = Directory.current;
  final files = currentDir.listSync(recursive: true);

  final dbFiles = files
      .where((file) =>
          file.path.contains('.db') ||
          file.path.contains('database') ||
          file.path.contains('sqlite'))
      .toList();

  if (dbFiles.isNotEmpty) {
    print('📁 Archivos de base de datos encontrados:');
    for (final file in dbFiles) {
      if (file is File) {
        print('   • ${file.path} (${file.lengthSync()} bytes)');
      }
    }
  } else {
    print(
        '❌ No se encontraron archivos de base de datos en el directorio actual');
  }

  print('\n✅ Verificación completada');
}
