import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/ampliacion_local.dart';
import '../data/app_database.dart';
import '../data/capital_repository.dart';
import 'capital_remoto.dart';
import '../data/pedido_repository.dart';
import '../data/stock_repository.dart';
import '../data/vidriera_local.dart';
import '../services/negocio_local.dart';
import 'catalogo_remoto.dart';
import 'clientes_remoto.dart';
import 'ids_remotos.dart';
import 'negocio_remoto.dart';
import 'remoto_comun.dart';
import 'stock_remoto.dart';

/// Al entrar al negocio, trae lo que falta en Drift y vuelve a empujar
/// el local cuando no hay una marca de tiempo de edición confiable.
class SincronizarNegocio {
  const SincronizarNegocio._();

  static Future<void> traer(AppDatabase db) async {
    if (!RemotoComun.activo) return;
    final negocio = await NegocioStore().leer();
    if (negocio == null) return;
    try {
      await const NegocioRemoto().publicar(negocio);
    } catch (error) {
      RemotoComun.aviso('No se pudo publicar el negocio: $error');
    }
    final negocioId = await RemotoComun.negocioId();
    final supabase = RemotoComun.cliente;
    if (negocioId == null || supabase == null) return;

    final nuevosProductos = await _paso(
      'productos',
      () => _productos(db, supabase, negocioId),
    );
    await _paso('clientes', () => _clientes(db, supabase, negocioId));
    await _paso('fichas', () => _fichas(db));
    await _paso(
      'stock',
      () => _stock(db, supabase, negocioId, nuevosProductos ?? {}),
    );
    await _paso('movimientos', () => _movimientos(db, supabase, negocioId));
    await _paso('pedidos', () => _pedidos(db, supabase, negocioId));
    await _paso('capital', () => _capital(db, supabase, negocioId));
    await _paso('categorías', () => _categorias(negocio));
    await _paso('historial de clientes', () => _historialClientes(db));
  }

  static Future<T?> _paso<T>(String nombre, Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (error) {
      RemotoComun.aviso('No se pudo sincronizar $nombre: $error');
      return null;
    }
  }

  static Future<void> _clientes(
    AppDatabase db,
    SupabaseClient supabase,
    String negocioId,
  ) async {
    final remotos = await supabase
        .from('clientes')
        .select('id, nombre, telefono, email, notas, es_potencial, estado_pago, creado_en')
        .eq('negocio_id', negocioId);
    final locales = await db.select(db.clientes).get();
    const ids = IdsRemotos();
    final usadosLocal = <int>{};
    final usadosRemoto = <String>{};

    for (final local in locales) {
      final uuid = await ids.leer(IdsRemotos.cliente, '${local.id}');
      if (uuid == null) continue;
      usadosLocal.add(local.id);
      usadosRemoto.add(uuid);
    }

    for (final remoto in remotos) {
      final uuid = textoRemoto(remoto['id']);
      if (uuid.isEmpty || usadosRemoto.contains(uuid)) continue;
      final candidatos = [
        for (final local in locales)
          if (!usadosLocal.contains(local.id) && _mismoCliente(local, remoto))
            local,
      ];
      if (candidatos.length != 1) continue;
      await ids.guardar(IdsRemotos.cliente, '${candidatos.first.id}', uuid);
      usadosLocal.add(candidatos.first.id);
      usadosRemoto.add(uuid);
    }

    for (final remoto in remotos) {
      final uuid = textoRemoto(remoto['id']);
      final nombre = textoRemoto(remoto['nombre']);
      if (uuid.isEmpty || nombre.isEmpty || usadosRemoto.contains(uuid)) {
        continue;
      }
      final id = await db.into(db.clientes).insert(
            ClientesCompanion.insert(
              nombre: nombre,
              contacto: Value(_opcional(remoto['telefono'])),
              email: Value(_opcional(remoto['email'])),
              esPotencial: Value(banderaRemota(remoto['es_potencial'])),
              notas: Value(_opcional(remoto['notas'])),
              estadoPago: Value(_estado(remoto['estado_pago'])),
              fechaCreacion: Value(fechaRemota(remoto['creado_en'])),
            ),
          );
      await ids.guardar(IdsRemotos.cliente, '$id', uuid);
    }

    final actuales = await db.select(db.clientes).get();
    for (final local in actuales) {
      await ClientesRemoto.replicar(
        localId: local.id,
        nombre: local.nombre,
        telefono: local.contacto,
        email: local.email,
        notas: local.notas,
        esPotencial: local.esPotencial,
        estadoPago: local.estadoPago,
      );
    }
  }

