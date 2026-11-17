import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_cliente.dart';

/// Error de la sesión remota, con el texto ya en español.
class SesionRemotaException implements Exception {
  const SesionRemotaException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Resultado de crear o entrar con correo. [entro] solo es true con sesión.
class ResultadoCorreo {
  const ResultadoCorreo({required this.entro, this.mensaje = ''});

  final bool entro;
  final String mensaje;
}

/// Alta e ingreso en Supabase Auth. La contraseña no se guarda.
class SesionRemota {
  const SesionRemota();

  static const _volver = 'https://gexi.com.ar';

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

  /// Crea la cuenta y manda el correo de activación. No abre la app hasta
  /// que el correo esté activado. Sin cliente configurado deja entrar en local.
  Future<ResultadoCorreo> crearConCorreo({
    required String correo,
    required String clave,
  }) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return const ResultadoCorreo(entro: true);
    final email = correo.trim();
    try {
      final alta = await _alta(cliente, email, clave);
      if (_yaHabiaCuenta(alta)) {
        return const ResultadoCorreo(
          entro: false,
          mensaje:
              'Ese correo ya tiene cuenta. Ingresá con tu contraseña. Si todavía no la activaste, revisá el correo.',
        );
      }
      if (alta.user == null) {
        return const ResultadoCorreo(
          entro: false,
          mensaje: 'No se pudo crear la cuenta. Probá de nuevo.',
        );
      }
      if (alta.session != null || cliente.auth.currentSession != null) {
        return const ResultadoCorreo(entro: true);
      }
      return const ResultadoCorreo(
        entro: false,
        mensaje:
            'Te enviamos un correo para activar la cuenta. Abrilo y después entrá con este correo y tu contraseña.',
      );
    } on AuthException catch (error) {
      return ResultadoCorreo(entro: false, mensaje: _traducirAlta(error));
    } on TimeoutException {
      return const ResultadoCorreo(
        entro: false,
        mensaje: 'La nube tardó demasiado. Probá de nuevo.',
      );
    }
  }

  /// Entra solo si la cuenta ya está activada.
  Future<ResultadoCorreo> entrarConClave({
    required String correo,
    required String clave,
  }) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return const ResultadoCorreo(entro: true);
    final email = correo.trim();
    try {
      await cliente.auth
          .signInWithPassword(email: email, password: clave)
          .timeout(const Duration(seconds: 20));
      return const ResultadoCorreo(entro: true);
    } on AuthException catch (error) {
      if (_sinActivar(error)) {
        try {
          await cliente.auth.resend(type: OtpType.signup, email: email);
        } catch (_) {}
        return const ResultadoCorreo(
          entro: false,
          mensaje:
              'Falta activar la cuenta. Te reenviamos el correo. Abrilo y volvé a entrar.',
        );
      }
      return ResultadoCorreo(entro: false, mensaje: _traducirIngreso(error));
    } on TimeoutException {
      return const ResultadoCorreo(
        entro: false,
        mensaje: 'La nube tardó demasiado. Probá de nuevo.',
      );
    }
  }

  Future<AuthResponse> _alta(SupabaseClient cliente, String email, String clave) {
    return cliente.auth
        .signUp(
          email: email,
          password: clave,
          emailRedirectTo: _volver,
        )
        .timeout(const Duration(seconds: 20));
  }

  Future<void> guardarPerfil({
    required String nombre,
    required String apellido,
    String whatsapp = '',
  }) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null || cliente.auth.currentSession == null) return;
    try {
      await cliente.auth
          .updateUser(
            UserAttributes(
              data: {
                'nombre': nombre,
                'apellido': apellido,
                'whatsapp': whatsapp,
              },
            ),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
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

  bool _sinActivar(AuthException error) {
    final codigo = (error.code ?? '').toLowerCase();
    final mensaje = error.message.toLowerCase();
    return codigo == 'email_not_confirmed' || mensaje.contains('email not confirmed');
  }

  String _traducirAlta(AuthException error) {
    if (_esCuentaExistente(error)) {
      return 'Ese correo ya tiene cuenta. Ingresá con tu contraseña.';
    }
    return _traducirComun(error, alta: true);
  }

  String _traducirIngreso(AuthException error) {
    final codigo = (error.code ?? '').toLowerCase();
    final mensaje = error.message.toLowerCase();
    if (codigo == 'invalid_credentials' ||
        mensaje.contains('invalid login') ||
        mensaje.contains('invalid credentials')) {
      return 'El correo o la contraseña no coinciden.';
    }
    return _traducirComun(error, alta: false);
  }

  String _traducirComun(AuthException error, {required bool alta}) {
    final codigo = (error.code ?? '').toLowerCase();
    final mensaje = error.message.toLowerCase();
    if (codigo == 'weak_password' ||
        mensaje.contains('password should be') ||
        mensaje.contains('at least')) {
      return 'La contraseña es muy corta. Usá al menos 6 caracteres.';
    }
    if (codigo == 'over_request_rate_limit' ||
        codigo == 'over_email_send_rate_limit' ||
        mensaje.contains('rate limit')) {
      return 'Esperá un momento y volvé a intentar.';
    }
    if (mensaje.contains('redirect')) {
      return 'No se pudo armar el enlace de activación. Probá de nuevo.';
    }
    if (alta) return 'No se pudo crear la cuenta. Probá de nuevo.';
    return 'No se pudo ingresar. Probá de nuevo.';
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
