import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/apariencia_tienda.dart';
import '../data/diseno_tienda.dart';
import '../data/funciones_asistente.dart';
import '../data/paises_latam.dart';

/// Rubro local. La detección no llama a ninguna API.
class RubroDefinicion {
  const RubroDefinicion({
    required this.id,
    required this.nombre,
    required this.categorias,
    required this.atributos,
    required this.tipoTienda,
    required this.nota,
    this.palabras = const [],
    this.prefijos = const [],
  });

  final String id;
  final String nombre;
  final List<String> categorias;
  final List<String> atributos;
  final String tipoTienda;
  final String nota;
  final List<String> palabras;
  final List<String> prefijos;

  bool coincide(String textoNormalizado) {
    for (final token in textoNormalizado.split(RegExp(r'[^a-z0-9]+'))) {
      if (token.isEmpty) continue;
      for (final palabra in palabras) {
        if (_esPalabraOPlural(token, palabra)) return true;
      }
      for (final prefijo in prefijos) {
        if (prefijo.length >= 4 && token.startsWith(prefijo)) return true;
      }
    }
    return false;
  }
}

class CatalogoRubros {
  static const tecnologia = RubroDefinicion(
    id: 'tecnologia',
    nombre: 'Tecnología',
    categorias: ['Celulares', 'Accesorios'],
    atributos: [
      'Marca',
      'Modelo',
      'Almacenamiento',
      'Estado',
      'Número de serie'
    ],
    tipoTienda: 'Catálogo',
    nota:
        'Pensada para equipos y accesorios, con marca, modelo y número de serie.',
    palabras: [
      'pc',
      'imei',
      'android',
      'iphone',
      'tablet',
      'notebook',
      'smartphone',
      'auricular',
      'cargador',
      'consola',
      'televisor',
      'tv',
    ],
    prefijos: ['celu', 'tecno', 'telefon', 'comput'],
  );

  static const indumentaria = RubroDefinicion(
    id: 'indumentaria',
    nombre: 'Indumentaria',
    categorias: ['Ropa', 'Calzado', 'Accesorios'],
    atributos: ['Talle', 'Color', 'Género', 'Material'],
    tipoTienda: 'Catálogo',
    nota: 'Pensada para ropa y calzado, con talle, color, género y material.',
    palabras: [
      'ropa',
      'moda',
      'talle',
      'calzado',
      'jean',
      'buzo',
      'camisa',
      'campera',
      'pollera',
      'vestido',
      'camiseta',
      'gorra',
      'sueter',
      'sweater',
      'hoodie',
    ],
    prefijos: ['indument', 'remer', 'pantalon', 'zapat'],
  );

  static const gastronomia = RubroDefinicion(
    id: 'gastronomia',
    nombre: 'Gastronomía',
    categorias: ['Comidas', 'Bebidas'],
    atributos: ['Tamaño', 'Variante'],
    tipoTienda: 'Menú',
    nota:
        'Pensada para comidas y bebidas. Si es el único rubro, la tienda queda como Menú.',
    palabras: [
      'comida',
      'menu',
      'plato',
      'bebida',
      'pizza',
      'empanada',
      'helado',
      'milanesa',
      'hamburguesa',
      'bar',
      'cafe',
      'roti',
      'panaderia',
      'heladeria',
      'cafeteria',
      'restaurante',
      'restaurant',
      'medialuna',
      'sandwich',
      'lomito',
      'asado',
      'parrilla',
      'postre',
    ],
    prefijos: ['gastro'],
  );

  static const rotiseria = RubroDefinicion(
    id: 'rotiseria',
    nombre: 'Rotisería',
    categorias: ['Minutas', 'Viandas', 'Bebidas'],
    atributos: ['Tamaño', 'Variante', 'Guarnición'],
    tipoTienda: 'Menú',
    nota: 'Pensada para rotisería y minutas. La tienda se muestra como menú.',
    palabras: ['rotiseria', 'vianda', 'minuta', 'guarnicion'],
    prefijos: ['rotis'],
  );

  static const cosmeticos = RubroDefinicion(
    id: 'cosmeticos',
    nombre: 'Cosméticos',
    categorias: ['Maquillaje', 'Cuidado de la piel', 'Cabello'],
    atributos: ['Marca', 'Tono', 'Presentación'],
    tipoTienda: 'Catálogo',
    nota: 'Pensada para cosmética, con marca, tono y presentación.',
    palabras: [
      'cosmetico',
      'maquillaje',
      'labial',
      'rimel',
      'shampoo',
      'skincare'
    ],
    prefijos: ['cosmet', 'maquill'],
  );

