import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'ids_remotos.dart';
import 'remoto_comun.dart';
import 'stock_remoto.dart';

/// Nombre y precio de una variante. El stock de la variante no tiene columna
/// en `variantes_producto`: queda en la ficha del teléfono.
class VarianteParaNube {
  const VarianteParaNube({required this.etiqueta, this.precio});

  final String etiqueta;
  final double? precio;
}

class UnidadParaNube {
  const UnidadParaNube({required this.codigo, required this.estado});

  final String codigo;
  final String estado;
}

/// Foto ya leída en el teléfono. [variante] vacía es una foto del producto.
class FotoParaNube {
  const FotoParaNube({required this.base64, this.variante = ''});

  final String base64;
  final String variante;
}

/// Ficha, descripción, variantes, series, categorías y fotos.
///
/// Las fotos se suben al bucket `productos` y la tabla guarda la URL pública.
class CatalogoRemoto {
  const CatalogoRemoto._();

  /// Lo registra main para que la ficha pueda leer el nombre sin tocar Drift
  /// desde la pantalla.
  static Future<({String nombre, double compra, double venta})?> Function(
    int productoId,
  )? leerProducto;

  static Future<void> publicarDescripcion({
    required int productoLocalId,
    required String descripcion,
  }) async {
    if (!RemotoComun.activo) return;
    try {
      final supabase = RemotoComun.cliente;
      final negocioId = await RemotoComun.negocioId();
      if (supabase == null || negocioId == null) return;
      final uuid = await const IdsRemotos()
          .leer(IdsRemotos.producto, '$productoLocalId');
      if (uuid == null) return;
      await supabase.from('productos').update({
        'descripcion': descripcion.trim(),
      }).eq('id', uuid);
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar la descripción en la nube: $error');
    }
  }

  static Future<void> publicarVidriera({
    required int productoLocalId,
    required String descripcion,
    required List<FotoParaNube> fotos,
  }) async {
    if (!RemotoComun.activo) return;
    try {
      final supabase = RemotoComun.cliente;
      final negocioId = await RemotoComun.negocioId();
      if (supabase == null || negocioId == null) return;
      final uuid = await const IdsRemotos()
          .leer(IdsRemotos.producto, '$productoLocalId');
      if (uuid == null) {
        if (descripcion.trim().isNotEmpty || fotos.isNotEmpty) {
          RemotoComun.aviso(
            'Las fotos quedaron en el teléfono. El producto todavía no está en la nube.',
          );
        }
        return;
      }
      await supabase.from('productos').update({
        'descripcion': descripcion.trim(),
      }).eq('id', uuid);
      await _reemplazarFotos(
        supabase: supabase,
        negocioId: negocioId,
        productoLocalId: productoLocalId,
        productoId: uuid,
        fotos: fotos,
      );
    } catch (error) {
      RemotoComun.aviso('No se pudieron guardar las fotos en la nube: $error');
    }
  }

