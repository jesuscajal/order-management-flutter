import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_cliente.dart';

class BorrarCuentaException implements Exception {
  const BorrarCuentaException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Pide a la nube que borre imágenes, datos y la cuenta de ingreso.
class BorrarCuenta {
  const BorrarCuenta();

  Future<void> ejecutar() async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null || cliente.auth.currentUser == null) {
      throw const BorrarCuentaException(
        'No hay una cuenta abierta en la nube.',
      );
    }
    try {
      await cliente.functions
          .invoke(
            'borrar-cuenta',
            body: const {'confirmacion': 'BORRAR'},
          )
          .timeout(const Duration(seconds: 40));
    } on FunctionException catch (error) {
      throw BorrarCuentaException(_mensaje(error));
    } catch (_) {
      throw const BorrarCuentaException(
        'No se pudo borrar la cuenta. Probá de nuevo.',
      );
    }
  }

  String _mensaje(FunctionException error) {
    final detalles = error.details;
    if (detalles is Map && detalles['mensaje'] is String) {
      final texto = (detalles['mensaje'] as String).trim();
      if (texto.isNotEmpty) return texto;
    }
    return 'No se pudo borrar la cuenta. Probá de nuevo.';
  }
}