  static bool _mismoCliente(Cliente local, Map<String, dynamic> remoto) {
    if (local.nombre.trim().toLowerCase() !=
        textoRemoto(remoto['nombre']).toLowerCase()) {
      return false;
    }
    final telLocal = (local.contacto ?? '').trim();
    final telRemoto = textoRemoto(remoto['telefono']);
    if (telLocal.isNotEmpty && telRemoto.isNotEmpty && telLocal != telRemoto) {
      return false;
    }
    return true;
  }

  static Future<Set<int>> _productos(
    AppDatabase db,
    SupabaseClient supabase,
    String negocioId,
  ) async {
    final remotos = await supabase
        .from('productos')
        .select(
          'id, nombre, precio_compra, precio_venta, descripcion, visible_en_tienda, activo, sku, umbral_stock_bajo, controla_serie, categoria_id',
        )
        .eq('negocio_id', negocioId);
    final unidades = await supabase
        .from('unidades_producto')
        .select('producto_id, codigo, estado')
        .eq('negocio_id', negocioId);
    final categorias = await supabase
        .from('categorias')
        .select('id, nombre')
        .eq('negocio_id', negocioId);
    final nombreCategoria = <String, String>{
      for (final fila in categorias)
        textoRemoto(fila['id']): textoRemoto(fila['nombre']),
    };
    final porProducto = <String, List<String>>{};
    try {
      final vinculos = await supabase
          .from('productos_categorias')
          .select('producto_id, categoria_id')
          .eq('negocio_id', negocioId);
      for (final fila in vinculos) {
        final producto = textoRemoto(fila['producto_id']);
        final nombre = nombreCategoria[textoRemoto(fila['categoria_id'])] ?? '';
        if (producto.isEmpty || nombre.isEmpty) continue;
        final lista = porProducto.putIfAbsent(producto, () => []);
        if (lista.any((item) => item.toLowerCase() == nombre.toLowerCase())) {
          continue;
        }
        lista.add(nombre);
      }
    } catch (_) {
      // La migración de varias categorías puede no estar aplicada todavía.
    }
    final locales = await db.select(db.productos).get();
    const ids = IdsRemotos();
    final usadosLocal = <int>{};
    final usadosRemoto = <String>{};
    final nuevos = <int>{};

    for (final local in locales) {
      final uuid = await ids.leer(IdsRemotos.producto, '${local.id}');
      if (uuid == null) continue;
      usadosLocal.add(local.id);
      usadosRemoto.add(uuid);
    }
    for (final remoto in remotos) {
      final uuid = textoRemoto(remoto['id']);
      if (uuid.isEmpty || usadosRemoto.contains(uuid)) continue;
      final nombre = textoRemoto(remoto['nombre']).toLowerCase();
      final candidatos = [
        for (final local in locales)
          if (!usadosLocal.contains(local.id) &&
              local.nombre.trim().toLowerCase() == nombre)
            local,
      ];
      if (candidatos.length != 1) continue;
      await ids.guardar(IdsRemotos.producto, '${candidatos.first.id}', uuid);
      usadosLocal.add(candidatos.first.id);
      usadosRemoto.add(uuid);
    }

    for (final remoto in remotos) {
      final uuid = textoRemoto(remoto['id']);
      final nombre = textoRemoto(remoto['nombre']);
      if (uuid.isEmpty || nombre.isEmpty || usadosRemoto.contains(uuid)) {
        continue;
      }
      final id = await db.into(db.productos).insert(
            ProductosCompanion.insert(
              nombre: nombre,
              precioCompra: Value(numeroRemoto(remoto['precio_compra']) ?? 0),
              precioVenta: Value(numeroRemoto(remoto['precio_venta']) ?? 0),
            ),
          );
      await ids.guardar(IdsRemotos.producto, '$id', uuid);
      nuevos.add(id);
      final suelta = nombreCategoria[textoRemoto(remoto['categoria_id'])] ?? '';
      final nombres = porProducto[uuid] ??
          (suelta.isEmpty ? const <String>[] : [suelta]);
      await _fichaTraida(
        productoId: id,
        remoto: remoto,
        categoria: nombres.isEmpty ? '' : nombres.first,
        categorias: nombres,
        unidades: [
          for (final unidad in unidades)
            if (textoRemoto(unidad['producto_id']) == uuid) unidad,
        ],
      );
    }

    final actuales = await db.select(db.productos).get();
    for (final local in actuales) {
      if (nuevos.contains(local.id)) continue;
      await StockRemoto.replicarProducto(
        DatosProductoRemoto(
          localId: local.id,
          nombre: local.nombre,
          precioCompra: local.precioCompra,
          precioVenta: local.precioVenta,
          pisarCompra: true,
          pisarVenta: true,
          pisarNombre: true,
          activo: true,
        ),
      );
    }
    return nuevos;
  }

