import 'package:drift/drift.dart';

import '../backend/catalogo_remoto.dart';
import '../backend/ids_remotos.dart';
import '../backend/remoto_comun.dart';
import '../backend/stock_remoto.dart';
import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/pedido_repository.dart';

/// Pasa costos, ventas, pedidos, deudas y capital a otra moneda.
///
/// Primero cambia el teléfono. Después copia esos importes a Supabase,
/// que es lo que muestra la página web del negocio.
class ConvertirMoneda {
  const ConvertirMoneda._();

  static double dinero(double valor, double factor) {
    if (!valor.isFinite || valor == 0) return 0;
    final convertido = valor * factor;
    if (!convertido.isFinite) return 0;
    return (convertido * 100).roundToDouble() / 100;
  }

  static Future<void> aplicar({
    required AppDatabase database,
    required double factor,
  }) async {
    if (!factor.isFinite || factor <= 0) {
      throw StateError('La cotización no es válida.');
    }
    if ((factor - 1).abs() < 0.0000001) return;

    const ampliacion = AmpliacionLocal();
    final copia = await ampliacion.copia();
    final productos = await database.select(database.productos).get();
    final pedidos = await database.select(database.pedidos).get();
    final capital = await database.select(database.movimientosCapital).get();

    await _convertirLocal(database, ampliacion, factor);
    try {
      await _subir(database, factor);
    } catch (error) {
      await _restaurarLocal(
        database,
        ampliacion,
        copia,
        productos,
        pedidos,
        capital,
      );
      throw StateError(
        'No se pudieron guardar los precios convertidos en Supabase. '
        'El teléfono quedó con los importes anteriores. $error',
      );
    }
  }

  static Future<void> _convertirLocal(
    AppDatabase database,
    AmpliacionLocal ampliacion,
    double factor,
  ) async {
    await database.transaction(() async {
      final productos = await database.select(database.productos).get();
      for (final producto in productos) {
        await (database.update(database.productos)
              ..where((tabla) => tabla.id.equals(producto.id)))
            .write(
          ProductosCompanion(
            precioCompra: Value(dinero(producto.precioCompra, factor)),
            precioVenta: Value(dinero(producto.precioVenta, factor)),
          ),
        );
      }
      final pedidos = await database.select(database.pedidos).get();
      for (final pedido in pedidos) {
        await (database.update(database.pedidos)
              ..where((tabla) => tabla.id.equals(pedido.id)))
            .write(
          PedidosCompanion(
            montoSenado: Value(dinero(pedido.montoSenado, factor)),
          ),
        );
      }
      final movimientos = await database.select(database.movimientosCapital).get();
      for (final movimiento in movimientos) {
        await (database.update(database.movimientosCapital)
              ..where((tabla) => tabla.id.equals(movimiento.id)))
            .write(
          MovimientosCapitalCompanion(
            monto: Value(dinero(movimiento.monto, factor)),
          ),
        );
      }
    });
    await ampliacion.convertirMontos((valor) => dinero(valor, factor));
  }

  static Future<void> _restaurarLocal(
    AppDatabase database,
    AmpliacionLocal ampliacion,
    String? copia,
    List<Producto> productos,
    List<Pedido> pedidos,
    List<MovimientosCapitalData> capital,
  ) async {
    await database.transaction(() async {
      for (final producto in productos) {
        await (database.update(database.productos)
              ..where((tabla) => tabla.id.equals(producto.id)))
            .write(
          ProductosCompanion(
            precioCompra: Value(producto.precioCompra),
            precioVenta: Value(producto.precioVenta),
          ),
        );
      }
      for (final pedido in pedidos) {
        await (database.update(database.pedidos)
              ..where((tabla) => tabla.id.equals(pedido.id)))
            .write(PedidosCompanion(montoSenado: Value(pedido.montoSenado)));
      }
      for (final movimiento in capital) {
        await (database.update(database.movimientosCapital)
              ..where((tabla) => tabla.id.equals(movimiento.id)))
            .write(MovimientosCapitalCompanion(monto: Value(movimiento.monto)));
      }
    });
    await ampliacion.restaurar(copia);
  }

