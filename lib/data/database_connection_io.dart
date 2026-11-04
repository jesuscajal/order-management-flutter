import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final carpeta = await getApplicationDocumentsDirectory();
    final archivo = File(p.join(carpeta.path, 'db.sqlite'));
    return NativeDatabase(archivo);
  });
}