  static Future<void> _fichaTraida({
    required int productoId,
    required Map<String, dynamic> remoto,
    required String categoria,
    List<String> categorias = const [],
    required List<Map<String, dynamic>> unidades,
  }) async {
    final descripcion = textoRemoto(remoto['descripcion']);
    final visible = remoto['visible_en_tienda'] == null
        ? true
        : banderaRemota(remoto['visible_en_tienda']);
    final umbral = enteroRemoto(remoto['umbral_stock_bajo']) ?? 2;
    final series = [
      for (final unidad in unidades)
        if (textoRemoto(unidad['codigo']).isNotEmpty)
          UnidadSerie(
            codigo: textoRemoto(unidad['codigo']),
            estado: _estadoUnidad(textoRemoto(unidad['estado'])),
          ),
    ];
    if (!visible ||
        umbral != 2 ||
        categoria.isNotEmpty ||
        series.isNotEmpty) {
      await const AmpliacionLocal().guardarFicha(
        productoId,
        FichaProducto(
          categoria: categoria,
          categorias: categorias,
          visibleEnTienda: visible,
          umbral: umbral < 0 ? 0 : umbral,
          unidades: series,
        ),
      );
    }
    if (descripcion.isNotEmpty) {
      await const VidrieraLocal().guardar(
        productoId: productoId,
        descripcion: descripcion,
        fotoBase64: '',
      );
    }
  }

  static Future<void> _fichas(AppDatabase db) async {
    final productos = await db.select(db.productos).get();
    final doc = await const AmpliacionLocal().cargar();
    final vidriera = await const VidrieraLocal().cargar();
    for (final producto in productos) {
      final ficha = doc.fichas[producto.id];
      final dato = vidriera[producto.id];
      final descripcion = dato?.descripcion.trim() ?? '';
      if (ficha == null && descripcion.isEmpty) continue;
      await CatalogoRemoto.publicarFicha(
        productoLocalId: producto.id,
        nombre: producto.nombre,
        precioCompra: producto.precioCompra,
        precioVenta: producto.precioVenta,
        categoria: ficha == null || ficha.todas.isEmpty ? '' : ficha.todas.first,
        categorias: ficha?.todas ?? const [],
        visibleEnTienda: ficha?.visibleEnTienda ?? true,
        umbral: ficha?.umbral ?? 2,
        controlaSerie: ficha?.unidades.isNotEmpty ?? false,
        descripcion: dato == null ? null : descripcion,
        atributos: ficha?.atributos ?? const {},
        variantes: [
          for (final variante in ficha?.variantes ?? const <VarianteLocal>[])
            if (variante.etiqueta.trim().isNotEmpty)
              VarianteParaNube(
                etiqueta: variante.etiqueta,
                precio: variante.precio,
              ),
        ],
        unidades: [
          for (final unidad in ficha?.unidades ?? const <UnidadSerie>[])
            if (unidad.codigo.trim().isNotEmpty)
              UnidadParaNube(codigo: unidad.codigo, estado: unidad.estado),
        ],
      );
    }
  }