  static Future<void> _subir(AppDatabase database, double factor) async {
    final supabase = RemotoComun.cliente;
    final negocioId = await RemotoComun.negocioId();
    if (supabase == null || negocioId == null) {
      throw StateError('No hay sesión para actualizar la página web.');
    }
    const ids = IdsRemotos();
    final productosLocales = await database.select(database.productos).get();
    final mapaProductos = await ids.de(IdsRemotos.producto);
    final tocados = <String>{};

    for (final producto in productosLocales) {
      final uuid = mapaProductos['${producto.id}'];
      if (uuid == null) {
        final creado = await StockRemoto.asegurarProducto(
          DatosProductoRemoto(
            localId: producto.id,
            nombre: producto.nombre,
            precioCompra: producto.precioCompra,
            precioVenta: producto.precioVenta,
            pisarCompra: true,
            pisarVenta: true,
          ),
        );
        if (creado != null) tocados.add('$creado');
        continue;
      }
      tocados.add(uuid);
      await supabase.from('productos').update({
        'precio_compra': producto.precioCompra,
        'precio_venta': producto.precioVenta,
      }).eq('id', uuid);
    }

    final doc = await const AmpliacionLocal().cargar();
    for (final entrada in doc.fichas.entries) {
      final ficha = entrada.value;
      if (ficha.variantes.isEmpty) continue;
      await CatalogoRemoto.publicarFicha(
        productoLocalId: entrada.key,
        categoria: ficha.todas.isEmpty ? '' : ficha.todas.first,
        categorias: ficha.todas,
        visibleEnTienda: ficha.visibleEnTienda,
        umbral: ficha.umbral,
        controlaSerie: ficha.unidades.isNotEmpty,
        variantes: [
          for (final variante in ficha.variantes)
            if (variante.etiqueta.trim().isNotEmpty)
              VarianteParaNube(
                etiqueta: variante.etiqueta,
                stock: variante.stock < 0 ? 0 : variante.stock,
                precio: variante.precio,
              ),
        ],
        unidades: [
          for (final unidad in ficha.unidades)
            if (unidad.codigo.trim().isNotEmpty)
              UnidadParaNube(codigo: unidad.codigo, estado: unidad.estado),
        ],
        atributos: ficha.atributos,
      );
    }

    final remotos = await supabase
        .from('productos')
        .select('id, precio_compra, precio_venta')
        .eq('negocio_id', negocioId);
    for (final fila in remotos) {
      final id = '${fila['id']}';
      if (id.isEmpty || tocados.contains(id)) continue;
      await supabase.from('productos').update({
        'precio_compra': dinero(_numero(fila['precio_compra']), factor),
        'precio_venta': dinero(_numero(fila['precio_venta']), factor),
      }).eq('id', id);
    }

    await _pedidos(database, factor, negocioId);
    await _capital(database, factor, negocioId);
    await _variantesSueltas(factor, negocioId, doc);
  }

  static Future<void> _pedidos(
    AppDatabase database,
    double factor,
    String negocioId,
  ) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return;
    final repo = PedidoRepository(database);
    final locales = await repo.listarPedidos();
    final metas = await const AmpliacionLocal().cargar();
    final mapa = await const IdsRemotos().de(IdsRemotos.pedido);
    final tocados = <String>{};

    for (final pedido in locales) {
      final uuid = mapa['${pedido.id}'];
      if (uuid == null) continue;
      tocados.add(uuid);
      await supabase.from('pedidos').update({
        'senia': pedido.montoSenado,
        'total': _total(pedido, metas.pedidos[pedido.id]),
      }).eq('id', uuid);
      final lineas = await supabase
          .from('productos_pedido')
          .select('id, precio_venta')
          .eq('pedido_id', uuid);
      for (final linea in lineas) {
        await supabase.from('productos_pedido').update({
          'precio_venta': dinero(_numero(linea['precio_venta']), factor),
        }).eq('id', linea['id']);
      }
    }

