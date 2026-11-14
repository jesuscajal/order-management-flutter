import 'dart:convert';

/// Presentación cerrada de la vidriera. Un solo dominio para todas las tiendas.
///
/// El color y la paleta siguen en `AparienciaTienda`. Este objeto no los
/// duplica. No admite HTML, CSS ni enlaces: solo las claves de abajo.
class DisenoTienda {
  const DisenoTienda({
    this.schemaVersion = esquemaVigente,
    this.plantillaId = 'general',
    this.fondo = 'claro',
    this.columnas = 2,
    this.mostrarBuscador = true,
    this.mostrarFiltros = true,
    this.mostrarHorario = false,
    this.mostrarRedes = true,
    this.mostrarWhatsapp = true,
    this.mostrarBanner = false,
    this.bannerTexto = '',
    this.bannerEstilo = 'simple',
  });

  /// Contrato actual. [validar] rechaza cualquier otro número.
  static const int esquemaVigente = 1;

  static const plantillas = [
    'menu',
    'tecnologia',
    'ropa',
    'cosmeticos',
    'servicios',
    'perfumes',
    'general',
  ];

  static const fondos = ['claro', 'oscuro'];
  static const estilosBanner = ['oferta', 'novedad', 'simple'];

  /// Mismo orden que el catálogo de rubros. El desempate entre varios
  /// rubros sigue esta lista.
  static const _ordenRubros = [
    'tecnologia',
    'indumentaria',
    'gastronomia',
    'rotiseria',
    'cosmeticos',
    'servicios',
    'perfumes',
    'general',
  ];

  final int schemaVersion;
  final String plantillaId;
  final String fondo;
  final int columnas;
  final bool mostrarBuscador;
  final bool mostrarFiltros;
  final bool mostrarHorario;
  final bool mostrarRedes;
  final bool mostrarWhatsapp;
  final bool mostrarBanner;
  final String bannerTexto;
  final String bannerEstilo;

  static const _menu = DisenoTienda(
    plantillaId: 'menu',
    fondo: 'claro',
    columnas: 1,
    mostrarBuscador: false,
    mostrarFiltros: false,
    mostrarHorario: true,
    mostrarRedes: true,
    mostrarWhatsapp: true,
    mostrarBanner: true,
    bannerEstilo: 'oferta',
  );

  static const _tecnologia = DisenoTienda(
    plantillaId: 'tecnologia',
    fondo: 'oscuro',
    columnas: 3,
    mostrarBuscador: true,
    mostrarFiltros: true,
    mostrarHorario: false,
    mostrarRedes: true,
    mostrarWhatsapp: true,
    mostrarBanner: true,
    bannerEstilo: 'novedad',
  );

  static const _ropa = DisenoTienda(
    plantillaId: 'ropa',
    fondo: 'claro',
    columnas: 2,
    mostrarBuscador: true,
    mostrarFiltros: true,
    mostrarHorario: false,
    mostrarRedes: true,
    mostrarWhatsapp: true,
    mostrarBanner: true,
    bannerEstilo: 'novedad',
  );

  static const _cosmeticos = DisenoTienda(
    plantillaId: 'cosmeticos',
    fondo: 'claro',
    columnas: 2,
    mostrarBuscador: true,
    mostrarFiltros: true,
    mostrarHorario: false,
    mostrarRedes: true,
    mostrarWhatsapp: true,
    mostrarBanner: true,
    bannerEstilo: 'oferta',
  );

  static const _servicios = DisenoTienda(
    plantillaId: 'servicios',
    fondo: 'claro',
    columnas: 1,
    mostrarBuscador: true,
    mostrarFiltros: false,
    mostrarHorario: true,
    mostrarRedes: true,
    mostrarWhatsapp: true,
    mostrarBanner: false,
    bannerEstilo: 'simple',
  );

