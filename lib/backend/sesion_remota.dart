import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_cliente.dart';

/// Error de la sesión remota, con el texto ya en español.
class SesionRemotaException implements Exception {
  const SesionRemotaException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Alta e ingreso en Supabase Auth. La contraseña no se guarda.
class SesionRemota {
  const SesionRemota();

  /// Abre la sesión de Supabase con el token de Google.
  /// Sin cliente configurado avisa: si no, el negocio no viaja a otro teléfono.
  Future<void> entrarConGoogle({
    required String idToken,
    String? accessToken,
  }) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) {
      throw const SesionRemotaException(
        'Esta compilación no está conectada a Supabase. Volvé a abrir la app con las claves del proyecto.',
      );
    }
    final acceso = accessToken?.trim() ?? '';
    try {
      await cliente.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: acceso.isEmpty ? null : acceso,
          )
          .timeout(const Duration(seconds: 20));
    } on AuthException catch (error) {
      throw SesionRemotaException(_traducir(error.message));
    }
  }

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

  String _traducir(String mensaje) {
    final texto = mensaje.toLowerCase();
    if (texto.contains('provider') &&
        (texto.contains('not enabled') || texto.contains('disabled'))) {
      return 'En Supabase falta activar el ingreso con Google, usando el mismo Client ID.';
    }
    if (texto.contains('audience') || texto.contains('client id')) {
      return 'El Client ID de Google no coincide con el que tiene Supabase.';
    }
    return 'No se pudo abrir la sesión en la nube. $mensaje';
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