    final remotos = await supabase
        .from('pedidos')
        .select('id, senia, total')
        .eq('negocio_id', negocioId);
    for (final fila in remotos) {
      final id = '${fila['id']}';
      if (id.isEmpty || tocados.contains(id)) continue;
      await supabase.from('pedidos').update({
        'senia': dinero(_numero(fila['senia']), factor),
        'total': dinero(_numero(fila['total']), factor),
      }).eq('id', id);
      final lineas = await supabase
          .from('productos_pedido')
          .select('id, precio_venta')
          .eq('pedido_id', id);
      for (final linea in lineas) {
        await supabase.from('productos_pedido').update({
          'precio_venta': dinero(_numero(linea['precio_venta']), factor),
        }).eq('id', linea['id']);
      }
    }
  }

  static Future<void> _capital(
    AppDatabase database,
    double factor,
    String negocioId,
  ) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return;
    final locales = await database.select(database.movimientosCapital).get();
    final mapa = await const IdsRemotos().de(IdsRemotos.capital);
    final tocados = <String>{};
    for (final movimiento in locales) {
      final uuid = mapa['${movimiento.id}'];
      if (uuid == null) continue;
      tocados.add(uuid);
      await supabase.from('movimientos_capital').update({
        'monto': dinero(movimiento.monto, factor).abs(),
      }).eq('id', uuid);
    }
    final remotos = await supabase
        .from('movimientos_capital')
        .select('id, monto')
        .eq('negocio_id', negocioId);
    for (final fila in remotos) {
      final id = '${fila['id']}';
      if (id.isEmpty || tocados.contains(id)) continue;
      await supabase.from('movimientos_capital').update({
        'monto': dinero(_numero(fila['monto']), factor).abs(),
      }).eq('id', id);
    }
  }

  static Future<void> _variantesSueltas(
    double factor,
    String negocioId,
    DocumentoAmpliacion doc,
  ) async {
    final supabase = RemotoComun.cliente;
    if (supabase == null) return;
    final mapa = await const IdsRemotos().de(IdsRemotos.variante);
    final tocados = mapa.values.toSet();
    for (final entrada in doc.fichas.entries) {
      for (final variante in entrada.value.variantes) {
        final clave = IdsRemotos.claveVariante(entrada.key, variante.etiqueta);
        final uuid = mapa[clave];
        if (uuid == null || variante.precio == null) continue;
        tocados.add(uuid);
        await supabase.from('variantes_producto').update({
          'precio_venta': variante.precio,
        }).eq('id', uuid);
      }
    }
    final productos = await supabase
        .from('productos')
        .select('id')
        .eq('negocio_id', negocioId);
    final ids = [
      for (final fila in productos)
        if ('${fila['id']}'.isNotEmpty) fila['id'],
    ];
    if (ids.isEmpty) return;
    final variantes = await supabase
        .from('variantes_producto')
        .select('id, precio_venta')
        .inFilter('producto_id', ids);
    for (final fila in variantes) {
      final id = '${fila['id']}';
      if (id.isEmpty || tocados.contains(id) || fila['precio_venta'] == null) {
        continue;
      }
      await supabase.from('variantes_producto').update({
        'precio_venta': dinero(_numero(fila['precio_venta']), factor),
      }).eq('id', id);
    }
  }

  static double _total(PedidoResumen pedido, MetaPedido? meta) {
    var bruto = 0.0;
    if (meta != null && meta.lineas.isNotEmpty) {
      for (final linea in meta.lineas) {
        bruto += linea.precio * linea.cantidad;
      }
    } else {
      for (final item in pedido.items) {
        final precio = meta?.precioDe(item.productoId) ?? item.precioVenta;
        bruto += precio * item.cantidad;
      }
    }
    final descuento = meta?.descuentoMonto ?? 0;
    final neto = bruto - (descuento < 0 ? 0 : descuento);
    if (neto <= 0) return 0;
    return (neto * 100).roundToDouble() / 100;
  }

  static double _numero(Object? valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse('$valor') ?? 0;
  }
}
