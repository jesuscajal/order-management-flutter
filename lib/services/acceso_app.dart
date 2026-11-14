import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/supabase_cliente.dart';

/// Anota la ciudad desde la que se abrió la app, una vez cada 12 horas.
///
/// No guarda el punto exacto ni la dirección IP. Si no hay sesión, no hace nada.
class AccesoApp {
  const AccesoApp();

  static const _marca = 'acceso_app_ms';

  Future<void> anotarSiCorresponde() async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null || cliente.auth.currentSession == null) return;
    final prefs = await SharedPreferences.getInstance();
    final ultimo = prefs.getInt(_marca) ?? 0;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (ahora - ultimo < const Duration(hours: 12).inMilliseconds) return;
    final lugar = await _ciudad();
    if (lugar == null) return;
    try {
      await cliente.rpc('registrar_acceso', params: {
        'p_ciudad': lugar.ciudad,
        'p_region': lugar.region,
        'p_pais': lugar.pais,
      }).timeout(const Duration(seconds: 8));
      await prefs.setInt(_marca, ahora);
    } catch (_) {}
  }

  Future<_Ciudad?> _ciudad() async {
    try {
      final respuesta = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return null;
      final decoded = jsonDecode(respuesta.body);
      if (decoded is! Map || decoded['success'] == false) return null;
      final ciudad = _texto(decoded['city']);
      final region = _texto(decoded['region']);
      final pais = _texto(decoded['country']);
      if (ciudad.isEmpty && pais.isEmpty) return null;
      return _Ciudad(ciudad, region, pais);
    } catch (_) {
      return null;
    }
  }

  String _texto(Object? valor) => valor?.toString().trim() ?? '';
}

class _Ciudad {
  const _Ciudad(this.ciudad, this.region, this.pais);

  final String ciudad;
  final String region;
  final String pais;
}
