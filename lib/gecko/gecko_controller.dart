import 'dart:async';
import 'package:flutter/foundation.dart';
import 'gecko_mood.dart';

typedef AnalyzeCallback = void Function();

/// Control central de animación: puede vivir en Provider/GetIt o junto a una vista.
/// No ejecuta IA por sí mismo; representa el estado REAL del trabajo externo.
class GeckoAssistantController extends ChangeNotifier {
  GeckoMood _mood = GeckoMood.idle;
  GeckoMood get mood => _mood;

  int _generation = 0;
  Timer? _autoReturn;

  void setMood(GeckoMood mood) {
    _autoReturn?.cancel();
    if (_mood == mood) return;
    _mood = mood;
    notifyListeners();
  }

  void reset() {
    _generation++;
    setMood(GeckoMood.idle);
  }

  /// Ejecuta una operación real (API, base de datos, IA) y sincroniza los estados.
  /// `markAnalyzing()` debe llamarse cuando realmente se empieza a consultar datos.
  /// Cada llamada tiene una generación para que una respuesta vieja no reemplace
  /// la animación de una consulta más reciente.
  Future<T> runTask<T>(
    Future<T> Function(AnalyzeCallback markAnalyzing) operation, {
    Duration outcomeVisibility = const Duration(milliseconds: 1500),
  }) async {
    final current = ++_generation;
    setMood(GeckoMood.thinking);
    void markAnalyzing() {
      if (current == _generation) setMood(GeckoMood.analyzing);
    }

    try {
      final result = await operation(markAnalyzing);
      if (current == _generation) {
        setMood(GeckoMood.success);
        _scheduleIdle(current, outcomeVisibility);
      }
      return result;
    } catch (_) {
      if (current == _generation) {
        setMood(GeckoMood.error);
        _scheduleIdle(current, outcomeVisibility);
      }
      rethrow;
    }
  }

  void _scheduleIdle(int current, Duration duration) {
    _autoReturn?.cancel();
    _autoReturn = Timer(duration, () {
      if (current == _generation) setMood(GeckoMood.idle);
    });
  }

  @override
  void dispose() {
    _autoReturn?.cancel();
    super.dispose();
  }
}
