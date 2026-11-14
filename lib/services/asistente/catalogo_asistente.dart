import 'package:drift/drift.dart';

import '../../backend/ids_remotos.dart';
import '../../backend/remoto_comun.dart';
import '../../backend/stock_remoto.dart';
import '../../data/ampliacion_local.dart';
import '../../data/app_database.dart';
import '../../data/stock_repository.dart';
import '../../data/vidriera_local.dart';
import '../negocio_local.dart';
import 'coincidencia_producto.dart';

export 'coincidencia_producto.dart';

/// Lectura y altas de catálogo para el asistente.
///
/// [buscarProducto] no crea ni modifica productos. Las escrituras piden un id
/// ya confirmado, o crean uno nuevo y devuelven ese id. Si la búsqueda trae
/// varias coincidencias, se devuelven todas.
class CatalogoAsistente {
  const CatalogoAsistente(this.database);

  final AppDatabase database;

  /// No escribe. Busca en productos locales (StockRepository / Drift).
  /// Normaliza mayúsculas, acentos y espacios.
  Future<ResultadoBusquedaProducto> buscarProducto(String texto) async {
    final clave = _normalizar(texto);
    if (clave.isEmpty) return const ResultadoBusquedaProducto();

    final stock = StockRepository(database);
    final productosFuture = stock.obtenerProductos();
    final fichasFuture = const AmpliacionLocal().cargar();
    final vidrieraFuture = _cargarVidriera();
    final productos = await productosFuture;
    final fichas = (await fichasFuture).fichas;
    final vidriera = await vidrieraFuture;

    final exactos = <_Ordenado>[];
    final parecidos = <_Ordenado>[];
    for (final producto in productos) {
      final id = producto.id;
      if (id == null) continue;
      final nombre = _normalizar(producto.nombre);
      if (nombre.isEmpty) continue;
      final coincidencia = _coincidencia(producto, id, fichas[id]);
      if (nombre == clave) {
        exactos.add(_Ordenado(coincidencia, 0));
        continue;
      }
      final cercania = _cercania(nombre, clave);
      if (cercania == null) continue;
      parecidos.add(_Ordenado(coincidencia, cercania));
    }

    int porNombre(_Ordenado a, _Ordenado b) =>
        _normalizar(a.item.nombre).compareTo(_normalizar(b.item.nombre));

    exactos.sort(porNombre);
    parecidos.sort((a, b) {
      final porCercania = a.orden.compareTo(b.orden);
      if (porCercania != 0) return porCercania;
      return porNombre(a, b);
    });

    final ids = <int>{
      for (final item in exactos) item.item.id,
      for (final item in parecidos) item.item.id,
    };
    final urls = await _urlsPublicas(ids);
    CoincidenciaProducto pintar(_Ordenado item) {
      final url = urls[item.item.id];
      if (url != null) return item.item.conFoto(fotoUrl: url);
      return item.item.conFoto(
        fotoBytes: _fotoGeneralLocal(vidriera[item.item.id]),
      );
    }

    return ResultadoBusquedaProducto(
      exactos: List.unmodifiable([for (final item in exactos) pintar(item)]),
      parecidos: List.unmodifiable([for (final item in parecidos) pintar(item)]),
    );
  }

