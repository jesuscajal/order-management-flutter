import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la clave de OpenAI solo en el dispositivo.
/// No se escribe en el repositorio ni se envía a ningún otro servicio.
class ApiKeyStore {
  static const _clave = 'openai_api_key';

  Future<String?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString(_clave)?.trim();
    if (valor == null || valor.isEmpty) return null;
    return valor;
  }

  Future<void> guardar(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, apiKey.trim());
  }

  Future<void> borrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
  }
}
