import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../openai_chat_service.dart';

/// Un turno que sí llamó al modelo.
class TurnoMedido {
  const TurnoMedido({
    required this.cuando,
    required this.modelo,
    required this.versionPrompt,
    required this.entrada,
    required this.salida,
    required this.enCache,
    required this.milisegundos,
    required this.acciones,
    required this.error,
  });

  final DateTime cuando;
  final String modelo;
  final String versionPrompt;
  final int entrada;
  final int salida;
  final int enCache;
  final int milisegundos;

  /// Cuántas acciones devolvió. 0 es un turno que no sirvió para operar.
  final int acciones;
  final bool error;

  Map<String, dynamic> toJson() => {
        'cuando': cuando.toIso8601String(),
        'modelo': modelo,
        'version': versionPrompt,
        'entrada': entrada,
        'salida': salida,
        'cache': enCache,
        'ms': milisegundos,
        'acciones': acciones,
        'error': error,
      };

  factory TurnoMedido.fromJson(Map<String, dynamic> json) {
    int entero(dynamic valor) => valor is num ? valor.toInt() : 0;
    return TurnoMedido(
      cuando: DateTime.tryParse(json['cuando'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      modelo: json['modelo'] as String? ?? '',
      versionPrompt: json['version'] as String? ?? '',
      entrada: entero(json['entrada']),
      salida: entero(json['salida']),
      enCache: entero(json['cache']),
      milisegundos: entero(json['ms']),
      acciones: entero(json['acciones']),
      error: json['error'] == true,
    );
  }
}

class ResumenMetricas {
  const ResumenMetricas({
    required this.turnos,
    required this.entrada,
    required this.salida,
    required this.enCache,
    required this.msPromedio,
    required this.utiles,
  });

  final int turnos;
  final int entrada;
  final int salida;
  final int enCache;
  final int msPromedio;

  /// Turnos que devolvieron al menos una acción y no fallaron.
  final int utiles;

  int get total => entrada + salida;
}

/// Guarda en el teléfono los últimos turnos del modelo: tokens, demora y si
/// sirvieron. No guarda la frase ni la clave.
class MetricasAsistente {
  const MetricasAsistente();

  static const _clave = 'gexi_metricas_asistente_v1';
  static const _tope = 200;

  Future<void> registrar({
    required UsoOpenAi? uso,
    required String modelo,
    required String versionPrompt,
    required int acciones,
    required bool error,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _leer(prefs.getString(_clave));
    lista.add(
      TurnoMedido(
        cuando: DateTime.now(),
        modelo: modelo,
        versionPrompt: versionPrompt,
        entrada: uso?.entrada ?? 0,
        salida: uso?.salida ?? 0,
        enCache: uso?.enCache ?? 0,
        milisegundos: uso?.milisegundos ?? 0,
        acciones: acciones,
        error: error,
      ),
    );
    final recortada =
        lista.length > _tope ? lista.sublist(lista.length - _tope) : lista;
    await prefs.setString(
      _clave,
      jsonEncode([for (final turno in recortada) turno.toJson()]),
    );
  }

  Future<ResumenMetricas> resumir() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _leer(prefs.getString(_clave));
    var entrada = 0;
    var salida = 0;
    var cache = 0;
    var ms = 0;
    var utiles = 0;
    for (final turno in lista) {
      entrada += turno.entrada;
      salida += turno.salida;
      cache += turno.enCache;
      ms += turno.milisegundos;
      if (!turno.error && turno.acciones > 0) utiles++;
    }
    return ResumenMetricas(
      turnos: lista.length,
      entrada: entrada,
      salida: salida,
      enCache: cache,
      msPromedio: lista.isEmpty ? 0 : ms ~/ lista.length,
      utiles: utiles,
    );
  }

  List<TurnoMedido> _leer(String? crudo) {
    if (crudo == null || crudo.isEmpty) return [];
    try {
      final decoded = jsonDecode(crudo);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map) TurnoMedido.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return [];
    }
  }
}
