import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'google_client_id.dart'
    if (dart.library.html) 'google_client_id_web.dart';

class SesionGoogle {
  const SesionGoogle({
    required this.nombre,
    required this.email,
    this.fotoUrl,
  });

  final String nombre;
  final String email;
  final String? fotoUrl;

  String get saludo {
    final primer = nombre.trim().split(' ').first;
    return primer.isEmpty ? email : primer;
  }

  Map<String, String?> toJson() => {
        'nombre': nombre,
        'email': email,
        'fotoUrl': fotoUrl,
      };

  factory SesionGoogle.fromJson(Map<String, dynamic> json) {
    return SesionGoogle(
      nombre: json['nombre'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fotoUrl: json['fotoUrl'] as String?,
    );
  }
}

class AuthGoogle {
  AuthGoogle._();

  static final AuthGoogle instancia = AuthGoogle._();
  static const _clave = 'sesion_google_v1';

  GoogleSignIn? _google;

  GoogleSignIn _cliente() {
    return _google ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
    );
  }

  Future<SesionGoogle?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return null;
    try {
      final decoded = jsonDecode(crudo);
      if (decoded is! Map<String, dynamic>) return null;
      final sesion = SesionGoogle.fromJson(decoded);
      if (sesion.email.isEmpty) return null;
      return sesion;
    } catch (_) {
      return null;
    }
  }

  Future<SesionGoogle> entrarParaVer() {
    return entrarConCorreo('piloto@novaceltec.local', nombre: 'Jesús Cajal');
  }

  Future<SesionGoogle> entrarConCorreo(String email, {String? nombre}) async {
    final limpio = email.trim();
    final pieza = limpio.split('@').first.replaceAll(RegExp(r'[._]+'), ' ').trim();
    final sesion = SesionGoogle(
      nombre: (nombre ?? pieza).trim().isEmpty ? 'Gexi' : (nombre ?? pieza).trim(),
      email: limpio,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(sesion.toJson()));
    return sesion;
  }

  Future<SesionGoogle?> entrar() async {
    if (kIsWeb && !hayClientIdDeGoogle()) {
      throw StateError('ClientID not set');
    }
    final cuenta = await _cliente().signIn();
    if (cuenta == null) return null;
    final sesion = SesionGoogle(
      nombre: (cuenta.displayName ?? '').trim().isEmpty
          ? cuenta.email
          : cuenta.displayName!.trim(),
      email: cuenta.email,
      fotoUrl: cuenta.photoUrl,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(sesion.toJson()));
    return sesion;
  }

  Future<void> salir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
    final google = _google;
    if (google == null) return;
    try {
      await google.signOut();
    } catch (_) {}
  }
}