  static const servicios = RubroDefinicion(
    id: 'servicios',
    nombre: 'Servicios',
    categorias: ['Servicios'],
    atributos: ['Duración', 'Modalidad'],
    tipoTienda: 'Catálogo',
    nota: 'Pensada para turnos y servicios, con duración y modalidad.',
    palabras: ['servicio', 'peluqueria', 'manicura', 'reparacion', 'taller'],
    prefijos: ['servic'],
  );

  static const perfumes = RubroDefinicion(
    id: 'perfumes',
    nombre: 'Perfumes',
    categorias: ['Perfumes', 'Sets'],
    atributos: ['Marca', 'Concentración', 'Género'],
    tipoTienda: 'Catálogo',
    nota: 'Pensada para fragancias, con marca, concentración y género.',
    palabras: ['perfume', 'fragancia', 'colonia'],
    prefijos: ['perfum', 'fraganc'],
  );

  static const general = RubroDefinicion(
    id: 'general',
    nombre: 'General',
    categorias: ['Productos'],
    atributos: ['Nombre', 'Precio'],
    tipoTienda: 'Catálogo',
    nota: 'Una base simple, con productos, nombre y precio.',
  );

  static const detectables = [
    tecnologia,
    indumentaria,
    gastronomia,
    rotiseria,
    cosmeticos,
    servicios,
    perfumes,
  ];
  static const todos = [
    tecnologia,
    indumentaria,
    gastronomia,
    rotiseria,
    cosmeticos,
    servicios,
    perfumes,
    general,
  ];

  static List<RubroDefinicion> enOrden(Iterable<String> ids) {
    final pedidos = ids.toSet();
    return [
      for (final rubro in todos)
        if (pedidos.contains(rubro.id)) rubro,
    ];
  }
}

bool _esRubroMenu(RubroDefinicion rubro) =>
    rubro.id == CatalogoRubros.gastronomia.id ||
    rubro.id == CatalogoRubros.rotiseria.id;

class PropuestaRubro {
  const PropuestaRubro({
    required this.plantilla,
    required this.categorias,
    required this.atributos,
    required this.tipoTienda,
    required this.nota,
    required this.rubros,
  });

  final String plantilla;
  final List<String> categorias;
  final List<String> atributos;
  final String tipoTienda;
  final String nota;

  /// Nombres visibles, por ejemplo Tecnología e Indumentaria.
  final List<String> rubros;

  static List<String> detectarIds(String descripcion) {
    final texto = _normalizar(descripcion);
    return [
      for (final rubro in CatalogoRubros.detectables)
        if (rubro.coincide(texto)) rubro.id,
    ];
  }

  static PropuestaRubro desdeDescripcion(String descripcion) {
    return desdeIds(detectarIds(descripcion));
  }

  /// Une los rubros elegidos. El orden es el del catálogo, no el del toque.
  static PropuestaRubro desdeIds(Iterable<String> ids) {
    final elegidos = CatalogoRubros.enOrden(ids);
    if (elegidos.isEmpty) {
      return const PropuestaRubro(
        plantilla: '',
        categorias: [],
        atributos: [],
        tipoTienda: 'Catálogo',
        nota: 'Elegí al menos un rubro para armar la propuesta.',
        rubros: [],
      );
    }
    final todosMenu = elegidos.every(_esRubroMenu);
    final mezclaComida = !todosMenu && elegidos.any(_esRubroMenu);
    final nota = elegidos.length == 1
        ? elegidos.single.nota
        : mezclaComida
            ? 'Mezclás comida con otro rubro: la tienda queda como Catálogo y se conservan las categorías de ambos.'
            : 'Juntamos las categorías y los atributos de cada rubro, sin repetir.';
    return PropuestaRubro(
      plantilla: elegidos.map((rubro) => rubro.nombre).join(' + '),
      categorias: _unir(elegidos.map((rubro) => rubro.categorias)),
      atributos: _unir(elegidos.map((rubro) => rubro.atributos)),
      tipoTienda: todosMenu ? 'Menú' : 'Catálogo',
      nota: nota,
      rubros: [for (final rubro in elegidos) rubro.nombre],
    );
  }
}

class MiembroEquipo {
  const MiembroEquipo({
    required this.nombre,
    required this.rol,
    this.activo = true,
    this.codigo = '',
    this.email = '',
  });

  final String nombre;
  final String rol;
  final bool activo;

  /// Código propio para entrar al negocio. No es el código del negocio.
  final String codigo;

