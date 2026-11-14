/// País de América Latina: nacionalidad, moneda y teléfono.
class PaisLatam {
  const PaisLatam({
    required this.codigo,
    required this.nombre,
    required this.nacionalidad,
    required this.moneda,
    required this.nombreMoneda,
    required this.prefijo,
    required this.ejemplo,
  });

  /// ISO 3166-1 alfa-2.
  final String codigo;
  final String nombre;

  /// Gentilicio en femenino, como se muestra en el apartado de nacionalidad.
  final String nacionalidad;

  /// ISO 4217.
  final String moneda;
  final String nombreMoneda;

  /// Característica internacional, con el signo +.
  final String prefijo;

  /// Ejemplo del número local, sin la característica.
  final String ejemplo;

  String get prefijoDigitos => prefijo.replaceAll(RegExp(r'\D'), '');

  String get etiquetaNacionalidad => '$nombre — $nacionalidad';

  String get etiquetaMoneda => '$nombreMoneda ($moneda)';
}

const paisesLatam = <PaisLatam>[
  PaisLatam(codigo: 'AR', nombre: 'Argentina', nacionalidad: 'argentina', moneda: 'ARS', nombreMoneda: 'Peso argentino', prefijo: '+54', ejemplo: '11 2345-6789'),
  PaisLatam(codigo: 'BO', nombre: 'Bolivia', nacionalidad: 'boliviana', moneda: 'BOB', nombreMoneda: 'Boliviano', prefijo: '+591', ejemplo: '71234567'),
  PaisLatam(codigo: 'BR', nombre: 'Brasil', nacionalidad: 'brasileña', moneda: 'BRL', nombreMoneda: 'Real brasileño', prefijo: '+55', ejemplo: '11 91234-5678'),
  PaisLatam(codigo: 'CL', nombre: 'Chile', nacionalidad: 'chilena', moneda: 'CLP', nombreMoneda: 'Peso chileno', prefijo: '+56', ejemplo: '9 1234 5678'),
  PaisLatam(codigo: 'CO', nombre: 'Colombia', nacionalidad: 'colombiana', moneda: 'COP', nombreMoneda: 'Peso colombiano', prefijo: '+57', ejemplo: '300 123 4567'),
  PaisLatam(codigo: 'CR', nombre: 'Costa Rica', nacionalidad: 'costarricense', moneda: 'CRC', nombreMoneda: 'Colón costarricense', prefijo: '+506', ejemplo: '6123 4567'),
  PaisLatam(codigo: 'CU', nombre: 'Cuba', nacionalidad: 'cubana', moneda: 'CUP', nombreMoneda: 'Peso cubano', prefijo: '+53', ejemplo: '5 1234567'),
  PaisLatam(codigo: 'EC', nombre: 'Ecuador', nacionalidad: 'ecuatoriana', moneda: 'USD', nombreMoneda: 'Dólar estadounidense', prefijo: '+593', ejemplo: '99 123 4567'),
  PaisLatam(codigo: 'SV', nombre: 'El Salvador', nacionalidad: 'salvadoreña', moneda: 'USD', nombreMoneda: 'Dólar estadounidense', prefijo: '+503', ejemplo: '7123 4567'),
  PaisLatam(codigo: 'GT', nombre: 'Guatemala', nacionalidad: 'guatemalteca', moneda: 'GTQ', nombreMoneda: 'Quetzal', prefijo: '+502', ejemplo: '5123 4567'),
  PaisLatam(codigo: 'HT', nombre: 'Haití', nacionalidad: 'haitiana', moneda: 'HTG', nombreMoneda: 'Gourde', prefijo: '+509', ejemplo: '34 12 3456'),
  PaisLatam(codigo: 'HN', nombre: 'Honduras', nacionalidad: 'hondureña', moneda: 'HNL', nombreMoneda: 'Lempira', prefijo: '+504', ejemplo: '9123 4567'),
  PaisLatam(codigo: 'MX', nombre: 'México', nacionalidad: 'mexicana', moneda: 'MXN', nombreMoneda: 'Peso mexicano', prefijo: '+52', ejemplo: '55 1234 5678'),
  PaisLatam(codigo: 'NI', nombre: 'Nicaragua', nacionalidad: 'nicaragüense', moneda: 'NIO', nombreMoneda: 'Córdoba', prefijo: '+505', ejemplo: '8123 4567'),
  PaisLatam(codigo: 'PA', nombre: 'Panamá', nacionalidad: 'panameña', moneda: 'PAB', nombreMoneda: 'Balboa', prefijo: '+507', ejemplo: '6123 4567'),
  PaisLatam(codigo: 'PY', nombre: 'Paraguay', nacionalidad: 'paraguaya', moneda: 'PYG', nombreMoneda: 'Guaraní', prefijo: '+595', ejemplo: '981 123 456'),
  PaisLatam(codigo: 'PE', nombre: 'Perú', nacionalidad: 'peruana', moneda: 'PEN', nombreMoneda: 'Sol', prefijo: '+51', ejemplo: '912 345 678'),
  PaisLatam(codigo: 'DO', nombre: 'República Dominicana', nacionalidad: 'dominicana', moneda: 'DOP', nombreMoneda: 'Peso dominicano', prefijo: '+1', ejemplo: '809 123 4567'),
  PaisLatam(codigo: 'UY', nombre: 'Uruguay', nacionalidad: 'uruguaya', moneda: 'UYU', nombreMoneda: 'Peso uruguayo', prefijo: '+598', ejemplo: '94 123 456'),
  PaisLatam(codigo: 'VE', nombre: 'Venezuela', nacionalidad: 'venezolana', moneda: 'VES', nombreMoneda: 'Bolívar', prefijo: '+58', ejemplo: '412 123 4567'),
  PaisLatam(codigo: 'BZ', nombre: 'Belice', nacionalidad: 'beliceña', moneda: 'BZD', nombreMoneda: 'Dólar beliceño', prefijo: '+501', ejemplo: '612 3456'),
  PaisLatam(codigo: 'GY', nombre: 'Guyana', nacionalidad: 'guyanesa', moneda: 'GYD', nombreMoneda: 'Dólar guyanés', prefijo: '+592', ejemplo: '612 3456'),
  PaisLatam(codigo: 'SR', nombre: 'Surinam', nacionalidad: 'surinamesa', moneda: 'SRD', nombreMoneda: 'Dólar surinamés', prefijo: '+597', ejemplo: '812 3456'),
  PaisLatam(codigo: 'PR', nombre: 'Puerto Rico', nacionalidad: 'puertorriqueña', moneda: 'USD', nombreMoneda: 'Dólar estadounidense', prefijo: '+1', ejemplo: '787 123 4567'),
];