  /// Solo con categoría ya resuelta. Crea el producto con precio de compra y
  /// de venta y stock inicial 0 (el stock entra por [agregarStock]). Devuelve
  /// el id local.
  Future<int> crearProducto({
    required String nombre,
    required String categoria,
    required double precioCompra,
    required double precioVenta,
  }) async {
    final limpio = _espacios(nombre);
    if (limpio.isEmpty) {
      throw StateError('El nombre del producto es obligatorio.');
    }
    _exigirPrecio(precioCompra, 'precio de compra');
    _exigirPrecio(precioVenta, 'precio de venta');

    final categoriaLimpia = _espacios(categoria);
    if (categoriaLimpia.isEmpty) {
      throw StateError('La categoría es obligatoria.');
    }

    final stock = StockRepository(database);
    final yaExiste = await stock.obtenerProductos();
    final clave = _normalizar(limpio);
    for (final producto in yaExiste) {
      if (producto.id == null) continue;
      if (_normalizar(producto.nombre) != clave) continue;
      throw StateError(
        'Ya hay un producto con el nombre "$limpio". No creé otro.',
      );
    }

    final store = NegocioStore();
    final negocio = await store.leer();
    if (negocio == null) {
      throw StateError(
        'No hay un negocio configurado. No creé el producto.',
      );
    }
    final categoriaElegida = await _categoriaResuelta(
      store,
      negocio.categorias,
      categoriaLimpia,
    );

    // registrarEntrada rechaza cantidad 0. El alta sin unidades queda en Drift
    // y la ficha guarda la categoría. El stock entra después, con el id.
    final id = await database.into(database.productos).insert(
          ProductosCompanion.insert(
            nombre: limpio,
            precioCompra: Value(precioCompra),
            precioVenta: Value(precioVenta),
          ),
        );
    ReplicaScope.diferir(
      () => StockRemoto.replicarProducto(
        DatosProductoRemoto(
          localId: id,
          nombre: limpio,
          precioCompra: precioCompra,
          precioVenta: precioVenta,
          pisarCompra: true,
          pisarVenta: true,
          activo: true,
        ),
      ),
    );
    await const AmpliacionLocal().guardarFicha(
      id,
      FichaProducto(
        categoria: categoriaElegida,
        categorias: [categoriaElegida],
      ),
    );
    return id;
  }

  /// Suma unidades a un id ya confirmado. Costo unitario = precio de compra de
  /// esa entrada. Si [precioVenta] viene, actualiza el precio de venta.
  ///
  /// La entrada queda a nombre de Yo: este método no recibe propietario.
  /// Usa [StockRepository.registrarEntrada] cuando ese nombre apunta a este
  /// id. Si el mismo nombre pertenece a otro id más chico, no lo toca: ajusta
  /// por el id recibido y actualiza los precios con el repositorio.
  Future<void> agregarStock({
    required int productoId,
    required int cantidad,
    required double costoUnitario,
    double? precioVenta,
  }) async {
    if (productoId <= 0) {
      throw StateError(
        'El id del producto tiene que venir indicado. No modifiqué el stock.',
      );
    }
    _exigirCantidad(cantidad);
    _exigirPrecio(costoUnitario, 'costo unitario');
    if (precioVenta != null) {
      _exigirPrecio(precioVenta, 'precio de venta');
    }

    final stock = StockRepository(database);
    final producto = await stock.obtenerPorId(productoId);
    if (producto == null || producto.id != productoId) {
      throw StateError(
        'No encontré el producto $productoId. No modifiqué el stock.',
      );
    }

    final productos = await stock.obtenerProductos();
    final clave = producto.nombre.trim().toLowerCase();
    ProductoStock? porNombre;
    for (final item in productos) {
      final idItem = item.id;
      if (idItem == null) continue;
      if (item.nombre.trim().toLowerCase() != clave) continue;
      if (porNombre == null || idItem < porNombre.id!) {
        porNombre = item;
      }
    }

    if (porNombre != null && porNombre.id == productoId) {
      await stock.registrarEntrada(
        nombre: producto.nombre,
        cantidad: cantidad,
        precioCompra: costoUnitario,
        precioVenta: precioVenta,
        propietario: StockRepository.propietarioYo,
      );
      return;
    }

    await stock.actualizarPrecios(
      productoId: productoId,
      precioCompra: costoUnitario,
      precioVenta: precioVenta ?? producto.precioVenta,
    );
    await stock.registrarAjuste(
      productoId: productoId,
      nombre: producto.nombre,
      cantidad: cantidad,
      propietario: StockRepository.propietarioYo,
      tipo: StockRepository.tipoEntrada,
      descripcion: 'Alta de stock',
    );
  }

