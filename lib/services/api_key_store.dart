import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la clave de OpenAI solo en el dispositivo.
/// No se escribe en el repositorio ni se envía a ningún otro servicio.
/// El cupo de mensajes de prueba usa otra clave y no toca la de OpenAI.
class ApiKeyStore {
  static const _clave = 'openai_api_key';
  static const claveMensajesAsistente = 'gexi_mensajes_asistente_v1';
  static const limiteMensajesAsistente = 10;

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

  Future<int> leerMensajesUsados() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(claveMensajesAsistente) ?? 0;
  }

  /// Suma un mensaje que sí llamó al modelo. El filtro local no usa este método.
  Future<int> consumirMensajeAsistente() async {
    final prefs = await SharedPreferences.getInstance();
    final actual = prefs.getInt(claveMensajesAsistente) ?? 0;
    final siguiente = actual + 1;
    await prefs.setInt(claveMensajesAsistente, siguiente);
    return siguiente;
  }
}