  /// Cuenta que ya usó el código. Vacío hasta que alguien entra.
  final String email;

  String get etiquetaRol =>
      rol == 'administrador' ? 'Administrador' : 'Vendedor';

  MiembroEquipo copiar({
    String? nombre,
    String? rol,
    bool? activo,
    String? codigo,
    String? email,
  }) {
    return MiembroEquipo(
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      codigo: codigo ?? this.codigo,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'rol': rol,
        'activo': activo,
        'codigo': codigo,
        'email': email,
      };

  factory MiembroEquipo.fromJson(Map<String, dynamic> json) {
    final rol = json['rol'] as String? ?? 'vendedor';
    return MiembroEquipo(
      nombre: (json['nombre'] as String? ?? '').trim(),
      rol: rol == 'administrador' ? 'administrador' : 'vendedor',
      activo: json['activo'] as bool? ?? true,
      codigo: (json['codigo'] as String? ?? '').trim().toUpperCase(),
      email: (json['email'] as String? ?? '').trim(),
    );
  }
}

class NegocioLocal {
  const NegocioLocal({
    required this.nombre,
    required this.descripcion,
    required this.codigo,
    required this.rol,
    required this.configurado,
    required this.plantilla,
    required this.rubros,
    required this.categorias,
    required this.atributos,
    required this.tipoTienda,
    this.duenoEmail = '',
    this.slug = '',
    this.tiendaActiva = false,
    this.whatsapp = '',
    this.mensajePublico = '',
    this.horario = '',
    this.aliasCobro = '',
    this.logoUrl = '',
    this.asistenteListo,
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.mapsUrl = '',
    this.latitud,
    this.longitud,
    this.equipo = const [],
    this.moneda = 'USD',
    this.pais = '',
    this.nacionalidad = '',
    this.apariencia = const AparienciaTienda(),
    this.diseno = const DisenoTienda(),
    this.funciones = const FuncionesAsistente(),
  });

  final String nombre;
  final String descripcion;
  final String codigo;
  final String rol;
  final bool configurado;
  final String plantilla;
  final List<String> rubros;
  final List<String> categorias;
  final List<String> atributos;
  final String tipoTienda;

  /// Código ISO 4217 en mayúsculas. USD si el negocio se guardó sin este campo.
  final String moneda;

  /// ISO 3166-1 alfa-2. Vacío si todavía no eligió nacionalidad.
  final String pais;

  /// Gentilicio guardado junto con el país, por ejemplo "argentina".
  final String nacionalidad;

  /// Colores, forma y textos de la vidriera. Solo valores predefinidos.
  final AparienciaTienda apariencia;

  /// Presentación según el rubro. Viaja en `apariencia.layout`.
  final DisenoTienda diseno;

  /// Lo que el asistente puede hacer. Viaja en `apariencia.funcionesAsistente`.
  final FuncionesAsistente funciones;

  /// Email de la sesión que creó o confirmó el negocio. Vacío en JSON viejo.
  final String duenoEmail;
  final String slug;
  final bool tiendaActiva;
  final String whatsapp;
  final String mensajePublico;

  /// Horario de atención, en texto libre. La columna ya existe en `negocios`.
  final String horario;

  /// CBU, CVU o alias, en un solo texto. Vacío si el negocio no lo cargó.
  final String aliasCobro;

  /// Dirección pública del logo. Vacía si todavía no eligió uno.
  final String logoUrl;

  /// Enlace de Facebook de la página. Vacío si el negocio no lo cargó.
  final String facebookUrl;

  /// Enlace de Instagram de la página. Vacío si el negocio no lo cargó.
  final String instagramUrl;

  /// Enlace de Google Maps o dirección del local. Vacío si no se cargó.
  final String mapsUrl;

  /// Punto del local elegido en el buscador. Nulo si todavía no hay uno.
  final double? latitud;
  final double? longitud;

  /// Personas del negocio, además del dueño. Como máximo cinco.
  final List<MiembroEquipo> equipo;

  /// Null en un negocio guardado antes del asistente: no se lo vuelve a mostrar.
  /// False si la cuenta es nueva y todavía no lo terminó.
  final bool? asistenteListo;

  /// Cuenta nueva, o un alta que todavía no confirmó el rubro.
  bool get necesitaAsistente {
    if (asistenteListo == true) return false;
    if (asistenteListo == false) return true;
    return !configurado;
  }

  static const cupoEquipo = 5;

  /// Códigos de América Latina, más el euro por si un negocio ya lo tenía.
  static final monedasAdmitidas = codigosMonedaLatam.toList();

