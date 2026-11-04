import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/negocio_local.dart';
import 'negocio_remoto.dart';
import 'supabase_cliente.dart';

/// Cliente, negocio y cola compartidos por las copias a Supabase.
///
/// Sin sesión o sin dart-define, [cliente] es null y nadie toca la red.
class RemotoComun {
  const RemotoComun._();

  static Future<void> _cadena = Future<void>.value();

  static SupabaseClient? get cliente {
    try {
      if (!SupabaseListo.estaConfigurado) return null;
      final actual = SupabaseListo.cliente;
      final email = actual?.auth.currentUser?.email?.trim() ?? '';
      if (actual == null || email.isEmpty) return null;
      return actual;
    } catch (_) {
      return null;
    }
  }

  static bool get activo => cliente != null;

  static void aviso(String mensaje) {
    debugPrint('Gexi: $mensaje');
  }

  /// Una sola cola. Así la semilla local termina de subir antes de traer la nube,
  /// y dos guardados del mismo producto no se pisan.
  static Future<T> enSerie<T>(Future<T> Function() accion) {
    final pendiente = _cadena.then((_) => accion());
    _cadena = pendiente.then<void>((_) {}, onError: (_, __) {});
    return pendiente;
  }

  static void enSegundoPlano(Future<void> Function() accion) {
    enSerie(() async {
      try {
        await accion();
      } catch (error) {
        aviso('No se pudo sincronizar: $error');
      }
    });
  }

  /// El mismo id estable que usa [NegocioRemoto.publicar].
  static Future<String?> negocioId() async {
    final supabase = cliente;
    if (supabase == null) return null;
    try {
      final negocio = await NegocioStore().leer();
      if (negocio != null && negocio.codigo.trim().isNotEmpty) {
        final id = const NegocioRemoto().idParaSesion(negocio);
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (error) {
      aviso('No se pudo leer el negocio local: $error');
    }
    try {
      final email = supabase.auth.currentUser?.email?.trim() ?? '';
      if (email.isEmpty) return null;
      final filas = await supabase
          .from('negocios')
          .select('id')
          .eq('dueno_email', email)
          .limit(1);
      if (filas.isEmpty) return null;
      final id = filas.first['id'];
      final texto = id?.toString().trim() ?? '';
      return texto.isEmpty ? null : texto;
    } catch (error) {
      aviso('No se pudo ubicar el negocio en la nube: $error');
      return null;
    }
  }
}

String textoRemoto(Object? valor) => valor?.toString().trim() ?? '';

double? numeroRemoto(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse(textoRemoto(valor));
}

int? enteroRemoto(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(textoRemoto(valor));
}

bool banderaRemota(Object? valor) {
  if (valor is bool) return valor;
  final texto = textoRemoto(valor).toLowerCase();
  return texto == 'true' || texto == 't' || texto == '1';
}

DateTime fechaRemota(Object? valor) {
  if (valor is DateTime) return valor.toLocal();
  return DateTime.tryParse(textoRemoto(valor))?.toLocal() ?? DateTime.now();
}

String? medioDeDescripcion(String? descripcion) {
  final texto = (descripcion ?? '').trim().toLowerCase();
  if (texto.startsWith('efectivo')) return 'efectivo';
  if (texto.startsWith('transferencia')) return 'transferencia';
  if (texto.startsWith('fiado')) return 'fiado';
  if (texto.startsWith('otro')) return 'otro';
  return null;
}
