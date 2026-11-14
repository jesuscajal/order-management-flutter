class SubdominioTienda {
  static const dominioBase = 'gexi.com.ar';

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
    'assets',
    'icons',
    'fonts',
    'canvaskit',
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

  /// `gexi.com.ar/novaceltec` abre esa tienda. La raíz sigue siendo el ingreso.
  static String? slugDesdeRuta(String path) {
    final partes = [
      for (final parte in path.split('/'))
        if (parte.trim().isNotEmpty) parte.trim().toLowerCase(),
    ];
    if (partes.length != 1) return null;
    final slug = partes.first;
    if (validarSlug(slug) != null) return null;
    return slug;
  }

  static String urlPublica(String slug) {
    return 'https://$dominioBase/${slug.trim().toLowerCase()}';
  }

  static String? validarSlug(String slug) {
    if (slug.length < 3 || slug.length > 30) {
      return 'La dirección debe tener entre 3 y 30 caracteres.';
    }
    if (slug != slug.toLowerCase()) {
      return 'La dirección debe estar escrita en minúsculas.';
    }
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) {
      return 'Usá solo letras sin acentos, números y guiones.';
    }
    if (slug.startsWith('-') || slug.endsWith('-')) {
      return 'La dirección no puede empezar ni terminar con guion.';
    }
    if (slug.contains('--')) {
      return 'La dirección no puede contener guiones dobles.';
    }
    if (_reservados.contains(slug)) {
      return 'Esa dirección está reservada.';
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

  /// Si el nombre ya tiene dueño, la dirección suma el código del negocio.
  /// Ese código es único, así que dos tiendas no comparten la misma página.
  static String slugConCodigo(String base, String codigo) {
    final marca = codigo.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (marca.isEmpty) return sugerirSlug(base);
    final cupo = 30 - marca.length - 1;
    if (cupo < 1) return sugerirSlug(marca);
    var nombre = sugerirSlug(base);
    if (nombre.endsWith('-$marca')) {
      nombre = nombre.substring(0, nombre.length - marca.length - 1);
    }
    if (nombre.length > cupo) {
      nombre = nombre.substring(0, cupo).replaceFirst(RegExp(r'-+$'), '');
    }
    if (nombre.isEmpty || _reservados.contains(nombre)) nombre = 'tienda';
    final junto = '$nombre-$marca';
    return validarSlug(junto) == null ? junto : sugerirSlug(junto);
  }
}