  static Future<void> _stock(
    AppDatabase db,
    SupabaseClient supabase,
    String negocioId,
    Set<int> nuevos,
  ) async {
    final remotos = await supabase
        .from('stock')
        .select('producto_id, propietario, cantidad')
        .eq('negocio_id', negocioId);
    const ids = IdsRemotos();
    for (final remoto in remotos) {
      final local = await ids.localDe(
        IdsRemotos.producto,
        textoRemoto(remoto['producto_id']),
      );
      if (local == null || !nuevos.contains(local)) continue;
      final cantidad = enteroRemoto(remoto['cantidad']) ?? 0;
      if (cantidad < 0) continue;
      await _ponerStock(
        db,
        local,
        textoRemoto(remoto['propietario']),
        cantidad,
      );
    }

    final productos = await StockRepository(db).obtenerProductos();
    for (final producto in productos) {
      final id = producto.id;
      if (id == null || nuevos.contains(id)) continue;
      await StockRemoto.publicarSaldo(
        productoLocalId: id,
        nombre: producto.nombre,
        precioCompra: producto.precioCompra,
        precioVenta: producto.precioVenta,
        propietario: StockRepository.propietarioYo,
        saldo: producto.stockYo,
      );
      await StockRemoto.publicarSaldo(
        productoLocalId: id,
        nombre: producto.nombre,
        precioCompra: producto.precioCompra,
        precioVenta: producto.precioVenta,
        propietario: StockRepository.propietarioNildo,
        saldo: producto.stockNildo,
      );
    }
  }

  static Future<void> _movimientos(
    AppDatabase db,
    SupabaseClient supabase,
    String negocioId,
  ) async {
    final remotos = await supabase
        .from('movimientos_stock')
        .select('id, producto_id, propietario, cantidad, tipo, descripcion, creado_en')
        .eq('negocio_id', negocioId);
    final locales = await db.select(db.movimientosStock).get();
    final usuarios = await db.select(db.usuarios).get();
    const ids = IdsRemotos();
    final usadosLocal = <int>{};
    final usadosRemoto = <String>{};
    final nombreUsuario = {for (final usuario in usuarios) usuario.id: usuario.nombre};

    for (final local in locales) {
      final uuid = await ids.leer(IdsRemotos.movimientoStock, '${local.id}');
      if (uuid == null) continue;
      usadosLocal.add(local.id);
      usadosRemoto.add(uuid);
    }

    final pendientesRemotos = <Map<String, dynamic>>[];
    for (final remoto in remotos) {
      final uuid = textoRemoto(remoto['id']);
      if (uuid.isEmpty || usadosRemoto.contains(uuid)) continue;
      final localProducto = await ids.localDe(
        IdsRemotos.producto,
        textoRemoto(remoto['producto_id']),
      );
      if (localProducto == null) continue;
      final huella = _huellaMovimiento(
        productoId: localProducto,
        propietario: textoRemoto(remoto['propietario']),
        tipo: textoRemoto(remoto['tipo']),
        cantidad: enteroRemoto(remoto['cantidad']) ?? 0,
        descripcion: textoRemoto(remoto['descripcion']),
      );
      MovimientosStockData? elegido;
      for (final local in locales) {
        if (usadosLocal.contains(local.id)) continue;
        final propia = _huellaMovimiento(
          productoId: local.productoId,
          propietario: nombreUsuario[local.usuarioId] ?? '',
          tipo: local.tipo,
          cantidad: local.cantidad,
          descripcion: local.descripcion ?? '',
        );
        if (propia != huella) continue;
        elegido = local;
        break;
      }
      if (elegido != null) {
        await ids.guardar(IdsRemotos.movimientoStock, '${elegido.id}', uuid);
        usadosLocal.add(elegido.id);
        usadosRemoto.add(uuid);
        continue;
      }
      pendientesRemotos.add(remoto);
    }

    for (final remoto in pendientesRemotos) {
      final uuid = textoRemoto(remoto['id']);
      final localProducto = await ids.localDe(
        IdsRemotos.producto,
        textoRemoto(remoto['producto_id']),
      );
      final tipo = _tipoStock(textoRemoto(remoto['tipo']));
      final cantidad = enteroRemoto(remoto['cantidad']) ?? 0;
      if (localProducto == null || tipo == null || cantidad <= 0 || uuid.isEmpty) {
        continue;
      }
      final propietario = _canonPropietario(textoRemoto(remoto['propietario']));
      if (propietario == null) continue;
      final usuarioId = await _usuario(db, propietario);
      final fecha = fechaRemota(remoto['creado_en']);
      final id = await db.into(db.movimientosStock).insert(
            MovimientosStockCompanion.insert(
              productoId: localProducto,
              usuarioId: usuarioId,
              tipo: tipo,
              cantidad: cantidad,
              descripcion: Value(_opcional(remoto['descripcion'])),
              fechaCarga: Value(fecha),
              fechaSalida: tipo == StockRepository.tipoSalida
                  ? Value(fecha)
                  : const Value.absent(),
            ),
          );
      await ids.guardar(IdsRemotos.movimientoStock, '$id', uuid);
      usadosLocal.add(id);
    }

    final productos = await StockRepository(db).obtenerProductos();
    final porId = {
      for (final producto in productos)
        if (producto.id != null) producto.id!: producto,
    };
    final frescos = await db.select(db.movimientosStock).get();
    final nombres = await db.select(db.usuarios).get();
    final dueno = {for (final usuario in nombres) usuario.id: usuario.nombre};
    for (final local in frescos) {
      if (usadosLocal.contains(local.id)) continue;
      final producto = porId[local.productoId];
      final propietario = _canonPropietario(dueno[local.usuarioId] ?? '');
      final tipo = _tipoStock(local.tipo);
      if (producto == null || propietario == null || tipo == null) continue;
      final saldo = propietario == StockRepository.propietarioYo
          ? producto.stockYo
          : producto.stockNildo;
      await StockRemoto.replicarMovimiento(
        DatosMovimientoRemoto(
          nombre: producto.nombre,
          precioCompra: producto.precioCompra,
          precioVenta: producto.precioVenta,
          pisarCompra: false,
          pisarVenta: false,
          propietario: propietario,
          cantidad: local.cantidad,
          saldo: saldo,
          tipo: tipo,
          descripcion: local.descripcion ?? '',
          productoLocalId: local.productoId,
          movimientoLocalId: local.id,
        ),
      );
      usadosLocal.add(local.id);
    }
  }

