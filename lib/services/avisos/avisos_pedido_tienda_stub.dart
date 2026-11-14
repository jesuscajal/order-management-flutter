import 'dart:async';

import '../../data/app_database.dart';

/// La web no muestra avisos nativos ni abre el canal de pedidos.
class AvisosPedidoTienda {
  const AvisosPedidoTienda._();

  static Stream<void> get alLlegar => const Stream.empty();

  static Future<void> iniciar() async {}

  static void usarBase(AppDatabase base) {}
}
