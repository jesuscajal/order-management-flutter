import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_cliente.dart';

/// Alta e ingreso en Supabase Auth. La contraseña no se guarda.
class SesionRemota {
  const SesionRemota();

  /// Crea la cuenta y, si el correo ya existe, entra con la contraseña.
  /// Sin cliente configurado no hace nada y no lanza error.
  Future<void> entrarOCrear({
    required String correo,
    required String clave,
  }) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return;

    final email = correo.trim();
    try {
      try {
        final alta = await cliente.auth
            .signUp(email: email, password: clave)
            .timeout(const Duration(seconds: 15));
        if (!_yaHabiaCuenta(alta) && cliente.auth.currentSession != null) {
          return;
        }
      } on AuthException catch (error) {
        if (!_esCuentaExistente(error)) rethrow;
      }
      await cliente.auth
          .signInWithPassword(email: email, password: clave)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // La sesión local no depende de que Auth responda.
      return;
    }
  }

  Future<void> salir() async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return;
    if (cliente.auth.currentSession == null) return;
    try {
      await cliente.auth.signOut().timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  bool _yaHabiaCuenta(AuthResponse alta) {
    final identidades = alta.user?.identities;
    return alta.user != null && (identidades == null || identidades.isEmpty);
  }

  bool _esCuentaExistente(AuthException error) {
    final codigo = (error.code ?? '').toLowerCase();
    if (codigo == 'user_already_exists' || codigo == 'email_exists') {
      return true;
    }
    final mensaje = error.message.toLowerCase();
    return mensaje.contains('already registered') ||
        mensaje.contains('already been registered') ||
        mensaje.contains('user already exists') ||
        mensaje.contains('already in use');
  }
}