const codigosMonedaLatam = <String>{
  'USD',
  'EUR',
  'ARS',
  'BOB',
  'BRL',
  'CLP',
  'COP',
  'CRC',
  'CUP',
  'GTQ',
  'HTG',
  'HNL',
  'MXN',
  'NIO',
  'PAB',
  'PYG',
  'PEN',
  'DOP',
  'UYU',
  'VES',
  'BZD',
  'GYD',
  'SRD',
};

/// Una fila por código de moneda, en el orden del catálogo.
List<PaisLatam> monedasParaElegir() {
  final vistos = <String>{};
  return [
    for (final pais in paisesLatam)
      if (vistos.add(pais.moneda)) pais,
  ];
}

PaisLatam? paisPorCodigo(String? codigo) {
  final limpio = (codigo ?? '').trim().toUpperCase();
  for (final pais in paisesLatam) {
    if (pais.codigo == limpio) return pais;
  }
  return null;
}

String normalizarMonedaLatam(String? codigo) {
  final limpio = (codigo ?? '').trim().toUpperCase();
  if (codigosMonedaLatam.contains(limpio)) return limpio;
  return 'USD';
}

String soloDigitos(String numero) => numero.replaceAll(RegExp(r'\D'), '');

/// Número local para mostrar, sin la característica si ya venía guardada.
String telefonoLocal(String guardado, PaisLatam? pais) {
  final digitos = soloDigitos(guardado);
  if (pais == null) return digitos;
  final prefijo = pais.prefijoDigitos;
  if (prefijo.isNotEmpty && digitos.startsWith(prefijo) && digitos.length > prefijo.length) {
    return digitos.substring(prefijo.length);
  }
  return digitos;
}

/// Agrega la característica del país si el número todavía no la tiene.
String telefonoConPrefijo(String numero, PaisLatam? pais) {
  var digitos = soloDigitos(numero);
  if (digitos.isEmpty || pais == null) return digitos;
  if (digitos.startsWith('0')) digitos = digitos.replaceFirst(RegExp(r'^0+'), '');
  final prefijo = pais.prefijoDigitos;
  if (prefijo.isEmpty || digitos.startsWith(prefijo)) return digitos;
  return '$prefijo$digitos';
}
