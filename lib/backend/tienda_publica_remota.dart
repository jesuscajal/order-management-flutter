import 'package:supabase_flutter/supabase_flutter.dart';

import 'remoto_comun.dart';
import 'supabase_cliente.dart';

class TiendaPublica {
  const TiendaPublica({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.whatsapp,
    required this.mensajePublico,
  });

  final String id;
  final String nombre;
  final String slug;
  final String whatsapp;
  final String mensajePublico;
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

  Future<TiendaPublica?> buscarPorSlug(String slug) async {
    try {
      final cliente = _clienteActivo();
      if (cliente == null) return null;
      final buscado = slug.trim().toLowerCase();
      if (buscado.isEmpty) return null;

      final filas = await cliente
          .from('tienda_publica')
          .select('id, nombre, slug, whatsapp, mensaje_publico')
          .eq('slug', buscado)
          .limit(1)
          .timeout(const Duration(seconds: 15));
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

  Future<void> guardarConfig({
    required String negocioId,
    required String slug,
    required bool tiendaActiva,
    required String whatsapp,
    required String mensajePublico,
  }) async {
    try {
      final cliente = _clienteActivo();
      if (cliente == null || cliente.auth.currentUser == null) return;
      final id = negocioId.trim();
      if (id.isEmpty) return;

      await cliente
          .from('negocios')
          .update({
            'slug': slug.trim().toLowerCase(),
            'tienda_activa': tiendaActiva,
            'whatsapp': whatsapp.trim(),
            'mensaje_publico': mensajePublico.trim(),
          })
          .eq('id', id)
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar la página: $error');
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
        .inFilter('id', [for (final producto in productos) producto.id])
        .timeout(const Duration(seconds: 15));
    final textos = <String, String>{
      for (final fila in filas)
        _texto(fila['id']): _texto(fila['descripcion']),
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

double? _double(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse(_texto(valor));
}

int? _entero(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(_texto(valor));
}
