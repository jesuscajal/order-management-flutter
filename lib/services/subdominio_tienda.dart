class SubdominioTienda {
  static const dominioBase = 'gexi-novaceltec.com';

  static const _reservados = {
    'www',
    'app',
    'api',
    'admin',
    'mail',
    'gexi',
    'supabase',
    'tienda',
    'login',
    'static',
    'ftp',
    'smtp',
    'ns1',
    'ns2',
  };

  static const _sinAcento = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
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
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  static String? slugDesdeHost(String host) {
    var limpio = host.trim().toLowerCase();
    if (limpio.endsWith('.')) {
      limpio = limpio.substring(0, limpio.length - 1);
    }

    final separadorPuerto = limpio.lastIndexOf(':');
    if (separadorPuerto > 0) {
      final puerto = limpio.substring(separadorPuerto + 1);
      if (RegExp(r'^\d+$').hasMatch(puerto)) {
        limpio = limpio.substring(0, separadorPuerto);
      }
    }

    if (limpio == dominioBase ||
        limpio == 'www.$dominioBase' ||
        limpio == 'localhost' ||
        limpio == '127.0.0.1') {
      return null;
    }

    const sufijo = '.$dominioBase';
    if (!limpio.endsWith(sufijo)) return null;
    final slug = limpio.substring(0, limpio.length - sufijo.length);
    if (slug.contains('.') || validarSlug(slug) != null) return null;
    return slug;
  }

  static String urlPublica(String slug) {
    return 'https://${slug.trim().toLowerCase()}.$dominioBase';
  }

  static String? validarSlug(String slug) {
    if (slug.length < 3 || slug.length > 30) {
      return 'El subdominio debe tener entre 3 y 30 caracteres.';
    }
    if (slug != slug.toLowerCase()) {
      return 'El subdominio debe estar escrito en minúsculas.';
    }
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) {
      return 'Usá solo letras sin acentos, números y guiones.';
    }
    if (slug.startsWith('-') || slug.endsWith('-')) {
      return 'El subdominio no puede empezar ni terminar con guion.';
    }
    if (slug.contains('--')) {
      return 'El subdominio no puede contener guiones dobles.';
    }
    if (_reservados.contains(slug)) {
      return 'Ese subdominio está reservado.';
    }
    return null;
  }

  static String sugerirSlug(String nombre) {
    final normalizado = StringBuffer();
    for (final caracter in nombre.toLowerCase().split('')) {
      normalizado.write(_sinAcento[caracter] ?? caracter);
    }

    var slug = normalizado
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'mi-tienda';
    if (slug.length < 3 || _reservados.contains(slug)) {
      slug = '$slug-tienda';
    }
    if (slug.length > 30) {
      slug = slug.substring(0, 30).replaceFirst(RegExp(r'-+$'), '');
    }
    return slug;
  }
}