  static Future<void> _pedidos(
    AppDatabase db,
    SupabaseClient supabase,
    String negocioId,
  ) async {
    final remotos = await supabase
        .from('pedidos')
        .select(
          'id, cliente_nombre, cliente_id, estado, senia, total, creado_en, origen, medio_pago, nota',
        )
        .eq('negocio_id', negocioId);
    final lineasRemotas = await supabase.from('productos_pedido').select(
          'id, pedido_id, producto_id, nombre, cantidad, precio_venta',
        );
    final historial = await supabase.from('historial_pedidos').select(
          'id, pedido_id, estado, nota, creado_en',
        );
    final locales = await db.select(db.pedidos).get();
    final clientes = await db.select(db.clientes).get();
    const ids = IdsRemotos();
    final usadosLocal = <int>{};
    final usadosRemoto = <String>{};
    final traidos = <int>{};
    final nombreCliente = {for (final cliente in clientes) cliente.id: cliente.nombre};

    for (final local in locales) {
      final uuid = await ids.leer(IdsRemotos.pedido, '${local.id}');
      if (uuid == null) continue;
      usadosLocal.add(local.id);
      usadosRemoto.add(uuid);
    }

    for (final remoto in remotos) {
      final uuid = textoRemoto(remoto['id']);
      if (uuid.isEmpty || usadosRemoto.contains(uuid)) continue;
      final candidatos = [
        for (final local in locales)
          if (!usadosLocal.contains(local.id) &&
              _mismoPedido(local, remoto, nombreCliente[local.clienteId] ?? ''))
            local,
      ];
      final fecha = fechaRemota(remoto['creado_en']);
      final finos = candidatos
          .where((local) => local.fecha.difference(fecha).inMinutes.abs() <= 2)
          .toList();
      final elegido = candidatos.length == 1
          ? candidatos.first
          : (finos.length == 1 ? finos.first : null);
      if (elegido == null) continue;
      await ids.guardar(IdsRemotos.pedido, '${elegido.id}', uuid);
      usadosLocal.add(elegido.id);
      usadosRemoto.add(uuid);
    }

    for (final remoto in remotos) {
      final uuid = textoRemoto(remoto['id']);
      if (uuid.isEmpty || usadosRemoto.contains(uuid)) continue;
      final localId = await _insertarPedidoTraido(
        db,
        ids,
        remoto,
        [
          for (final linea in lineasRemotas)
            if (textoRemoto(linea['pedido_id']) == uuid) linea,
        ],
        [
          for (final nota in historial)
            if (textoRemoto(nota['pedido_id']) == uuid) nota,
        ],
      );
      if (localId == null) continue;
      traidos.add(localId);
      await ids.guardar(IdsRemotos.pedido, '$localId', uuid);
    }

    final pedidos = PedidoRepository(db);
    final actuales = await db.select(db.pedidos).get();
    for (final local in actuales) {
      if (traidos.contains(local.id)) continue;
      await pedidos.publicarEnNube(local.id);
    }
  }