  /// Ids visibles en la página que no tienen foto general ni URL pública.
  Future<Set<int>> idsVisiblesSinFoto(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    final documento = await const AmpliacionLocal().cargar();
    final vidriera = await _cargarVidriera();
    final urls = await _urlsPublicas(ids);
    final sinFoto = <int>{};
    for (final id in ids) {
      final visible = documento.fichas[id]?.visibleEnTienda ?? true;
      if (!visible) continue;
      if (urls.containsKey(id)) continue;
      if (_fotoGeneralLocal(vidriera[id]) != null) continue;
      sinFoto.add(id);
    }
    return sinFoto;
  }

  /// Categorías ya configuradas del negocio. No inventa categorías nuevas.
  /// Si el negocio no tiene ninguna, devuelve una lista vacía.
  Future<List<String>> categoriasDelNegocio() async {
    final negocio = await NegocioStore().leer();
    if (negocio == null) return const [];
    return List.unmodifiable(_sinRepetir(negocio.categorias));
  }

  /// Sugiere una categoría existente por similitud con el nombre del producto.
  /// Si no hay parecido claro, devuelve null para que el orquestador pregunte.
  Future<String?> sugerirCategoria(String nombreProducto) async {
    final nombre = _normalizar(nombreProducto);
    if (nombre.isEmpty) return null;
    final categorias = await categoriasDelNegocio();
    if (categorias.isEmpty) return null;

    String? mejor;
    var mejorPuntaje = 0;
    var segundo = 0;
    for (final categoria in categorias) {
      final puntaje = _puntajeCategoria(nombre, categoria);
      if (puntaje > mejorPuntaje) {
        segundo = mejorPuntaje;
        mejorPuntaje = puntaje;
        mejor = categoria;
      } else if (puntaje > segundo) {
        segundo = puntaje;
      }
    }
    if (mejor == null || mejorPuntaje < 75) return null;
    if (mejorPuntaje - segundo < 15) return null;
    return mejor;
  }

  Future<String> _categoriaResuelta(
    NegocioStore store,
    List<String> actuales,
    String pedida,
  ) async {
    final limpias = _sinRepetir(actuales);
    if (limpias.isEmpty) {
      await store.guardarCatalogo(categorias: [pedida]);
      return pedida;
    }
    final clave = _normalizar(pedida);
    final coincidencias = [
      for (final nombre in limpias)
        if (_normalizar(nombre) == clave) nombre,
    ];
    if (coincidencias.isEmpty) {
      throw StateError(
        'La categoría "$pedida" no está en el negocio. '
        'Elegí una de las que ya existen.',
      );
    }
    if (coincidencias.length > 1) {
      throw StateError(
        'Hay más de una categoría para "$pedida": '
        '${coincidencias.join(', ')}. No elegí ninguna.',
      );
    }
    return coincidencias.first;
  }
}

class _Ordenado {
  const _Ordenado(this.item, this.orden);

  final CoincidenciaProducto item;
  final int orden;
}

Future<Map<int, DatoVidriera>> _cargarVidriera() async {
  try {
    return await const VidrieraLocal().cargar();
  } catch (_) {
    return const {};
  }
}

/// Primera foto general (variante vacía). No usa fotos de una variante.
Uint8List? _fotoGeneralLocal(DatoVidriera? dato) {
  if (dato == null) return null;
  for (final foto in dato.galeria) {
    if (foto.variante.trim().isNotEmpty) continue;
    final bytes = bytesDeFotoVidriera(foto.base64);
    if (bytes != null && bytes.isNotEmpty) return bytes;
  }
  return null;
}

/// Solo lectura. `imagen_url` gana; si no hay, la primera fila general de
/// `fotos_producto`. Si la nube no responde, el mapa queda vacío.
Future<Map<int, String>> _urlsPublicas(Set<int> ids) async {
  if (ids.isEmpty || !RemotoComun.activo) return const {};
  try {
    return await _leerUrlsPublicas(ids).timeout(const Duration(seconds: 8));
  } catch (_) {
    return const {};
  }
}