  static Future<void> publicarFicha({
    required int productoLocalId,
    String? nombre,
    double precioCompra = 0,
    double precioVenta = 0,
    required String categoria,
    List<String> categorias = const [],
    required bool visibleEnTienda,
    required int umbral,
    required bool controlaSerie,
    required List<VarianteParaNube> variantes,
    required List<UnidadParaNube> unidades,
    Map<String, String> atributos = const {},
    String? descripcion,
  }) async {
    if (!RemotoComun.activo) return;
    try {
      final supabase = RemotoComun.cliente;
      final negocioId = await RemotoComun.negocioId();
      if (supabase == null || negocioId == null) return;
      var nombreListo = nombre?.trim() ?? '';
      var compra = precioCompra;
      var venta = precioVenta;
      if (nombreListo.isEmpty) {
        final leido = await leerProducto?.call(productoLocalId);
        if (leido == null || leido.nombre.trim().isEmpty) {
          RemotoComun.aviso(
            'La ficha quedó en el teléfono. El producto todavía no está en la nube.',
          );
          return;
        }
        nombreListo = leido.nombre.trim();
        compra = leido.compra;
        venta = leido.venta;
      }
      final uuid = await StockRemoto.asegurarProducto(
        DatosProductoRemoto(
          localId: productoLocalId,
          nombre: nombreListo,
          precioCompra: compra,
          precioVenta: venta,
          pisarCompra: true,
          pisarVenta: true,
          pisarNombre: true,
          descripcion: descripcion,
          visibleEnTienda: visibleEnTienda,
          activo: true,
          umbral: umbral < 0 ? 0 : umbral,
          controlaSerie: controlaSerie,
        ),
      );
      if (uuid == null) return;
      final nombres = _nombresCategoria(categoria, categorias);
      final categoriaId = await _categoriaId(
        negocioId: negocioId,
        nombre: nombres.isEmpty ? '' : nombres.first,
      );
      await supabase.from('productos').update({
        'categoria_id': categoriaId,
        'visible_en_tienda': visibleEnTienda,
        'umbral_stock_bajo': umbral < 0 ? 0 : umbral,
        'controla_serie': controlaSerie,
        'activo': true,
      }).eq('id', uuid);
      await _reemplazarCategorias(
        negocioId: negocioId,
        productoId: uuid,
        nombres: nombres,
      );
      await _variantes(
        negocioId: negocioId,
        productoLocalId: productoLocalId,
        productoId: uuid,
        variantes: variantes,
      );
      await _unidades(
        negocioId: negocioId,
        productoLocalId: productoLocalId,
        productoId: uuid,
        unidades: unidades,
      );
      await _atributos(
        negocioId: negocioId,
        productoId: uuid,
        valores: atributos,
      );
    } catch (error) {
      RemotoComun.aviso('No se pudo guardar la ficha en la nube: $error');
    }
  }

  static Future<void> publicarCategorias(List<String> nombres) async {
    if (!RemotoComun.activo) return;
    try {
      final supabase = RemotoComun.cliente;
      final negocioId = await RemotoComun.negocioId();
      if (supabase == null || negocioId == null) return;
      const ids = IdsRemotos();
      final conservados = <String>{};
      for (var i = 0; i < nombres.length; i++) {
        final nombre = nombres[i].trim();
        if (nombre.isEmpty) continue;
        final uuid = await _upsertCategoria(
          negocioId: negocioId,
          nombre: nombre,
          orden: i,
        );
        if (uuid == null) continue;
        conservados.add(uuid);
        await ids.guardar(
          IdsRemotos.categoria,
          IdsRemotos.claveCategoria(nombre),
          uuid,
        );
      }
      final mapa = await ids.de(IdsRemotos.categoria);
      for (final entrada in mapa.entries) {
        if (conservados.contains(entrada.value)) continue;
        try {
          await supabase.from('categorias').delete().eq('id', entrada.value);
        } catch (error) {
          RemotoComun.aviso('No se pudo borrar una categoría: $error');
          continue;
        }
        await ids.olvidar(IdsRemotos.categoria, entrada.key);
      }
    } catch (error) {
      RemotoComun.aviso('No se pudieron guardar las categorías: $error');
    }
  }

  static List<String> _nombresCategoria(
    String categoria,
    List<String> categorias,
  ) {
    final vistas = <String>{};
    final lista = <String>[];
    void sumar(String nombre) {
      final limpio = nombre.trim();
      if (limpio.isEmpty) return;
      if (!vistas.add(limpio.toLowerCase())) return;
      lista.add(limpio);
    }

    for (final nombre in categorias) {
      sumar(nombre);
    }
    sumar(categoria);
    return lista;
  }