  /// Deja solo un código de [monedasAdmitidas]. Cualquier otro valor vuelve a USD.
  static String normalizarMoneda(String? codigo) =>
      normalizarMonedaLatam(codigo);

  MiembroEquipo? miembroConEmail(String email) {
    final clave = email.trim().toLowerCase();
    if (clave.isEmpty) return null;
    for (final miembro in equipo) {
      if (miembro.email.trim().toLowerCase() == clave) return miembro;
    }
    return null;
  }

  MiembroEquipo? miembroConCodigo(String codigo) {
    final clave = codigo.trim().toUpperCase();
    if (clave.isEmpty) return null;
    for (final miembro in equipo) {
      if (miembro.codigo.toUpperCase() == clave) return miembro;
    }
    return null;
  }

  NegocioLocal copiar({
    String? nombre,
    String? descripcion,
    String? rol,
    bool? configurado,
    String? plantilla,
    List<String>? rubros,
    List<String>? categorias,
    List<String>? atributos,
    String? tipoTienda,
    String? duenoEmail,
    String? slug,
    bool? tiendaActiva,
    String? whatsapp,
    String? mensajePublico,
    String? horario,
    String? aliasCobro,
    String? logoUrl,
    String? facebookUrl,
    String? instagramUrl,
    String? mapsUrl,
    double? latitud,
    double? longitud,
    bool punto = false,
    List<MiembroEquipo>? equipo,
    String? moneda,
    String? pais,
    String? nacionalidad,
    AparienciaTienda? apariencia,
    DisenoTienda? diseno,
    FuncionesAsistente? funciones,
    bool? asistenteListo,
  }) {
    return NegocioLocal(
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      codigo: codigo,
      rol: rol ?? this.rol,
      configurado: configurado ?? this.configurado,
      plantilla: plantilla ?? this.plantilla,
      rubros: rubros ?? this.rubros,
      categorias: categorias ?? this.categorias,
      atributos: atributos ?? this.atributos,
      tipoTienda: tipoTienda ?? this.tipoTienda,
      duenoEmail: duenoEmail ?? this.duenoEmail,
      slug: slug ?? this.slug,
      tiendaActiva: tiendaActiva ?? this.tiendaActiva,
      whatsapp: whatsapp ?? this.whatsapp,
      mensajePublico: mensajePublico ?? this.mensajePublico,
      horario: horario ?? this.horario,
      aliasCobro: aliasCobro ?? this.aliasCobro,
      logoUrl: logoUrl ?? this.logoUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      mapsUrl: mapsUrl ?? this.mapsUrl,
      latitud: punto ? latitud : this.latitud,
      longitud: punto ? longitud : this.longitud,
      equipo: equipo ?? this.equipo,
      moneda: moneda == null ? this.moneda : normalizarMoneda(moneda),
      pais: pais ?? this.pais,
      nacionalidad: nacionalidad ?? this.nacionalidad,
      apariencia: apariencia ?? this.apariencia,
      diseno: diseno ?? this.diseno,
      funciones: funciones ?? this.funciones,
      asistenteListo: asistenteListo ?? this.asistenteListo,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'codigo': codigo,
        'rol': rol,
        'configurado': configurado,
        'plantilla': plantilla,
        'rubros': rubros,
        'categorias': categorias,
        'atributos': atributos,
        'tipoTienda': tipoTienda,
        'duenoEmail': duenoEmail,
        'slug': slug,
        'tiendaActiva': tiendaActiva,
        'whatsapp': whatsapp,
        'mensajePublico': mensajePublico,
        'horario': horario,
        'aliasCobro': aliasCobro,
        'logoUrl': logoUrl,
        if (asistenteListo != null) 'asistenteListo': asistenteListo,
        'facebookUrl': facebookUrl,
        'instagramUrl': instagramUrl,
        'mapsUrl': mapsUrl,
        if (latitud != null) 'latitud': latitud,
        if (longitud != null) 'longitud': longitud,
        'equipo': [for (final miembro in equipo) miembro.toJson()],
        'moneda': normalizarMoneda(moneda),
        'pais': pais.trim().toUpperCase(),
        'nacionalidad': nacionalidad.trim(),
        'apariencia': aparienciaConDiseno(),
      };

  /// `apariencia` de siempre, más el diseño y las funciones del asistente.
  Map<String, dynamic> aparienciaConDiseno() => {
        ...apariencia.toJson(),
        'layout': diseno.toJson(),
        FuncionesAsistente.clave: funciones.toJson(),
      };

  factory NegocioLocal.fromJson(Map<String, dynamic> json) {
    return NegocioLocal(
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      codigo: json['codigo'] as String? ?? '',
      rol: json['rol'] as String? ?? 'administrador',
      configurado: json['configurado'] as bool? ?? false,
      plantilla: json['plantilla'] as String? ?? '',
      rubros: _rubrosLeidos(json),
      categorias: [
        for (final item in (json['categorias'] as List<dynamic>? ?? const []))
          item.toString(),
      ],
      atributos: [
        for (final item in (json['atributos'] as List<dynamic>? ?? const []))
          item.toString(),
      ],
      tipoTienda: json['tipoTienda'] as String? ?? 'Catálogo',
      duenoEmail: json['duenoEmail'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      tiendaActiva: json['tiendaActiva'] as bool? ?? false,
      whatsapp: json['whatsapp'] as String? ?? '',
      mensajePublico: json['mensajePublico'] as String? ?? '',
      horario: json['horario'] as String? ?? '',
      aliasCobro: json['aliasCobro'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      asistenteListo: json.containsKey('asistenteListo')
          ? json['asistenteListo'] == true
          : null,
      facebookUrl: json['facebookUrl'] as String? ?? '',
      instagramUrl: json['instagramUrl'] as String? ?? '',
      mapsUrl: json['mapsUrl'] as String? ?? '',
      latitud: _coord(json['latitud']),
      longitud: _coord(json['longitud']),
      equipo: [
        for (final item in (json['equipo'] as List<dynamic>? ?? const []))
          if (item is Map)
            MiembroEquipo.fromJson(Map<String, dynamic>.from(item)),
      ].where((miembro) => miembro.nombre.isNotEmpty).take(cupoEquipo).toList(),
      moneda: normalizarMoneda(json['moneda']?.toString()),
      pais: (json['pais'] as String? ?? '').trim().toUpperCase(),
      nacionalidad: (json['nacionalidad'] as String? ?? '').trim(),
      apariencia: AparienciaTienda.desde(json['apariencia']),
      diseno: DisenoTienda.desdeApariencia(
        json['apariencia'],
        rubros: _rubrosLeidos(json),
      ),
      funciones: FuncionesAsistente.desde(json['apariencia']),
    );
  }
}

/// Moneda del negocio guardado en este dispositivo.
Future<String> monedaDelNegocio() async {
  try {
    final negocio = await NegocioStore().leer();
    return NegocioLocal.normalizarMoneda(negocio?.moneda);
  } catch (_) {
    return NegocioLocal.normalizarMoneda(null);
  }
}

class NegocioStore {
  static const _clave = 'negocio_gexi_v1';

  /// Si main lo registra, se llama después de crear o confirmar.
  /// Un fallo remoto no deshace el guardado local.
  static Future<void> Function(NegocioLocal negocio)? alPublicar;

  /// Categorías de la tabla `categorias`, además del arreglo del negocio.
  static Future<void> Function(List<String> categorias)? alGuardarCatalogo;

  /// Deja el negocio en el teléfono sin volver a publicarlo.
  Future<void> guardarLocal(NegocioLocal negocio) => _guardar(negocio);

  Future<NegocioLocal?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return null;
    try {
      final decoded = jsonDecode(crudo);
      if (decoded is! Map<String, dynamic>) return null;
      final negocio = NegocioLocal.fromJson(decoded);
      if (negocio.nombre.isEmpty) return null;
      return negocio;
    } catch (_) {
      return null;
    }
  }

  /// El JSON ya trae `moneda`. Si no, el negocio es anterior a este campo.
  Future<bool> tieneMonedaGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return false;
    try {
      final decoded = jsonDecode(crudo);
      return decoded is Map && decoded.containsKey('moneda');
    } catch (_) {
      return false;
    }
  }

  Future<NegocioLocal> asegurarParaVer() async {
    final actual = await leer();
    if (actual != null && actual.configurado) return actual;
    final propuesta = PropuestaRubro.desdeIds(const ['tecnologia']);
    final base = actual ??
        NegocioLocal(
          nombre: 'Novaceltec',
          descripcion: 'Vendo celulares nuevos y usados y accesorios',
          codigo: _codigo(),
          rol: 'administrador',
          configurado: false,
          plantilla: '',
          rubros: const [],
          categorias: const [],
          atributos: const [],
          tipoTienda: 'Catálogo',
        );
    final listo = base.copiar(
      configurado: true,
      plantilla: propuesta.plantilla,
      rubros: propuesta.rubros,
      categorias: propuesta.categorias,
      atributos: propuesta.atributos,
      tipoTienda: propuesta.tipoTienda,
      diseno: DisenoTienda.desdeRubros(propuesta.rubros),
    );
    await _guardar(listo);
    return listo;
  }

  Future<bool> tienePaisGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return false;
    try {
      final decoded = jsonDecode(crudo);
      return decoded is Map && decoded.containsKey('pais');
    } catch (_) {
      return false;
    }
  }