Future<Map<int, String>> _leerUrlsPublicas(Set<int> ids) async {
  final supabase = RemotoComun.cliente;
  if (supabase == null) return const {};
  final negocioId = await RemotoComun.negocioId();
  if (negocioId == null || negocioId.isEmpty) return const {};

  final mapa = await const IdsRemotos().de(IdsRemotos.producto);
  final localDe = <String, int>{};
  for (final id in ids) {
    final uuid = mapa['$id']?.trim() ?? '';
    if (uuid.isEmpty) continue;
    localDe[uuid] = id;
  }
  if (localDe.isEmpty) return const {};
  final uuids = localDe.keys.toList();
  final urls = <int, String>{};

  try {
    final filas = await supabase
        .from('productos')
        .select('id, imagen_url')
        .eq('negocio_id', negocioId)
        .inFilter('id', uuids);
    for (final fila in filas) {
      final local = localDe[textoRemoto(fila['id'])];
      if (local == null) continue;
      final url = _urlHttp(textoRemoto(fila['imagen_url']));
      if (url != null) urls[local] = url;
    }
  } catch (_) {
    // La columna puede no existir todavía. Las filas de fotos siguen sirviendo.
  }

  final faltan = [
    for (final uuid in uuids)
      if (localDe[uuid] != null && !urls.containsKey(localDe[uuid])) uuid,
  ];
  if (faltan.isEmpty) return urls;

  try {
    final filas = await supabase
        .from('fotos_producto')
        .select('producto_id, variante_id, url, orden')
        .eq('negocio_id', negocioId)
        .inFilter('producto_id', faltan)
        .order('orden');
    final mejor = <int, ({String url, bool general, int orden})>{};
    for (final fila in filas) {
      final local = localDe[textoRemoto(fila['producto_id'])];
      if (local == null || urls.containsKey(local)) continue;
      final url = _urlHttp(textoRemoto(fila['url']));
      if (url == null) continue;
      final general = textoRemoto(fila['variante_id']).isEmpty;
      final orden = enteroRemoto(fila['orden']) ?? 0;
      final actual = mejor[local];
      final reemplaza = actual == null ||
          (general && !actual.general) ||
          (general == actual.general && orden < actual.orden);
      if (reemplaza) {
        mejor[local] = (url: url, general: general, orden: orden);
      }
    }
    for (final entrada in mejor.entries) {
      urls[entrada.key] = entrada.value.url;
    }
  } catch (_) {
    // Sin filas de fotos, queda la URL de productos o la foto local.
  }
  return urls;
}

String? _urlHttp(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty) return null;
  final uri = Uri.tryParse(limpio);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return limpio;
}

CoincidenciaProducto _coincidencia(
  ProductoStock producto,
  int id,
  FichaProducto? ficha,
) {
  final categorias = ficha?.todas ?? const <String>[];
  return CoincidenciaProducto(
    id: id,
    nombre: producto.nombre,
    categoria: categorias.isEmpty ? '' : categorias.first,
    categorias: List.unmodifiable(categorias),
    stock: producto.stockTotal,
    precioCompra: producto.precioCompra,
    precioVenta: producto.precioVenta,
    activo: ficha?.visibleEnTienda ?? true,
  );
}

List<String> _sinRepetir(List<String> nombres) {
  final vistas = <String>{};
  final lista = <String>[];
  for (final nombre in nombres) {
    final limpio = _espacios(nombre);
    if (limpio.isEmpty) continue;
    if (!vistas.add(_normalizar(limpio))) continue;
    lista.add(limpio);
  }
  return lista;
}

void _exigirPrecio(double valor, String cual) {
  if (valor.isNaN || valor.isInfinite || valor < 0) {
    throw StateError('El $cual no puede ser negativo ni inválido.');
  }
}

