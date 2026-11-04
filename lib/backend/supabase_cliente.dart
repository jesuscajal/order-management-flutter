import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente de Supabase armado solo con variables de compilación.
///
/// Sin `--dart-define=SUPABASE_URL` y `--dart-define=SUPABASE_ANON_KEY`
/// [estaConfigurado] queda en false y el resto de la app sigue en local.
class SupabaseListo {
  SupabaseListo._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const claveAnonima = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _iniciado = false;

  static bool get estaConfigurado =>
      url.trim().isNotEmpty && claveAnonima.trim().isNotEmpty;

  /// No hace nada si faltan las variables. Un fallo de red o de clave
  /// tampoco tira abajo el arranque local.
  static Future<void> iniciar() async {
    if (!estaConfigurado || _iniciado) return;
    try {
      await Supabase.initialize(
        url: url.trim(),
        publishableKey: claveAnonima.trim(),
      );
      _iniciado = true;
    } catch (_) {
      _iniciado = false;
    }
  }

  static SupabaseClient? get cliente {
    if (!_iniciado) return null;
    return Supabase.instance.client;
  }
}