  static bool _mismoPedido(
    Pedido local,
    Map<String, dynamic> remoto,
    String cliente,
  ) {
    if (cliente.trim().toLowerCase() !=
        textoRemoto(remoto['cliente_nombre']).toLowerCase()) {
      return false;
    }
    final senia = numeroRemoto(remoto['senia']) ?? 0;
    return (local.montoSenado - senia).abs() < 0.02;
  }

  static Future<int?> _insertarPedidoTraido(
    AppDatabase db,
    IdsRemotos ids,
    Map<String, dynamic> remoto,
    List<Map<String, dynamic>> lineas,
    List<Map<String, dynamic>> historial,
  ) async {
    final nombre = textoRemoto(remoto['cliente_nombre']);
    if (nombre.isEmpty) return null;
    final remotoCliente = textoRemoto(remoto['cliente_id']);
    var clienteId = await ids.localDe(IdsRemotos.cliente, remotoCliente);
    clienteId ??= await _clientePorNombre(db, nombre);
    clienteId ??= await db.into(db.clientes).insert(
          ClientesCompanion.insert(nombre: nombre),
        );
    if (remotoCliente.isNotEmpty) {
      await ids.guardar(IdsRemotos.cliente, '$clienteId', remotoCliente);
    }
    final id = await db.into(db.pedidos).insert(
          PedidosCompanion.insert(
            clienteId: clienteId,
            fecha: Value(fechaRemota(remoto['creado_en'])),
            estado: Value(_estado(remoto['estado'])),
            montoSenado: Value(numeroRemoto(remoto['senia']) ?? 0),
          ),
        );
    var bruto = 0.0;
    for (final linea in lineas) {
      final cantidad = enteroRemoto(linea['cantidad']) ?? 0;
      if (cantidad <= 0) continue;
      final precio = numeroRemoto(linea['precio_venta']) ?? 0;
      final productoId = await _productoDeLinea(db, ids, linea, precio);
      if (productoId == null) continue;
      bruto += precio * cantidad;
      await db.into(db.productosPedido).insert(
            ProductosPedidoCompanion.insert(
              pedidoId: id,
              productoId: productoId,
              cantidad: cantidad,
            ),
          );
    }
    historial.sort(
      (a, b) => fechaRemota(a['creado_en']).compareTo(fechaRemota(b['creado_en'])),
    );
    for (final nota in historial) {
      final paso = _pasoHistorial(
        textoRemoto(nota['estado']),
        textoRemoto(nota['nota']),
      );
      await db.into(db.historialPedidos).insert(
            HistorialPedidosCompanion.insert(
              pedidoId: id,
              estadoAnterior: paso.$1,
              estadoNuevo: paso.$2,
              fechaCambio: Value(fechaRemota(nota['creado_en'])),
            ),
          );
    }
    final total = numeroRemoto(remoto['total']) ?? bruto;
    final descuento = bruto - total;
    final medio = textoRemoto(remoto['medio_pago']);
    await const AmpliacionLocal().marcarPedido(
      pedidoId: id,
      origen: _origenLocal(textoRemoto(remoto['origen'])),
      medioPago: medio == 'fiado' ? '' : medio,
      fiado: medio == 'fiado',
      descuentoTipo: descuento > 0.009 ? 'monto' : '',
      descuentoValor: descuento > 0.009 ? descuento : 0,
      descuentoMonto: descuento > 0.009 ? descuento : 0,
    );
    return id;
  }