  static Future<void> _reemplazarCategorias({
    required String negocioId,
    required Object productoId,
    required List<String> nombres,
  }) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return;
    final deseados = <String>{};
    for (var i = 0; i < nombres.length; i++) {
      final id = await _upsertCategoria(
        negocioId: negocioId,
        nombre: nombres[i],
        orden: i,
      );
      if (id != null) deseados.add(id);
    }
    final actuales = await supabase
        .from('productos_categorias')
        .select('categoria_id')
        .eq('producto_id', productoId);
    for (final fila in actuales) {
      final id = textoRemoto(fila['categoria_id']);
      if (id.isEmpty || deseados.contains(id)) continue;
      await supabase
          .from('productos_categorias')
          .delete()
          .eq('producto_id', productoId)
          .eq('categoria_id', id);
    }
    for (final id in deseados) {
      await supabase.from('productos_categorias').upsert({
        'producto_id': productoId,
        'categoria_id': id,
        'negocio_id': negocioId,
      });
    }
  }

  static Future<void> _reemplazarFotos({
    required SupabaseClient supabase,
    required String negocioId,
    required int productoLocalId,
    required Object productoId,
    required List<FotoParaNube> fotos,
  }) async {
    final filas = <Map<String, dynamic>>[];
    final rutas = <String>[];
    var orden = 0;
    for (final foto in fotos) {
      final bytes = _bytesFoto(foto.base64);
      if (bytes == null) continue;
      final variante = foto.variante.trim();
      String? varianteId;
      if (variante.isNotEmpty) {
        varianteId = await _varianteId(
          supabase: supabase,
          productoLocalId: productoLocalId,
          productoId: productoId,
          nombre: variante,
        );
        if (varianteId == null) {
          RemotoComun.aviso(
            'La foto de "$variante" quedó en el teléfono porque esa variante todavía no está en la nube.',
          );
          continue;
        }
      }
      final ruta = '$negocioId/$productoId/${_archivoFoto(orden, variante)}';
      await supabase.storage.from('productos').uploadBinary(
            ruta,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final url = supabase.storage.from('productos').getPublicUrl(ruta);
      filas.add({
        'negocio_id': negocioId,
        'producto_id': productoId,
        'variante_id': varianteId,
        'url': url,
        'orden': orden,
      });
      rutas.add(ruta);
      orden++;
    }

    final carpeta = '$negocioId/$productoId';
    try {
      final existentes =
          await supabase.storage.from('productos').list(path: carpeta);
      final sobran = [
        for (final item in existentes)
          if (!rutas.contains('$carpeta/${item.name}')) '$carpeta/${item.name}',
      ];
      if (sobran.isNotEmpty) {
        await supabase.storage.from('productos').remove(sobran);
      }
    } catch (_) {
      // Si no se puede listar, las filas nuevas igual reemplazan a las viejas.
    }

    await supabase.from('fotos_producto').delete().eq('producto_id', productoId);
    if (filas.isNotEmpty) {
      await supabase.from('fotos_producto').insert(filas);
    }
    String? urlGeneral;
    for (final fila in filas) {
      if (fila['variante_id'] != null) continue;
      final url = fila['url'];
      if (url is String && url.isNotEmpty) {
        urlGeneral = url;
        break;
      }
    }
    await supabase.from('productos').update({
      'imagen_url': urlGeneral,
    }).eq('id', productoId);
  }

  static Future<String?> _varianteId({
    required SupabaseClient supabase,
    required int productoLocalId,
    required Object productoId,
    required String nombre,
  }) async {
    const ids = IdsRemotos();
    final mapeada = await ids.leer(
      IdsRemotos.variante,
      IdsRemotos.claveVariante(productoLocalId, nombre),
    );
    if (mapeada != null) return mapeada;
    final filas = await supabase
        .from('variantes_producto')
        .select('id, nombre')
        .eq('producto_id', productoId);
    for (final fila in filas) {
      if (textoRemoto(fila['nombre']).toLowerCase() != nombre.toLowerCase()) {
        continue;
      }
      final id = textoRemoto(fila['id']);
      if (id.isEmpty) continue;
      await ids.guardar(
        IdsRemotos.variante,
        IdsRemotos.claveVariante(productoLocalId, nombre),
        id,
      );
      return id;
    }
    return null;
  }

  static Uint8List? _bytesFoto(String base64) {
    if (base64.isEmpty) return null;
    try {
      final bytes = base64Decode(base64);
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static String _archivoFoto(int orden, String variante) {
    final limpia = variante
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final sufijo = limpia.isEmpty ? 'general' : limpia;
    return '$orden-$sufijo.jpg';
  }

  static Future<String?> _categoriaId({
    required String negocioId,
    required String nombre,
  }) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return null;
    return _upsertCategoria(negocioId: negocioId, nombre: limpio, orden: 0);
  }

  static Future<String?> _upsertCategoria({
    required String negocioId,
    required String nombre,
    required int orden,
  }) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return null;
    const ids = IdsRemotos();
    final clave = IdsRemotos.claveCategoria(nombre);
    final mapeada = await ids.leer(IdsRemotos.categoria, clave);
    if (mapeada != null) {
      await supabase.from('categorias').update({
        'nombre': nombre,
        'orden': orden,
        'activo': true,
      }).eq('id', mapeada);
      return mapeada;
    }
    final filas = await supabase
        .from('categorias')
        .select('id, nombre')
        .eq('negocio_id', negocioId);
    for (final fila in filas) {
      if (textoRemoto(fila['nombre']).toLowerCase() != clave) continue;
      final id = textoRemoto(fila['id']);
      if (id.isEmpty) continue;
      await ids.guardar(IdsRemotos.categoria, clave, id);
      await supabase.from('categorias').update({
        'nombre': nombre,
        'orden': orden,
        'activo': true,
      }).eq('id', id);
      return id;
    }
    final creada = await supabase
        .from('categorias')
        .insert({
          'negocio_id': negocioId,
          'nombre': nombre,
          'orden': orden,
          'activo': true,
        })
        .select('id')
        .single();
    final id = textoRemoto(creada['id']);
    if (id.isEmpty) return null;
    await ids.guardar(IdsRemotos.categoria, clave, id);
    return id;
  }

  static Future<void> _variantes({
    required String negocioId,
    required int productoLocalId,
    required Object productoId,
    required List<VarianteParaNube> variantes,
  }) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return;
    const ids = IdsRemotos();
    final conservadas = <String>{};
    for (final variante in variantes) {
      final nombre = variante.etiqueta.trim();
      if (nombre.isEmpty) continue;
      final clave = IdsRemotos.claveVariante(productoLocalId, nombre);
      final precio = variante.precio;
      final datos = <String, dynamic>{
        'nombre': nombre,
        'activo': true,
      };
      if (precio != null && !precio.isNaN && !precio.isInfinite && precio >= 0) {
        datos['precio_venta'] = precio;
      }
      var uuid = await ids.leer(IdsRemotos.variante, clave);
      if (uuid == null) {
        final filas = await supabase
            .from('variantes_producto')
            .select('id, nombre')
            .eq('producto_id', productoId);
        for (final fila in filas) {
          if (textoRemoto(fila['nombre']).toLowerCase() !=
              nombre.toLowerCase()) {
            continue;
          }
          final id = textoRemoto(fila['id']);
          if (id.isEmpty) continue;
          uuid = id;
          break;
        }
      }
      if (uuid != null) {
        await supabase.from('variantes_producto').update(datos).eq('id', uuid);
      } else {
        final creada = await supabase
            .from('variantes_producto')
            .insert({
              ...datos,
              'negocio_id': negocioId,
              'producto_id': productoId,
            })
            .select('id')
            .single();
        final id = textoRemoto(creada['id']);
        if (id.isEmpty) continue;
        uuid = id;
      }
      await ids.guardar(IdsRemotos.variante, clave, uuid);
      conservadas.add(uuid);
    }
    final mapa = await ids.de(IdsRemotos.variante);
    final prefijo = '$productoLocalId|';
    for (final entrada in mapa.entries) {
      if (!entrada.key.startsWith(prefijo)) continue;
      if (conservadas.contains(entrada.value)) continue;
      try {
        await supabase.from('variantes_producto').delete().eq('id', entrada.value);
      } catch (error) {
        RemotoComun.aviso('No se pudo borrar una variante: $error');
        continue;
      }
      await ids.olvidar(IdsRemotos.variante, entrada.key);
    }
  }

  static Future<void> _unidades({
    required String negocioId,
    required int productoLocalId,
    required Object productoId,
    required List<UnidadParaNube> unidades,
  }) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return;
    const ids = IdsRemotos();
    const estados = {'disponible', 'reservada', 'vendida', 'baja'};
    final conservadas = <String>{};
    for (final unidad in unidades) {
      final codigo = unidad.codigo.trim();
      if (codigo.isEmpty) continue;
      final estado = estados.contains(unidad.estado) ? unidad.estado : 'disponible';
      final clave = IdsRemotos.claveUnidad(productoLocalId, codigo);
      final datos = <String, dynamic>{
        'codigo': codigo,
        'estado': estado,
        'producto_id': productoId,
      };
      var uuid = await ids.leer(IdsRemotos.unidad, clave);
      if (uuid == null) {
        final filas = await supabase
            .from('unidades_producto')
            .select('id, codigo')
            .eq('negocio_id', negocioId)
            .eq('producto_id', productoId);
        for (final fila in filas) {
          if (textoRemoto(fila['codigo']).toLowerCase() != codigo.toLowerCase()) {
            continue;
          }
          final id = textoRemoto(fila['id']);
          if (id.isEmpty) continue;
          uuid = id;
          break;
        }
      }
      if (uuid != null) {
        await supabase.from('unidades_producto').update(datos).eq('id', uuid);
      } else {
        final creada = await supabase
            .from('unidades_producto')
            .insert({
              ...datos,
              'negocio_id': negocioId,
            })
            .select('id')
            .single();
        final id = textoRemoto(creada['id']);
        if (id.isEmpty) continue;
        uuid = id;
      }
      await ids.guardar(IdsRemotos.unidad, clave, uuid);
      conservadas.add(uuid);
    }
    final mapa = await ids.de(IdsRemotos.unidad);
    final prefijo = '$productoLocalId|';
    for (final entrada in mapa.entries) {
      if (!entrada.key.startsWith(prefijo)) continue;
      if (conservadas.contains(entrada.value)) continue;
      try {
        await supabase.from('unidades_producto').delete().eq('id', entrada.value);
      } catch (error) {
        RemotoComun.aviso('No se pudo borrar una serie: $error');
        continue;
      }
      await ids.olvidar(IdsRemotos.unidad, entrada.key);
    }
  }

  static Future<void> _atributos({
    required String negocioId,
    required Object productoId,
    required Map<String, String> valores,
  }) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null || valores.isEmpty) return;
    for (final entrada in valores.entries) {
      final nombre = entrada.key.trim();
      if (nombre.isEmpty) continue;
      try {
        final atributoId = await _atributoId(negocioId, nombre);
        if (atributoId == null) continue;
        final filas = await supabase
            .from('atributos_producto')
            .select('id')
            .eq('atributo_id', atributoId)
            .eq('producto_id', productoId)
            .limit(1);
        if (filas.isEmpty) {
          await supabase.from('atributos_producto').insert({
            'negocio_id': negocioId,
            'atributo_id': atributoId,
            'producto_id': productoId,
            'valor': entrada.value.trim(),
          });
        } else {
          final id = filas.first['id'];
          if (id == null) continue;
          await supabase.from('atributos_producto').update({
            'valor': entrada.value.trim(),
          }).eq('id', id);
        }
      } catch (error) {
        RemotoComun.aviso('No se pudo guardar un atributo: $error');
      }
    }
  }

  static Future<String?> _atributoId(String negocioId, String nombre) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return null;
    final filas = await supabase
        .from('atributos')
        .select('id, nombre')
        .eq('negocio_id', negocioId);
    for (final fila in filas) {
      if (textoRemoto(fila['nombre']).toLowerCase() != nombre.toLowerCase()) {
        continue;
      }
      final id = textoRemoto(fila['id']);
      if (id.isNotEmpty) return id;
    }
    final creada = await supabase
        .from('atributos')
        .insert({
          'negocio_id': negocioId,
          'nombre': nombre,
          'tipo': 'texto',
        })
        .select('id')
        .single();
    final id = textoRemoto(creada['id']);
    return id.isEmpty ? null : id;
  }
}