  static const _perfumes = DisenoTienda(
    plantillaId: 'perfumes',
    fondo: 'oscuro',
    columnas: 2,
    mostrarBuscador: true,
    mostrarFiltros: false,
    mostrarHorario: false,
    mostrarRedes: true,
    mostrarWhatsapp: true,
    mostrarBanner: true,
    bannerEstilo: 'simple',
  );

  /// Diseño completo de una plantilla. Cambiar de plantilla reemplaza fondo,
  /// columnas y qué se muestra. No deja el cromo de la plantilla anterior.
  static DisenoTienda dePlantilla(String plantillaId) {
    switch (plantillaId) {
      case 'menu':
        return _menu;
      case 'tecnologia':
        return _tecnologia;
      case 'ropa':
        return _ropa;
      case 'cosmeticos':
        return _cosmeticos;
      case 'servicios':
        return _servicios;
      case 'perfumes':
        return _perfumes;
      default:
        return const DisenoTienda();
    }
  }

  /// Plantilla inicial de un rubro. Acepta el id estable o el nombre visible.
  ///
  /// Rotisería y gastronomía usan menú. Indumentaria (o «ropa») usa ropa.
  /// Un texto que no es un rubro usa la plantilla general.
  static DisenoTienda desdeRubro(String id) {
    switch (_rubroCanonico(id)) {
      case 'rotiseria':
      case 'gastronomia':
        return _menu;
      case 'tecnologia':
        return _tecnologia;
      case 'indumentaria':
        return _ropa;
      case 'cosmeticos':
        return _cosmeticos;
      case 'servicios':
        return _servicios;
      case 'perfumes':
        return _perfumes;
      default:
        return const DisenoTienda();
    }
  }

  /// Varios rubros. Gastronomía y rotisería dejan el menú si también hay
  /// otro rubro. Si no, queda el primero del catálogo.
  static DisenoTienda desdeRubros(Iterable<String> ids) {
    final presentes = <String>{};
    for (final id in ids) {
      final canonico = _rubroCanonico(id);
      if (canonico != null) presentes.add(canonico);
    }
    if (presentes.isEmpty) return const DisenoTienda();
    final ordenados = [
      for (final id in _ordenRubros)
        if (presentes.contains(id)) id,
    ];
    final hayOtraPlantilla = ordenados.any(
      (id) => desdeRubro(id).plantillaId != 'menu',
    );
    for (final id in ordenados) {
      final diseno = desdeRubro(id);
      if (hayOtraPlantilla && diseno.plantillaId == 'menu') continue;
      return diseno;
    }
    return desdeRubro(ordenados.first);
  }

  /// Lee `apariencia.layout`. Si no está, arma el diseño desde [rubros].
  static DisenoTienda desdeApariencia(
    Object? apariencia, {
    Iterable<String> rubros = const [],
  }) {
    final mapa = _mapa(apariencia);
    final layout = mapa == null ? null : _mapa(mapa['layout']);
    if (layout == null || layout.isEmpty) {
      return rubros.isEmpty ? const DisenoTienda() : desdeRubros(rubros);
    }
    return DisenoTienda.desdeJson(layout);
  }