  static Future<int?> _productoDeLinea(
    AppDatabase db,
    IdsRemotos ids,
    Map<String, dynamic> linea,
    double precio,
  ) async {
    final mapeado = await ids.localDe(
      IdsRemotos.producto,
      textoRemoto(linea['producto_id']),
    );
    if (mapeado != null) return mapeado;
    final nombre = textoRemoto(linea['nombre']);
    if (nombre.isEmpty) return null;
    final productos = await db.select(db.productos).get();
    for (final producto in productos) {
      if (producto.nombre.trim().toLowerCase() == nombre.toLowerCase()) {
        return producto.id;
      }
    }
    final id = await db.into(db.productos).insert(
          ProductosCompanion.insert(
            nombre: nombre,
            precioVenta: Value(precio < 0 ? 0 : precio),
          ),
        );
    final uuid = textoRemoto(linea['producto_id']);
    if (uuid.isNotEmpty) {
      await ids.guardar(IdsRemotos.producto, '$id', uuid);
    }
    return id;
  }

  static Future<int?> _clientePorNombre(AppDatabase db, String nombre) async {
    final clave = nombre.trim().toLowerCase();
    final clientes = await db.select(db.clientes).get();
    int? elegido;
    for (final cliente in clientes) {
      if (cliente.nombre.trim().toLowerCase() != clave) continue;
      if (elegido == null || cliente.id < elegido) elegido = cliente.id;
    }
    return elegido;
  }

  static Future<void> _capital(
    AppDatabase db,
    SupabaseClient supabase,
    String negocioId,
  ) async {
    final remotos = await supabase
        .from('movimientos_capital')
        .select('id, persona, monto, tipo, descripcion, creado_en')
        .eq('negocio_id', negocioId);
    final locales = await db.select(db.movimientosCapital).get();
    const ids = IdsRemotos();
    final usadosLocal = <int>{};
    final usadosRemoto = <String>{};

    for (final local in locales) {
      final uuid = await ids.leer(IdsRemotos.capital, '${local.id}');
      if (uuid == null) continue;
      usadosLocal.add(local.id);
      usadosRemoto.add(uuid);
    }

    for (final remoto in remotos) {
      final uuid = textoRemoto(remoto['id']);
      if (uuid.isEmpty || usadosRemoto.contains(uuid)) continue;
      final huella = _huellaCapital(
        persona: textoRemoto(remoto['persona']),
        tipo: textoRemoto(remoto['tipo']),
        monto: numeroRemoto(remoto['monto']) ?? 0,
        descripcion: textoRemoto(remoto['descripcion']),
      );
      MovimientosCapitalData? elegido;
      for (final local in locales) {
        if (usadosLocal.contains(local.id)) continue;
        final propia = _huellaCapital(
          persona: local.persona,
          tipo: local.tipo,
          monto: local.monto,
          descripcion: local.descripcion ?? '',
        );
        if (propia != huella) continue;
        elegido = local;
        break;
      }
      if (elegido != null) {
        await ids.guardar(IdsRemotos.capital, '${elegido.id}', uuid);
        usadosLocal.add(elegido.id);
        usadosRemoto.add(uuid);
        continue;
      }
      final persona = textoRemoto(remoto['persona']);
      final monto = numeroRemoto(remoto['monto']) ?? 0;
      final tipo = textoRemoto(remoto['tipo']);
      if (persona.isEmpty || tipo.isEmpty || monto == 0) continue;
      final id = await db.into(db.movimientosCapital).insert(
            MovimientosCapitalCompanion.insert(
              persona: persona,
              monto: monto.abs(),
              tipo: tipo,
              descripcion: Value(_opcional(remoto['descripcion'])),
              fecha: Value(fechaRemota(remoto['creado_en'])),
            ),
          );
      await ids.guardar(IdsRemotos.capital, '$id', uuid);
      usadosLocal.add(id);
    }

    final actuales = await db.select(db.movimientosCapital).get();
    for (final local in actuales) {
      if (usadosLocal.contains(local.id)) continue;
      await CapitalRemoto.replicar(
        localId: local.id,
        persona: local.persona,
        monto: local.monto,
        tipo: local.tipo,
        descripcion: local.descripcion,
      );
    }
  }

