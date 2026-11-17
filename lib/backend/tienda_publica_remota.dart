import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/apariencia_tienda.dart';
import '../data/diseno_tienda.dart';
import '../utils/moneda.dart';
import 'supabase_cliente.dart';

class TiendaPublica {
  const TiendaPublica({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.whatsapp,
    required this.mensajePublico,
    this.moneda = monedaPorDefecto,
    this.apariencia = const AparienciaTienda(),
    this.diseno = const DisenoTienda(),
    this.logoUrl = '',
    this.aliasCobro = '',
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.mapsUrl = '',
    this.latitud,
    this.longitud,
    this.horario = '',
  });

  final String id;
  final String nombre;
  final String slug;
  final String whatsapp;
  final String mensajePublico;
  final String moneda;
  final AparienciaTienda apariencia;

  /// Presentación leída de `apariencia.layout`. General si todavía no hay.
  final DisenoTienda diseno;
  final String logoUrl;

  /// CBU, CVU o alias publicado en la vista. Vacío si el negocio no lo cargó.
  final String aliasCobro;

  /// Enlace de Facebook. Vacío si el negocio no lo cargó.
  final String facebookUrl;

  /// Enlace de Instagram. Vacío si el negocio no lo cargó.
  final String instagramUrl;

  /// Dirección del local, con numeración si se cargó. Vacío si no se cargó.
  final String mapsUrl;

  /// Punto del local. Nulo si todavía no hay coordenadas.
  final double? latitud;
  final double? longitud;

  /// Horario de atención. Vacío si el negocio no lo cargó.
  final String horario;
}

class ProductoTiendaPublica {
  const ProductoTiendaPublica({
    required this.negocioId,
    required this.id,
    required this.nombre,
    required this.precioVenta,
    required this.stock,
    this.descripcion = '',
    this.categorias = const [],
    this.fotos = const [],
  });

  final String negocioId;
  final String id;
  final String nombre;
  final double precioVenta;
  final int stock;
  final String descripcion;
  final List<String> categorias;
  final List<String> fotos;
}

class VarianteTiendaPublica {
  const VarianteTiendaPublica({
    required this.productoId,
    required this.id,
    required this.nombre,
    required this.precioVenta,
    required this.stock,
  });

  final String productoId;
  final String id;
  final String nombre;
  final double precioVenta;
  final int stock;
}

class FotoTiendaPublica {
  const FotoTiendaPublica({
    required this.productoId,
    required this.url,
    this.variante = '',
    this.orden = 0,
  });

  final String productoId;
  final String url;
  final String variante;
  final int orden;
}

/// Acceso tolerante a fallos a las vistas públicas de la tienda.
class TiendaPublicaRemota {
  const TiendaPublicaRemota();

  /// True si otro negocio ya publicó esa dirección.
  Future<bool> slugLoUsaOtro({
    required String slug,
    required String negocioId,
  }) async {
    final cliente = SupabaseListo.cliente;
    if (cliente == null || cliente.auth.currentUser == null) return false;
    final buscado = slug.trim().toLowerCase();
    final id = negocioId.trim();
    if (buscado.isEmpty || id.isEmpty) return false;
    final respuesta = await cliente.rpc(
      'slug_de_otro',
      params: {'p_slug': buscado, 'p_negocio_id': id},
    );
    return respuesta == true;
  }