void _exigirCantidad(int cantidad) {
  if (cantidad <= 0) {
    throw StateError('La cantidad tiene que ser mayor a cero.');
  }
}

String _espacios(String texto) => texto.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Minúsculas, sin acentos y con un solo espacio entre palabras.
String _normalizar(String texto) {
  const origen = 'áéíóúüñàèìòùâêîôûäëïö';
  const destino = 'aeiouunaeiouaeiouaeio';
  var salida = _espacios(texto).toLowerCase();
  for (var i = 0; i < origen.length; i++) {
    salida = salida.replaceAll(origen[i], destino[i]);
  }
  return salida;
}

String _raiz(String texto) {
  if (texto.length > 4 && texto.endsWith('es')) {
    final sinEs = texto.substring(0, texto.length - 2);
    if (sinEs.endsWith('c')) return '${sinEs.substring(0, sinEs.length - 1)}z';
    return sinEs;
  }
  if (texto.length > 3 && texto.endsWith('s')) {
    return texto.substring(0, texto.length - 1);
  }
  return texto;
}

/// null si no contiene el texto ni está a poca distancia.
/// Un número más chico es más parecido.
int? _cercania(String nombre, String consulta) {
  if (consulta.length >= 2 && nombre.contains(consulta)) return 0;
  if (nombre.length >= 3 && consulta.contains(nombre)) return 1;

  final nombreCompacto = nombre.replaceAll(' ', '');
  final consultaCompacta = consulta.replaceAll(' ', '');
  if (consultaCompacta.length >= 3 &&
      nombreCompacto == consultaCompacta &&
      nombre != consulta) {
    return 1;
  }
  if (consulta.length < 3 || nombre.length < 3) return null;

  final dist = _distancia(nombre, consulta);
  if (dist == 0) return 0;
  final largo =
      nombre.length > consulta.length ? nombre.length : consulta.length;
  final cerca = largo <= 5
      ? dist == 1
      : largo <= 10
          ? dist <= 2
          : dist <= 3 && dist / largo <= 0.25;
  if (!cerca) return null;
  return dist + 2;
}

int _puntajeCategoria(String nombre, String categoria) {
  final cat = _normalizar(categoria);
  if (cat.isEmpty || nombre.isEmpty) return 0;
  if (nombre == cat) return 100;

  final tokens = nombre.split(' ').where((token) => token.isNotEmpty).toList();
  final raizCat = _raiz(cat);
  for (final token in tokens) {
    if (token == cat) return 92;
    if (raizCat.length >= 4 && _raiz(token) == raizCat) return 90;
  }
  if (cat.length >= 4 && nombre.contains(cat)) return 80;
  if (raizCat.length >= 4 && nombre.contains(raizCat)) return 78;

  final dist = _distancia(nombre, cat);
  final largo = nombre.length > cat.length ? nombre.length : cat.length;
  if (largo >= 5 && dist > 0 && dist <= 2 && dist / largo <= 0.34) {
    return 76 - dist;
  }

  var mejor = 0;
  for (final token in tokens) {
    if (token.length < 4) continue;
    final d = _distancia(token, cat);
    final m = token.length > cat.length ? token.length : cat.length;
    if (d == 0) return 92;
    if (d == 1 || (m >= 5 && d <= 2 && d / m <= 0.34)) {
      final puntos = 74 - d;
      if (puntos > mejor) mejor = puntos;
    }
  }
  return mejor;
}

int _distancia(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previa = List<int>.generate(b.length + 1, (i) => i);
  var actual = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    actual[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final costo = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      final reemplazo = previa[j] + costo;
      final borrado = previa[j + 1] + 1;
      final insercion = actual[j] + 1;
      var menor = reemplazo < borrado ? reemplazo : borrado;
      if (insercion < menor) menor = insercion;
      actual[j + 1] = menor;
    }
    final swap = previa;
    previa = actual;
    actual = swap;
  }
  return previa[b.length];
}