  /// Tolera un layout ausente o incompleto y descarta claves desconocidas.
  /// Un valor inválido vuelve al default de la plantilla, no lanza.
  factory DisenoTienda.desdeJson(Object? crudo) {
    final mapa = _mapa(crudo);
    if (mapa == null || mapa.isEmpty) return const DisenoTienda();
    final plantilla = plantillas.contains(mapa['plantillaId'])
        ? mapa['plantillaId'] as String
        : 'general';
    final base = desdeRubro(_rubroDePlantilla(plantilla));
    final texto = mapa.containsKey('bannerTexto')
        ? _textoTolerante(mapa['bannerTexto'])
        : null;
    return DisenoTienda(
      schemaVersion: esquemaVigente,
      plantillaId: plantilla,
      fondo:
          fondos.contains(mapa['fondo']) ? mapa['fondo'] as String : base.fondo,
      columnas: _columnasDe(mapa['columnas']) ?? base.columnas,
      mostrarBuscador: mapa['mostrarBuscador'] is bool
          ? mapa['mostrarBuscador'] as bool
          : base.mostrarBuscador,
      mostrarFiltros: mapa['mostrarFiltros'] is bool
          ? mapa['mostrarFiltros'] as bool
          : base.mostrarFiltros,
      mostrarHorario: mapa['mostrarHorario'] is bool
          ? mapa['mostrarHorario'] as bool
          : base.mostrarHorario,
      mostrarRedes: mapa['mostrarRedes'] is bool
          ? mapa['mostrarRedes'] as bool
          : base.mostrarRedes,
      mostrarWhatsapp: mapa['mostrarWhatsapp'] is bool
          ? mapa['mostrarWhatsapp'] as bool
          : base.mostrarWhatsapp,
      mostrarBanner: mapa['mostrarBanner'] is bool
          ? mapa['mostrarBanner'] as bool
          : base.mostrarBanner,
      bannerTexto: texto ?? base.bannerTexto,
      bannerEstilo: estilosBanner.contains(mapa['bannerEstilo'])
          ? mapa['bannerEstilo'] as String
          : base.bannerEstilo,
    );
  }