  /// Suma una visita anónima a la página publicada. No guarda quién entró.
  Future<bool> registrarVisita(String slug) async {
    final cliente = _clienteActivo();
    final buscado = slug.trim().toLowerCase();
    if (cliente == null || buscado.isEmpty) return false;
    try {
      await cliente.rpc('registrar_visita_tienda', params: {'p_slug': buscado});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Visitas de la página de este usuario. Cero si no hay sesión o la función falta.
  Future<({int hoy, int mes})> visitasDeMiPagina(String slug) async {
    const vacio = (hoy: 0, mes: 0);
    final cliente = _clienteActivo();
    final buscado = slug.trim().toLowerCase();
    if (cliente == null || cliente.auth.currentUser == null || buscado.isEmpty) {
      return vacio;
    }
    try {
      final respuesta = await cliente.rpc(
        'visitas_de_mi_pagina',
        params: {'p_slug': buscado},
      );
      if (respuesta is! List || respuesta.isEmpty || respuesta.first is! Map) {
        return vacio;
      }
      final fila = Map<String, dynamic>.from(respuesta.first as Map);
      return (hoy: _entero(fila['hoy']) ?? 0, mes: _entero(fila['mes']) ?? 0);
    } catch (_) {
      return vacio;
    }
  }

  Future<TiendaPublica?> buscarPorSlug(String slug) async {
    try {
      final cliente = _clienteActivo();
      if (cliente == null) return null;
      final buscado = slug.trim().toLowerCase();
      if (buscado.isEmpty) return null;

      List<dynamic> filas;
      try {
        filas = await cliente
            .from('tienda_publica')
            .select(
              'id, nombre, slug, whatsapp, mensaje_publico, moneda, apariencia, logo_url, alias_cobro, facebook_url, instagram_url, maps_url, latitud, longitud, horario',
            )
            .eq('slug', buscado)
            .limit(1)
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        try {
          filas = await cliente
              .from('tienda_publica')
              .select(
                'id, nombre, slug, whatsapp, mensaje_publico, moneda, apariencia, logo_url, alias_cobro, facebook_url, instagram_url, maps_url',
              )
              .eq('slug', buscado)
              .limit(1)
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          try {
            filas = await cliente
                .from('tienda_publica')
                .select(
                  'id, nombre, slug, whatsapp, mensaje_publico, moneda, apariencia, logo_url, alias_cobro',
                )
                .eq('slug', buscado)
                .limit(1)
                .timeout(const Duration(seconds: 15));
          } catch (_) {
            try {
              filas = await cliente
                  .from('tienda_publica')
                  .select(
                    'id, nombre, slug, whatsapp, mensaje_publico, moneda, apariencia, logo_url',
                  )
                  .eq('slug', buscado)
                  .limit(1)
                  .timeout(const Duration(seconds: 15));
            } catch (_) {
              try {
                filas = await cliente
                    .from('tienda_publica')
                    .select(
                      'id, nombre, slug, whatsapp, mensaje_publico, moneda',
                    )
                    .eq('slug', buscado)
                    .limit(1)
                    .timeout(const Duration(seconds: 15));
              } catch (_) {
                filas = await cliente
                    .from('tienda_publica')
                    .select('id, nombre, slug, whatsapp, mensaje_publico')
                    .eq('slug', buscado)
                    .limit(1)
                    .timeout(const Duration(seconds: 15));
              }
            }
          }
        }
      }
      if (filas.isEmpty) return null;
      return _tiendaDesde(filas.first);
    } catch (_) {
      return null;
    }
  }

  Future<List<ProductoTiendaPublica>> productosDe(String negocioId) async {
    try {
      final cliente = _clienteActivo();
      if (cliente == null) return const [];
      final id = negocioId.trim();
      if (id.isEmpty) return const [];

      List<dynamic> filas;
      var traeDescripcion = true;
      try {
        filas = await cliente
            .from('tienda_publica_productos')
            .select(
              'negocio_id, id, nombre, precio_venta, stock, descripcion, categorias, fotos',
            )
            .eq('negocio_id', id)
            .order('nombre')
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        traeDescripcion = false;
        filas = await cliente
            .from('tienda_publica_productos')
            .select('negocio_id, id, nombre, precio_venta, stock, descripcion')
            .eq('negocio_id', id)
            .order('nombre')
            .timeout(const Duration(seconds: 15));
      }
      final productos = [
        for (final fila in filas)
          if (_productoDesde(fila) case final producto?) producto,
      ];
      if (!traeDescripcion) {
        return _completarDescripciones(cliente, productos);
      }
      return productos;
    } catch (_) {
      return const [];
    }
  }

  Future<List<VarianteTiendaPublica>> variantesDe(String negocioId) async {
    try {
      final cliente = _clienteActivo();
      if (cliente == null) return const [];
      final id = negocioId.trim();
      if (id.isEmpty) return const [];
      final filas = await cliente
          .from('tienda_publica_variantes')
          .select('producto_id, id, nombre, precio_venta, stock')
          .eq('negocio_id', id)
          .order('nombre')
          .timeout(const Duration(seconds: 15));
      return [
        for (final fila in filas)
          if (_varianteDesde(fila) case final variante?) variante,
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<FotoTiendaPublica>> fotosDe(String negocioId) async {
    try {
      final cliente = _clienteActivo();
      if (cliente == null) return const [];
      final id = negocioId.trim();
      if (id.isEmpty) return const [];
      final filas = await cliente
          .from('tienda_publica_fotos')
          .select('producto_id, variante, url, orden')
          .eq('negocio_id', id)
          .order('orden')
          .timeout(const Duration(seconds: 15));
      return [
        for (final fila in filas)
          if (_fotoDesde(fila) case final foto?) foto,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Deja el pedido de un visitante en la base. El precio lo pone el servidor.
  Future<String> crearPedido({
    required String slug,
    required String nombre,
    required String telefono,
    required List<Map<String, dynamic>> lineas,
  }) async {
    final cliente = _clienteActivo();
    if (cliente == null) {
      throw StateError('La página no está conectada. Probá de nuevo.');
    }
    final respuesta = await cliente.rpc(
      'crear_pedido_tienda',
      params: {
        'p_slug': slug.trim().toLowerCase(),
        'p_nombre': nombre.trim(),
        'p_telefono': telefono.trim(),
        'p_lineas': lineas,
      },
    ).timeout(const Duration(seconds: 20));
    final id = _texto(respuesta);
    if (id.isEmpty) {
      throw StateError('No se pudo guardar el pedido. Probá de nuevo.');
    }
    return id;
  }

  /// Sube el comprobante al depósito privado y anota la ruta en el pedido.
  /// El alias no viaja: ya se leyó de la vista. El precio lo fijó el servidor.
  Future<void> subirComprobante({
    required String negocioId,
    required String pedidoId,
    required Uint8List bytes,
  }) async {
    final cliente = _clienteActivo();
    if (cliente == null) {
      throw StateError('La página no está conectada. Probá de nuevo.');
    }
    final negocio = negocioId.trim().toLowerCase();
    final pedido = pedidoId.trim().toLowerCase();
    if (negocio.isEmpty || pedido.isEmpty || bytes.isEmpty) {
      throw StateError('No se pudo leer el comprobante.');
    }
    final ruta = '$negocio/comprobantes/$pedido.jpg';
    try {
      await cliente.storage
          .from('comprobantes')
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          )
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      final texto = error.toString().toLowerCase();
      final yaEstaba = texto.contains('already exists') ||
          texto.contains('duplicate') ||
          texto.contains('409');
      if (!yaEstaba) rethrow;
    }
    await cliente.rpc(
      'registrar_comprobante_tienda',
      params: {'p_pedido': pedido, 'p_url': ruta},
    ).timeout(const Duration(seconds: 15));
  }

  /// Sube el logo del negocio y guarda su dirección pública.
  Future<String> subirLogo({
    required String negocioId,
    required Uint8List bytes,
  }) async {
    final cliente = _clienteActivo();
    if (cliente == null || cliente.auth.currentUser == null) {
      throw StateError('Iniciá sesión para subir el logo.');
    }
    final id = negocioId.trim();
    if (id.isEmpty || bytes.isEmpty) {
      throw StateError('No se pudo leer la imagen.');
    }
    final ruta = '$id/logo.jpg';
    await cliente.storage
        .from('productos')
        .uploadBinary(
          ruta,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        )
        .timeout(const Duration(seconds: 20));
    final url =
        '${cliente.storage.from('productos').getPublicUrl(ruta)}?v=${DateTime.now().millisecondsSinceEpoch}';
    await cliente
        .from('negocios')
        .update({'logo_url': url})
        .eq('id', id)
        .timeout(const Duration(seconds: 15));
    return url;
  }

  Future<void> quitarLogo(String negocioId) async {
    final cliente = _clienteActivo();
    if (cliente == null || cliente.auth.currentUser == null) {
      throw StateError('Iniciá sesión para quitar el logo.');
    }
    final id = negocioId.trim();
    if (id.isEmpty) return;
    try {
      await cliente.storage
          .from('productos')
          .remove(['$id/logo.jpg']).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Si el archivo ya no está, igual se borra la dirección.
    }
    await cliente
        .from('negocios')
        .update({'logo_url': null})
        .eq('id', id)
        .timeout(const Duration(seconds: 15));
  }

  Future<void> guardarConfig({
    required String negocioId,
    required String slug,
    required bool tiendaActiva,
    required String whatsapp,
    required String mensajePublico,
    required String aliasCobro,
    required String facebookUrl,
    required String instagramUrl,
    required String mapsUrl,
    double? latitud,
    double? longitud,
  }) async {
    final cliente = _clienteActivo();
    if (cliente == null || cliente.auth.currentUser == null) {
      throw StateError('Iniciá sesión para que el cambio llegue a la página.');
    }
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No hay un negocio para configurar.');
    }

    final cambios = <String, dynamic>{
      'slug': slug.trim().toLowerCase(),
      'tienda_activa': tiendaActiva,
      'whatsapp': whatsapp.trim(),
      'mensaje_publico': mensajePublico.trim(),
      'alias_cobro': aliasCobro.trim().isEmpty ? null : aliasCobro.trim(),
      'facebook_url': facebookUrl.trim().isEmpty ? null : facebookUrl.trim(),
      'instagram_url': instagramUrl.trim().isEmpty ? null : instagramUrl.trim(),
      'maps_url': mapsUrl.trim().isEmpty ? null : mapsUrl.trim(),
      'latitud': latitud,
      'longitud': longitud,
    };
    List<dynamic> filas;
    try {
      filas = await cliente
          .from('negocios')
          .update(cambios)
          .eq('id', id)
          .select('id, tienda_activa')
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      final texto = error.toString().toLowerCase();
      var quito = false;
      if (texto.contains('alias_cobro')) {
        cambios.remove('alias_cobro');
        quito = true;
      }
      if (texto.contains('facebook_url') ||
          texto.contains('instagram_url') ||
          texto.contains('maps_url') ||
          texto.contains('latitud') ||
          texto.contains('longitud')) {
        cambios.remove('facebook_url');
        cambios.remove('instagram_url');
        cambios.remove('maps_url');
        cambios.remove('latitud');
        cambios.remove('longitud');
        quito = true;
      }
      if (!quito) rethrow;
      filas = await cliente
          .from('negocios')
          .update(cambios)
          .eq('id', id)
          .select('id, tienda_activa')
          .timeout(const Duration(seconds: 15));
    }
    if (filas.isEmpty) {
      throw StateError(
        'La página no se actualizó. Volvé a iniciar sesión e intentá de nuevo.',
      );
    }
  }
}

/// La vista pública puede no traer `descripcion` hasta aplicar 0004.
/// Un select a `productos` solo completa el texto si el rol anon lo permite.
Future<List<ProductoTiendaPublica>> _completarDescripciones(
  SupabaseClient cliente,
  List<ProductoTiendaPublica> productos,
) async {
  if (productos.isEmpty) return productos;
  try {
    final filas = await cliente
        .from('productos')
        .select('id, descripcion')
        .inFilter('id', [
      for (final producto in productos) producto.id
    ]).timeout(const Duration(seconds: 15));
    final textos = <String, String>{
      for (final fila in filas) _texto(fila['id']): _texto(fila['descripcion']),
    };
    if (textos.isEmpty) return productos;
    return [
      for (final producto in productos)
        ProductoTiendaPublica(
          negocioId: producto.negocioId,
          id: producto.id,
          nombre: producto.nombre,
          precioVenta: producto.precioVenta,
          stock: producto.stock,
          descripcion: textos[producto.id] ?? '',
        ),
    ];
  } catch (_) {
    return productos;
  }
}

SupabaseClient? _clienteActivo() {
  if (!SupabaseListo.estaConfigurado) return null;
  return SupabaseListo.cliente;
}

TiendaPublica? _tiendaDesde(Map<String, dynamic> fila) {
  final id = _texto(fila['id']);
  final nombre = _texto(fila['nombre']);
  final slug = _texto(fila['slug']);
  final whatsapp = _texto(fila['whatsapp']);
  if (id.isEmpty || nombre.isEmpty || slug.isEmpty || whatsapp.isEmpty) {
    return null;
  }
  return TiendaPublica(
    id: id,
    nombre: nombre,
    slug: slug,
    whatsapp: whatsapp,
    mensajePublico: _texto(fila['mensaje_publico']),
    moneda: codigoMoneda(_texto(fila['moneda'])),
    apariencia: AparienciaTienda.desde(fila['apariencia']),
    diseno: _disenoPublico(fila),
    logoUrl: _texto(fila['logo_url']),
    aliasCobro: _texto(fila['alias_cobro']),
    facebookUrl: _texto(fila['facebook_url']),
    instagramUrl: _texto(fila['instagram_url']),
    mapsUrl: _texto(fila['maps_url']),
    latitud: _punto(fila['latitud'], fila['longitud'])?.lat,
    longitud: _punto(fila['latitud'], fila['longitud'])?.lng,
    horario: _texto(fila['horario']),
  );
}

ProductoTiendaPublica? _productoDesde(Map<String, dynamic> fila) {
  final negocioId = _texto(fila['negocio_id']);
  final id = _texto(fila['id']);
  final nombre = _texto(fila['nombre']);
  final precioVenta = _double(fila['precio_venta']);
  final stock = _entero(fila['stock']);
  if (negocioId.isEmpty ||
      id.isEmpty ||
      nombre.isEmpty ||
      precioVenta == null ||
      stock == null ||
      stock <= 0) {
    return null;
  }
  return ProductoTiendaPublica(
    negocioId: negocioId,
    id: id,
    nombre: nombre,
    precioVenta: precioVenta,
    stock: stock,
    descripcion: _texto(fila['descripcion']),
    categorias: _textos(fila['categorias']),
    fotos: _textos(fila['fotos']),
  );
}

VarianteTiendaPublica? _varianteDesde(Map<String, dynamic> fila) {
  final productoId = _texto(fila['producto_id']);
  final id = _texto(fila['id']);
  final nombre = _texto(fila['nombre']);
  final precio = _double(fila['precio_venta']);
  final stock = _entero(fila['stock']);
  if (productoId.isEmpty ||
      id.isEmpty ||
      nombre.isEmpty ||
      precio == null ||
      precio <= 0 ||
      stock == null ||
      stock < 0) {
    return null;
  }
  return VarianteTiendaPublica(
    productoId: productoId,
    id: id,
    nombre: nombre,
    precioVenta: precio,
    stock: stock,
  );
}

FotoTiendaPublica? _fotoDesde(Map<String, dynamic> fila) {
  final productoId = _texto(fila['producto_id']);
  final url = _texto(fila['url']);
  if (productoId.isEmpty || url.isEmpty) return null;
  return FotoTiendaPublica(
    productoId: productoId,
    url: url,
    variante: _texto(fila['variante']),
    orden: _entero(fila['orden']) ?? 0,
  );
}

DisenoTienda _disenoPublico(Map<String, dynamic> fila) {
  final rubros = _textos(fila['rubros']);
  final diseno = DisenoTienda.desdeApariencia(
    fila['apariencia'],
    rubros: rubros,
  );
  if (diseno.plantillaId != 'general') return diseno;
  final tipo = _texto(fila['tipo_tienda']).toLowerCase();
  if (tipo == 'menú' || tipo == 'menu') return DisenoTienda.desdeRubro('gastronomia');
  return diseno;
}

String _texto(Object? valor) => valor?.toString().trim() ?? '';

List<String> _textos(Object? valor) {
  if (valor is! List) return const [];
  final vistos = <String>{};
  final lista = <String>[];
  for (final item in valor) {
    final texto = item?.toString().trim() ?? '';
    if (texto.isEmpty || !vistos.add(texto.toLowerCase())) continue;
    lista.add(texto);
  }
  return lista;
}

({double lat, double lng})? _punto(Object? latitud, Object? longitud) {
  final lat = _double(latitud);
  final lng = _double(longitud);
  if (lat == null || lng == null) return null;
  if (lat == 0 && lng == 0) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat: lat, lng: lng);
}

double? _double(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse(_texto(valor));
}

int? _entero(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(_texto(valor));
}