  Future<NegocioLocal> crear({
    required String nombre,
    required String descripcion,
    required String duenoEmail,
    String moneda = 'USD',
    String pais = '',
    String nacionalidad = '',
  }) async {
    final negocio = NegocioLocal(
      nombre: nombre.trim(),
      descripcion: descripcion.trim(),
      codigo: _codigo(),
      rol: 'administrador',
      configurado: false,
      plantilla: '',
      rubros: const [],
      categorias: const [],
      atributos: const [],
      tipoTienda: 'Catálogo',
      duenoEmail: duenoEmail.trim(),
      moneda: NegocioLocal.normalizarMoneda(moneda),
      pais: pais.trim().toUpperCase(),
      nacionalidad: nacionalidad.trim(),
      asistenteListo: false,
    );
    await _guardar(negocio);
    await _publicar(negocio);
    return negocio;
  }

  /// Une la cuenta al miembro cuyo código coincide.
  /// No cambia al dueño ni reemplaza el negocio.
  Future<NegocioLocal> unirEmpleado({
    required String codigo,
    required String email,
  }) async {
    final actual = await leer();
    if (actual == null || !actual.configurado) {
      throw StateError(
        'Ese código no corresponde a un negocio de este dispositivo.',
      );
    }
    final clave = codigo.trim().toUpperCase();
    if (clave.isEmpty) {
      throw StateError('Ingresá el código de empleado.');
    }
    if (clave == actual.codigo.trim().toUpperCase()) {
      throw StateError(
        'Ese es el código del negocio. Pedile tu código de empleado a quien administra.',
      );
    }
    final emailLimpio = email.trim();
    if (emailLimpio.isEmpty) {
      throw StateError('Necesitás una cuenta para unirte.');
    }
    if (actual.duenoEmail.trim().toLowerCase() == emailLimpio.toLowerCase()) {
      throw StateError('Esta cuenta ya es la dueña del negocio.');
    }
    final miembro = actual.miembroConCodigo(clave);
    if (miembro == null) {
      throw StateError('No encontramos ese código de empleado.');
    }
    if (!miembro.activo) {
      throw StateError(
        'Esa persona está inactiva. Un administrador tiene que activarla.',
      );
    }
    final yaVinculado = miembro.email.trim().toLowerCase();
    if (yaVinculado.isNotEmpty && yaVinculado != emailLimpio.toLowerCase()) {
      throw StateError('Ese código ya lo usa otra cuenta.');
    }
    final otro = actual.miembroConEmail(emailLimpio);
    if (otro != null && otro.codigo.toUpperCase() != clave) {
      throw StateError('Esta cuenta ya está en el equipo.');
    }
    final copia = [
      for (final item in actual.equipo)
        item.codigo.toUpperCase() == clave
            ? item.copiar(email: emailLimpio)
            : item,
    ];
    final actualizado = actual.copiar(equipo: copia);
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// Reemplaza el equipo del negocio. Máximo [NegocioLocal.cupoEquipo].
  Future<NegocioLocal?> guardarEquipo(List<MiembroEquipo> equipo) async {
    final actual = await leer();
    if (actual == null) return null;
    if (equipo.length > NegocioLocal.cupoEquipo) {
      throw StateError(
          'El equipo admite hasta ${NegocioLocal.cupoEquipo} personas.');
    }
    final limpio = <MiembroEquipo>[];
    final vistos = <String>{};
    final codigos = <String>{actual.codigo.trim().toUpperCase()};
    for (final miembro in equipo) {
      final nombre = miembro.nombre.trim();
      if (nombre.isEmpty) continue;
      final clave = nombre.toLowerCase();
      if (!vistos.add(clave)) continue;
      var codigo = miembro.codigo.trim().toUpperCase();
      if (codigo.isEmpty || !codigos.add(codigo)) {
        codigo = _codigoLibre(codigos);
      }
      limpio.add(
        MiembroEquipo(
          nombre: nombre,
          rol: miembro.rol == 'administrador' ? 'administrador' : 'vendedor',
          activo: miembro.activo,
          codigo: codigo,
          email: miembro.email.trim(),
        ),
      );
    }
    final actualizado = actual.copiar(equipo: limpio);
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// Nombre, oficio, país y moneda. No toca la página ni el equipo.
  Future<NegocioLocal?> guardarFicha({
    required String nombre,
    required String descripcion,
    required String moneda,
    required String pais,
    required String nacionalidad,
  }) async {
    final actual = await leer();
    if (actual == null) return null;
    final actualizado = actual.copiar(
      nombre: nombre.trim(),
      descripcion: descripcion.trim(),
      moneda: moneda,
      pais: pais.trim().toUpperCase(),
      nacionalidad: nacionalidad.trim(),
    );
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// WhatsApp del negocio, con característica. No publica ni oculta la página.
  Future<NegocioLocal?> guardarWhatsapp(String whatsapp) async {
    final actual = await leer();
    if (actual == null) return null;
    final actualizado = actual.copiar(whatsapp: whatsapp.trim());
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// Horario de atención. Si se cierra el asistente, la cuenta no lo vuelve a ver.
  Future<NegocioLocal?> guardarHorario(
    String horario, {
    bool cerrarAsistente = false,
  }) async {
    final actual = await leer();
    if (actual == null) return null;
    final actualizado = actual.copiar(
      horario: horario.trim(),
      asistenteListo: cerrarAsistente ? true : actual.asistenteListo,
    );
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// Actualiza únicamente la configuración de la página del negocio existente.
  Future<NegocioLocal?> guardarPagina({
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
    final actual = await leer();
    if (actual == null) return null;
    final actualizado = actual.copiar(
      slug: slug,
      tiendaActiva: tiendaActiva,
      whatsapp: whatsapp,
      mensajePublico: mensajePublico,
      aliasCobro: aliasCobro.trim(),
      facebookUrl: facebookUrl.trim(),
      instagramUrl: instagramUrl.trim(),
      mapsUrl: mapsUrl.trim(),
      latitud: latitud,
      longitud: longitud,
      punto: true,
    );
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// Guarda la dirección del logo en el teléfono y la vuelve a publicar.
  Future<NegocioLocal?> guardarLogo(String logoUrl) async {
    final actual = await leer();
    if (actual == null) return null;
    final actualizado = actual.copiar(logoUrl: logoUrl.trim());
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// Guarda la presentación. Al publicarse, el servidor deja una versión
  /// si `apariencia.layout` cambió.
  Future<NegocioLocal?> guardarDiseno(DisenoTienda diseno) async {
    diseno.validar();
    final actual = await leer();
    if (actual == null) return null;
    final actualizado = actual.copiar(diseno: diseno);
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// Guarda qué funciones puede usar el asistente. Viajan en `apariencia`.
  Future<NegocioLocal?> guardarFunciones(FuncionesAsistente funciones) async {
    final actual = await leer();
    if (actual == null) return null;
    final actualizado = actual.copiar(funciones: funciones);
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  /// Lee las funciones guardadas. Si no hay negocio, quedan prendidas.
  Future<FuncionesAsistente> leerFuncionesAsistente() async {
    try {
      final negocio = await leer();
      return negocio?.funciones ?? const FuncionesAsistente();
    } catch (_) {
      return const FuncionesAsistente();
    }
  }

  /// Guarda colores y forma de la vidriera en el teléfono y en Supabase.
  Future<NegocioLocal?> guardarApariencia(AparienciaTienda apariencia) async {
    final actual = await leer();
    if (actual == null) return null;
    final actualizado = actual.copiar(apariencia: apariencia);
    await _guardar(actualizado);
    await _publicar(actualizado);
    return actualizado;
  }

  Future<void> confirmar(
    NegocioLocal negocio,
    PropuestaRubro propuesta, {
    required String duenoEmail,
    AparienciaTienda? apariencia,
    DisenoTienda? diseno,
    List<String>? atributos,
    bool? asistenteListo,
  }) async {
    final disenoInicial = diseno ?? DisenoTienda.desdeRubros(propuesta.rubros);
    disenoInicial.validar();
    final confirmado = negocio.copiar(
      configurado: true,
      plantilla: propuesta.plantilla,
      rubros: propuesta.rubros,
      categorias: propuesta.categorias,
      atributos: atributos ?? propuesta.atributos,
      tipoTienda: propuesta.tipoTienda,
      duenoEmail: duenoEmail.trim(),
      asistenteListo: asistenteListo,
      diseno: disenoInicial,
      apariencia: apariencia ??
          AparienciaTienda.paraRubros(
            gastronomiaSola: propuesta.rubros.length == 1 &&
                propuesta.rubros.contains(CatalogoRubros.gastronomia.nombre),
            indumentaria:
                propuesta.rubros.contains(CatalogoRubros.indumentaria.nombre),
            tecnologia:
                propuesta.rubros.contains(CatalogoRubros.tecnologia.nombre),
          ),
    );
    await _guardar(confirmado);
    await _publicar(confirmado);
  }

  Future<void> _publicar(NegocioLocal negocio) async {
    final gancho = alPublicar;
    if (gancho == null) return;
    try {
      await gancho(negocio).timeout(const Duration(seconds: 20));
    } catch (_) {}
  }

  /// Reemplaza las categorías confirmadas, sin tocar el resto del negocio.
  Future<void> guardarCatalogo({required List<String> categorias}) async {
    final actual = await leer();
    if (actual == null) {
      throw StateError('Primero creá el negocio.');
    }
    final limpias = <String>[];
    for (final nombre in categorias) {
      final texto = nombre.trim();
      if (texto.isEmpty) continue;
      final repetida = limpias.any(
        (item) => item.toLowerCase() == texto.toLowerCase(),
      );
      if (!repetida) limpias.add(texto);
    }
    final actualizado = actual.copiar(categorias: limpias);
    await _guardar(actualizado);
    await _publicar(actualizado);
    final gancho = alGuardarCatalogo;
    if (gancho == null) return;
    try {
      await gancho(limpias).timeout(const Duration(seconds: 20));
    } catch (_) {}
  }

  Future<void> _guardar(NegocioLocal negocio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(negocio.toJson()));
  }

  String _codigo() => _codigoLibre({});

  String _codigoLibre(Set<String> usados) {
    const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    for (var intento = 0; intento < 40; intento++) {
      final codigo = List.generate(
        6,
        (_) => letras[random.nextInt(letras.length)],
      ).join();
      if (usados.add(codigo)) return codigo;
    }
    throw StateError('No se pudo crear un código de empleado.');
  }
}

const _sinAcento = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'ñ': 'n',
};

const _aliasPlantilla = {
  'tecnologia': 'Tecnología',
  'productos tecnologicos': 'Tecnología',
  'indumentaria': 'Indumentaria',
  'gastronomia': 'Gastronomía',
  'rotiseria': 'Rotisería',
  'cosmeticos': 'Cosméticos',
  'servicios': 'Servicios',
  'perfumes': 'Perfumes',
  'ropa': 'Indumentaria',
  'general': 'General',
};

String _normalizar(String texto) {
  final buffer = StringBuffer();
  for (final char in texto.toLowerCase().split('')) {
    buffer.write(_sinAcento[char] ?? char);
  }
  return buffer.toString();
}

bool _esPalabraOPlural(String token, String palabra) {
  if (palabra.isEmpty) return false;
  if (token == palabra) return true;
  if (!token.startsWith(palabra)) return false;
  final resto = token.substring(palabra.length);
  return resto == 's' || resto == 'es';
}

List<String> _unir(Iterable<List<String>> listas) {
  final vistos = <String>{};
  final salida = <String>[];
  for (final lista in listas) {
    for (final item in lista) {
      final clave = _normalizar(item);
      if (clave.isEmpty || !vistos.add(clave)) {
        continue;
      }
      salida.add(item);
    }
  }
  return salida;
}

/// Los negocios guardados antes de `rubros` la arman desde `plantilla`.
List<String> _rubrosLeidos(Map<String, dynamic> json) {
  if (json.containsKey('rubros')) {
    return _textos(json['rubros']);
  }
  return _nombresDesdePlantilla(json['plantilla'] as String? ?? '');
}

List<String> _nombresDesdePlantilla(String plantilla) {
  if (plantilla.trim().isEmpty) return const [];
  final nombres = <String>[];
  for (final parte in plantilla.split(RegExp(r'\s*\+\s*'))) {
    final clave = _normalizar(parte).trim().replaceAll(RegExp(r'\s+'), ' ');
    final nombre = _aliasPlantilla[clave];
    if (nombre != null && !nombres.contains(nombre)) {
      nombres.add(nombre);
    }
  }
  return nombres;
}

List<String> _textos(dynamic crudo) {
  if (crudo is! List) return const [];
  final vistos = <String>{};
  final salida = <String>[];
  for (final item in crudo) {
    final texto = item?.toString().trim() ?? '';
    if (texto.isEmpty || !vistos.add(texto)) {
      continue;
    }
    salida.add(texto);
  }
  return salida;
}

double? _coord(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor?.toString() ?? '');
}