  static Future<void> _categorias(NegocioLocal negocio) async {
    if (negocio.categorias.isEmpty) {
      final supabase = RemotoComun.cliente;
      final negocioId = await RemotoComun.negocioId();
      if (supabase == null || negocioId == null) return;
      final filas = await supabase
          .from('categorias')
          .select('nombre, orden')
          .eq('negocio_id', negocioId)
          .order('orden');
      final nombres = [
        for (final fila in filas)
          if (textoRemoto(fila['nombre']).isNotEmpty) textoRemoto(fila['nombre']),
      ];
      if (nombres.isEmpty) return;
      await NegocioStore().guardarCatalogo(categorias: nombres);
      return;
    }
    await CatalogoRemoto.publicarCategorias(negocio.categorias);
  }

  static Future<void> _historialClientes(AppDatabase db) async {
    final filas = await db.select(db.historialClientes).get();
    for (final fila in filas) {
      await ClientesRemoto.replicarHistorial(
        historialLocalId: fila.id,
        clienteLocalId: fila.clienteId,
        anterior: fila.estadoAnterior,
        nuevo: fila.estadoNuevo,
      );
    }
  }

  static Future<void> _ponerStock(
    AppDatabase db,
    int productoId,
    String propietario,
    int cantidad,
  ) async {
    final canonico = _canonPropietario(propietario);
    if (canonico == null) return;
    final usuarioId = await _usuario(db, canonico);
    final filas = await (db.select(db.stock)
          ..where(
            (fila) =>
                fila.productoId.equals(productoId) &
                fila.usuarioId.equals(usuarioId),
          ))
        .get();
    if (filas.isEmpty) {
      await db.into(db.stock).insert(
            StockCompanion.insert(
              productoId: productoId,
              usuarioId: usuarioId,
              cantidadActual: Value(cantidad),
            ),
          );
      return;
    }
    await (db.update(db.stock)..where((fila) => fila.id.equals(filas.first.id)))
        .write(StockCompanion(cantidadActual: Value(cantidad)));
    for (final extra in filas.skip(1)) {
      await (db.delete(db.stock)..where((fila) => fila.id.equals(extra.id))).go();
    }
  }

  static Future<int> _usuario(AppDatabase db, String nombre) async {
    final clave = nombre.trim().toLowerCase();
    final usuarios = await db.select(db.usuarios).get();
    for (final usuario in usuarios) {
      if (usuario.nombre.trim().toLowerCase() == clave) return usuario.id;
    }
    return db.into(db.usuarios).insert(UsuariosCompanion.insert(nombre: nombre));
  }
}

String? _opcional(Object? valor) {
  final texto = textoRemoto(valor);
  return texto.isEmpty ? null : texto;
}

String _estado(Object? valor) {
  final texto = textoRemoto(valor);
  return texto.isEmpty ? 'pendiente' : texto;
}

String _estadoUnidad(String estado) {
  const validos = {'disponible', 'reservada', 'vendida', 'baja'};
  return validos.contains(estado) ? estado : 'disponible';
}

String _origenLocal(String origen) {
  switch (origen) {
    case 'tienda':
    case 'asistente':
    case 'manual':
    case 'local':
      return origen;
    default:
      return 'local';
  }
}

(String, String) _pasoHistorial(String estado, String nota) {
  final match = RegExp(r'^Paso de (.+) a (.+)$').firstMatch(nota.trim());
  if (match != null) {
    return (match.group(1)!.trim(), match.group(2)!.trim());
  }
  final nuevo = estado.isEmpty ? 'pendiente' : estado;
  return (nuevo, nuevo);
}

String? _canonPropietario(String propietario) {
  final clave = propietario.trim().toLowerCase();
  if (clave == 'yo') return StockRepository.propietarioYo;
  if (clave == 'nildo') return StockRepository.propietarioNildo;
  return null;
}

String? _tipoStock(String tipo) {
  final clave = tipo.trim().toLowerCase();
  if (clave == 'entrada' || clave == 'salida') return clave;
  return null;
}

String _huellaMovimiento({
  required int productoId,
  required String propietario,
  required String tipo,
  required int cantidad,
  required String descripcion,
}) {
  return '$productoId|${propietario.trim().toLowerCase()}|${tipo.trim().toLowerCase()}|$cantidad|${descripcion.trim().toLowerCase()}';
}

String _huellaCapital({
  required String persona,
  required String tipo,
  required double monto,
  required String descripcion,
}) {
  return '${persona.trim().toLowerCase()}|${tipo.trim().toLowerCase()}|${CapitalRepository.enCentavos(monto)}|${descripcion.trim().toLowerCase()}';
}
