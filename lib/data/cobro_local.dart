import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Día de cobro y teléfono de una persona, guardados en este dispositivo.
///
/// La clave es el nombre en minúsculas. No modifica la deuda.
class DatoCobro {
  const DatoCobro({this.fecha, this.telefono = ''});

  /// Día calendario, sin hora. Null si todavía no eligieron uno.
  final DateTime? fecha;

  /// Texto tal como lo escribió la persona. Puede estar vacío.
  final String telefono;

  bool get vacio => fecha == null && telefono.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        if (fecha != null) 'fecha': isoFecha(fecha!),
        if (telefono.trim().isNotEmpty) 'telefono': telefono.trim(),
      };

  factory DatoCobro.fromJson(Map<String, dynamic> json) {
    return DatoCobro(
      fecha: leerFechaIso(json['fecha'] as String? ?? ''),
      telefono: (json['telefono'] as String? ?? '').trim(),
    );
  }
}

/// `aaaa-mm-dd`, sin zona horaria, para que el día no se corra.
String isoFecha(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year.toString().padLeft(4, '0')}-$mes-$dia';
}

DateTime? leerFechaIso(String cruda) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(cruda.trim());
  if (match == null) return null;
  final anio = int.tryParse(match.group(1)!);
  final mes = int.tryParse(match.group(2)!);
  final dia = int.tryParse(match.group(3)!);
  if (anio == null || mes == null || dia == null) return null;
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  final fecha = DateTime(anio, mes, dia);
  if (fecha.year != anio || fecha.month != mes || fecha.day != dia) {
    return null;
  }
  return fecha;
}

class CobroLocal {
  const CobroLocal();

  static const _clave = 'gexi_cobro_v1';

  static String clavePersona(String persona) => persona.trim().toLowerCase();

  Future<Map<String, DatoCobro>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return {};
    try {
      final decoded = jsonDecode(crudo);
      if (decoded is! Map) return {};
      final mapa = <String, DatoCobro>{};
      decoded.forEach((clave, valor) {
        if (valor is! Map) return;
        final persona = clavePersona(clave.toString());
        if (persona.isEmpty) return;
        final dato = DatoCobro.fromJson(Map<String, dynamic>.from(valor));
        if (!dato.vacio) mapa[persona] = dato;
      });
      return mapa;
    } catch (_) {
      return {};
    }
  }

  /// [telefono] null conserva el anterior. Cadena vacía lo borra.
  /// [quitarFecha] deja el día en blanco y no toca el teléfono.
  Future<DatoCobro> guardar({
    required String persona,
    DateTime? fecha,
    String? telefono,
    bool quitarFecha = false,
  }) async {
    final clave = clavePersona(persona);
    final mapa = await cargar();
    if (clave.isEmpty) return const DatoCobro();
    final previo = mapa[clave] ?? const DatoCobro();
    final dia = quitarFecha ? null : (fecha ?? previo.fecha);
    final siguiente = DatoCobro(
      fecha: dia == null ? null : DateTime(dia.year, dia.month, dia.day),
      telefono: (telefono ?? previo.telefono).trim(),
    );
    if (siguiente.vacio) {
      mapa.remove(clave);
    } else {
      mapa[clave] = siguiente;
    }
    await _escribir(mapa);
    return siguiente;
  }

  Future<void> _escribir(Map<String, DatoCobro> mapa) async {
    final prefs = await SharedPreferences.getInstance();
    if (mapa.isEmpty) {
      await prefs.remove(_clave);
      return;
    }
    await prefs.setString(
      _clave,
      jsonEncode({
        for (final entrada in mapa.entries) entrada.key: entrada.value.toJson(),
      }),
    );
  }
}