  DisenoTienda copiar({
    int? schemaVersion,
    String? plantillaId,
    String? fondo,
    int? columnas,
    bool? mostrarBuscador,
    bool? mostrarFiltros,
    bool? mostrarHorario,
    bool? mostrarRedes,
    bool? mostrarWhatsapp,
    bool? mostrarBanner,
    String? bannerTexto,
    String? bannerEstilo,
  }) {
    return DisenoTienda(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      plantillaId: plantillaId ?? this.plantillaId,
      fondo: fondo ?? this.fondo,
      columnas: columnas ?? this.columnas,
      mostrarBuscador: mostrarBuscador ?? this.mostrarBuscador,
      mostrarFiltros: mostrarFiltros ?? this.mostrarFiltros,
      mostrarHorario: mostrarHorario ?? this.mostrarHorario,
      mostrarRedes: mostrarRedes ?? this.mostrarRedes,
      mostrarWhatsapp: mostrarWhatsapp ?? this.mostrarWhatsapp,
      mostrarBanner: mostrarBanner ?? this.mostrarBanner,
      bannerTexto: bannerTexto ?? this.bannerTexto,
      bannerEstilo: bannerEstilo ?? this.bannerEstilo,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'plantillaId': plantillaId,
        'fondo': fondo,
        'columnas': columnas,
        'mostrarBuscador': mostrarBuscador,
        'mostrarFiltros': mostrarFiltros,
        'mostrarHorario': mostrarHorario,
        'mostrarRedes': mostrarRedes,
        'mostrarWhatsapp': mostrarWhatsapp,
        'mostrarBanner': mostrarBanner,
        'bannerTexto': bannerTexto,
        'bannerEstilo': bannerEstilo,
      };

  /// Rechaza plantilla, columnas o textos fuera del contrato.
  void validar() {
    if (schemaVersion != esquemaVigente) {
      throw StateError('La versión del diseño no es válida.');
    }
    if (!plantillas.contains(plantillaId)) {
      throw StateError('La plantilla del diseño no es válida.');
    }
    if (!fondos.contains(fondo)) {
      throw StateError('El fondo tiene que ser claro u oscuro.');
    }
    if (columnas != 1 && columnas != 2 && columnas != 3) {
      throw StateError('Las columnas tienen que ser 1, 2 o 3.');
    }
    if (!estilosBanner.contains(bannerEstilo)) {
      throw StateError('El estilo del banner no es válido.');
    }
    final texto = bannerTexto.trim();
    if (texto.runes.length > 120) {
      throw StateError(
        'El texto del banner no puede superar 120 caracteres.',
      );
    }
    if (_prohibido(texto)) {
      throw StateError(
        'El texto del banner no puede incluir HTML, CSS ni enlaces.',
      );
    }
  }

  static String _rubroDePlantilla(String plantillaId) {
    switch (plantillaId) {
      case 'menu':
        return 'gastronomia';
      case 'tecnologia':
        return 'tecnologia';
      case 'ropa':
        return 'indumentaria';
      case 'cosmeticos':
        return 'cosmeticos';
      case 'servicios':
        return 'servicios';
      case 'perfumes':
        return 'perfumes';
      default:
        return 'general';
    }
  }

  static String? _rubroCanonico(String crudo) {
    final plano = _sinAcento(crudo).replaceAll(RegExp(r'\s+'), ' ');
    switch (plano) {
      case 'rotiseria':
        return 'rotiseria';
      case 'gastronomia':
        return 'gastronomia';
      case 'tecnologia':
      case 'productos tecnologicos':
        return 'tecnologia';
      case 'indumentaria':
      case 'ropa':
        return 'indumentaria';
      case 'cosmeticos':
      case 'cosmetico':
      case 'cosmetica':
        return 'cosmeticos';
      case 'servicios':
      case 'servicio':
        return 'servicios';
      case 'perfumes':
      case 'perfume':
        return 'perfumes';
      case 'general':
        return 'general';
      default:
        return null;
    }
  }

  static int? _columnasDe(Object? valor) {
    final numero = valor is int
        ? valor
        : valor is num
            ? valor.toInt()
            : int.tryParse(valor?.toString() ?? '');
    if (numero == 1 || numero == 2 || numero == 3) return numero;
    return null;
  }

  /// Texto usable, o null si hay que conservar el default de la plantilla.
  static String? _textoTolerante(Object? valor) {
    if (valor is! String) return null;
    final limpio = valor.trim();
    if (_prohibido(limpio)) return '';
    final runas = limpio.runes.toList();
    if (runas.length <= 120) return limpio;
    return String.fromCharCodes(runas.take(120));
  }

  static bool _prohibido(String texto) {
    if (texto.contains('<') || texto.contains('>')) return true;
    final bajo = texto.toLowerCase();
    if (bajo.contains('style=') || bajo.contains('url(')) return true;
    if (bajo.contains('javascript:')) return true;
    if (bajo.contains('http://') ||
        bajo.contains('https://') ||
        bajo.contains('www.')) {
      return true;
    }
    return RegExp(
      r'\b[a-z0-9-]+\.(com|net|org|ar|io|app|dev|shop|store)\b',
    ).hasMatch(bajo);
  }

  static Map<String, dynamic>? _mapa(Object? crudo) {
    if (crudo is Map) return Map<String, dynamic>.from(crudo);
    if (crudo is String && crudo.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(crudo);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static String _sinAcento(String texto) {
    const mapa = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final char in texto.toLowerCase().split('')) {
      buffer.write(mapa[char] ?? char);
    }
    return buffer.toString().trim();
  }

  @override
  bool operator ==(Object other) {
    return other is DisenoTienda &&
        other.schemaVersion == schemaVersion &&
        other.plantillaId == plantillaId &&
        other.fondo == fondo &&
        other.columnas == columnas &&
        other.mostrarBuscador == mostrarBuscador &&
        other.mostrarFiltros == mostrarFiltros &&
        other.mostrarHorario == mostrarHorario &&
        other.mostrarRedes == mostrarRedes &&
        other.mostrarWhatsapp == mostrarWhatsapp &&
        other.mostrarBanner == mostrarBanner &&
        other.bannerTexto == bannerTexto &&
        other.bannerEstilo == bannerEstilo;
  }

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        plantillaId,
        fondo,
        columnas,
        mostrarBuscador,
        mostrarFiltros,
        mostrarHorario,
        mostrarRedes,
        mostrarWhatsapp,
        mostrarBanner,
        bannerTexto,
        bannerEstilo,
      );
}
