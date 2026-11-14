import 'dart:convert';

/// Código QR en modo byte, versiones 1 a 6.
///
/// El proyecto no trae un paquete de QR, así que la matriz se arma acá
/// y un widget la pinta. Cada texto distinto produce módulos distintos.
class CodigoQr {
  /// Módulos oscuros en true, sin el margen blanco.
  /// [mascara] fija el patrón 0 a 7; si no se pasa, se elige el de menor penalización.
  static List<List<bool>> modulos(String texto, {int? mascara}) {
    final bytes = utf8.encode(texto);
    final nivel = _elegirNivel(bytes.length);
    if (nivel == null) {
      throw ArgumentError('El enlace es demasiado largo para el código QR.');
    }
    final datos = _empaquetar(bytes, nivel.totalDatos);
    final flujo = _entrelazar(datos, nivel);
    return _Armador(nivel, flujo).construir(mascara);
  }

  /// Símbolos de corrección Reed-Solomon. Sirve para comprobar el codificador.
  static List<int> simbolosDeCorreccion(List<int> datos, int cantidad) {
    return _Campo.resto(datos, cantidad);
  }
}

class _Nivel {
  const _Nivel(
    this.version,
    this.ecc,
    this.ecPorBloque,
    this.bloques,
    this.datosPorBloque,
  );

  /// 0 es corrección media (M) y 1 es baja (L). Esos mismos bits van al formato.
  final int version;
  final int ecc;
  final int ecPorBloque;
  final int bloques;
  final int datosPorBloque;

  int get totalDatos => bloques * datosPorBloque;

  int get tamano => 21 + (version - 1) * 4;
}

/// Primero la corrección media. La baja queda de reserva si el texto no entra.
const List<_Nivel> _niveles = [
  _Nivel(1, 0, 10, 1, 16),
  _Nivel(2, 0, 16, 1, 28),
  _Nivel(3, 0, 26, 1, 44),
  _Nivel(4, 0, 18, 2, 32),
  _Nivel(5, 0, 24, 2, 43),
  _Nivel(6, 0, 16, 4, 27),
  _Nivel(1, 1, 7, 1, 19),
  _Nivel(2, 1, 10, 1, 34),
  _Nivel(3, 1, 15, 1, 55),
  _Nivel(4, 1, 20, 1, 80),
  _Nivel(5, 1, 26, 1, 108),
  _Nivel(6, 1, 18, 2, 68),
];

const List<List<int>> _centrosAlineacion = [
  [],
  [],
  [6, 18],
  [6, 22],
  [6, 26],
  [6, 30],
  [6, 34],
];

_Nivel? _elegirNivel(int bytes) {
  if (bytes > 255) return null;
  final necesita = bytes + 2;
  _Nivel? mejor;
  for (final nivel in _niveles) {
    if (nivel.totalDatos < necesita) continue;
    final cabeMejor = mejor == null ||
        nivel.ecc < mejor.ecc ||
        (nivel.ecc == mejor.ecc && nivel.version < mejor.version);
    if (cabeMejor) mejor = nivel;
  }
  return mejor;
}

class _Bits {
  final List<int> _bytes = [];
  int longitud = 0;

  void agregar(int valor, int bits) {
    for (var i = bits - 1; i >= 0; i--) {
      final indice = longitud >> 3;
      if (_bytes.length == indice) _bytes.add(0);
      if (((valor >> i) & 1) == 1) {
        _bytes[indice] |= 1 << (7 - (longitud & 7));
      }
      longitud++;
    }
  }

  void alinear() {
    final resto = longitud & 7;
    if (resto != 0) agregar(0, 8 - resto);
  }

  List<int> bytes() => List<int>.from(_bytes);
}

List<int> _empaquetar(List<int> contenido, int capacidad) {
  final bits = _Bits()
    ..agregar(0x4, 4)
    ..agregar(contenido.length, 8);
  for (final byte in contenido) {
    bits.agregar(byte, 8);
  }
  final libres = capacidad * 8 - bits.longitud;
  if (libres < 0) {
    throw ArgumentError('El enlace es demasiado largo para el código QR.');
  }
  bits.agregar(0, libres < 4 ? libres : 4);
  bits.alinear();
  const relleno = [0xEC, 0x11];
  var turno = 0;
  while (bits.longitud + 8 <= capacidad * 8) {
    bits.agregar(relleno[turno & 1], 8);
    turno++;
  }
  final datos = bits.bytes();
  if (datos.length != capacidad) {
    throw StateError('El empaquetado del QR no completó los datos.');
  }
  return datos;
}

List<int> _entrelazar(List<int> datos, _Nivel nivel) {
  final bloques = <List<int>>[];
  var offset = 0;
  for (var i = 0; i < nivel.bloques; i++) {
    bloques.add(datos.sublist(offset, offset + nivel.datosPorBloque));
    offset += nivel.datosPorBloque;
  }
  final correcciones = [
    for (final bloque in bloques) _Campo.resto(bloque, nivel.ecPorBloque),
  ];
  final salida = <int>[];
  final largoMaximo = bloques.map((b) => b.length).reduce((a, b) => a > b ? a : b);
  for (var i = 0; i < largoMaximo; i++) {
    for (final bloque in bloques) {
      if (i < bloque.length) salida.add(bloque[i]);
    }
  }
  for (var i = 0; i < nivel.ecPorBloque; i++) {
    for (final correccion in correcciones) {
      salida.add(correccion[i]);
    }
  }
  return salida;
}

class _Campo {
  static final List<int> _exp = _armarExp();
  static final List<int> _log = _armarLog(_exp);

  static List<int> _armarExp() {
    final exp = List<int>.filled(512, 0);
    var x = 1;
    for (var i = 0; i < 255; i++) {
      exp[i] = x;
      x <<= 1;
      if (x >= 256) x ^= 0x11d;
    }
    for (var i = 255; i < 512; i++) {
      exp[i] = exp[i - 255];
    }
    return exp;
  }

  static List<int> _armarLog(List<int> exp) {
    final log = List<int>.filled(256, 0);
    for (var i = 0; i < 255; i++) {
      log[exp[i]] = i;
    }
    return log;
  }

  static int mul(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return _exp[_log[a] + _log[b]];
  }

  static List<int> _generador(int grado) {
    var poly = <int>[1];
    var raiz = 1;
    for (var i = 0; i < grado; i++) {
      final siguiente = List<int>.filled(poly.length + 1, 0);
      for (var j = 0; j < poly.length; j++) {
        siguiente[j] ^= poly[j];
        siguiente[j + 1] ^= mul(poly[j], raiz);
      }
      poly = siguiente;
      raiz = mul(raiz, 0x02);
    }
    return poly;
  }

  static List<int> resto(List<int> datos, int cantidad) {
    final gen = _generador(cantidad);
    final res = List<int>.from(datos)..addAll(List.filled(cantidad, 0));
    for (var i = 0; i < datos.length; i++) {
      final coef = res[i];
      if (coef == 0) continue;
      for (var j = 0; j < gen.length; j++) {
        res[i + j] ^= mul(gen[j], coef);
      }
    }
    return res.sublist(datos.length);
  }
}

class _Armador {
  _Armador(this.nivel, this.flujo)
      : tamano = nivel.tamano,
        modulos = List.generate(nivel.tamano, (_) => List.filled(nivel.tamano, false)),
        funcion = List.generate(nivel.tamano, (_) => List.filled(nivel.tamano, false));

  final _Nivel nivel;
  final List<int> flujo;
  final int tamano;
  final List<List<bool>> modulos;
  final List<List<bool>> funcion;

  List<List<bool>> construir(int? mascaraPedida) {
    _buscadores();
    _alineaciones();
    _temporizacion();
    _marcar(tamano - 8, 8, true);
    _reservarFormato();
    _colocarDatos();
    final forzada = mascaraPedida;
    if (forzada != null && forzada >= 0 && forzada <= 7) {
      return _aplicar(forzada);
    }
    var mejorPuntaje = 1 << 30;
    List<List<bool>>? mejor;
    for (var mascara = 0; mascara < 8; mascara++) {
      final candidata = _aplicar(mascara);
      final puntaje = _penalizacion(candidata);
      if (puntaje < mejorPuntaje) {
        mejorPuntaje = puntaje;
        mejor = candidata;
      }
    }
    return mejor!;
  }

  void _marcar(int fila, int columna, bool oscuro) {
    modulos[fila][columna] = oscuro;
    funcion[fila][columna] = true;
  }

  void _buscadores() {
    _buscador(0, 0);
    _buscador(0, tamano - 7);
    _buscador(tamano - 7, 0);
  }

  void _buscador(int fila, int columna) {
    for (var dy = -1; dy <= 7; dy++) {
      for (var dx = -1; dx <= 7; dx++) {
        final y = fila + dy;
        final x = columna + dx;
        if (y < 0 || x < 0 || y >= tamano || x >= tamano) continue;
        final separador = dy == -1 || dy == 7 || dx == -1 || dx == 7;
        final borde = dy == 0 || dy == 6 || dx == 0 || dx == 6;
        final centro = dy >= 2 && dy <= 4 && dx >= 2 && dx <= 4;
        _marcar(y, x, !separador && (borde || centro));
      }
    }
  }

  void _alineaciones() {
    final centros = _centrosAlineacion[nivel.version];
    for (final cy in centros) {
      for (final cx in centros) {
        if (_pisaFuncion(cy, cx)) continue;
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final borde = dy.abs() == 2 || dx.abs() == 2;
            final centro = dy == 0 && dx == 0;
            _marcar(cy + dy, cx + dx, borde || centro);
          }
        }
      }
    }
  }

  bool _pisaFuncion(int cy, int cx) {
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        if (funcion[cy + dy][cx + dx]) return true;
      }
    }
    return false;
  }

  void _temporizacion() {
    for (var i = 0; i < tamano; i++) {
      if (!funcion[6][i]) _marcar(6, i, i.isEven);
      if (!funcion[i][6]) _marcar(i, 6, i.isEven);
    }
  }

  void _reservar(int fila, int columna) {
    if (funcion[fila][columna]) {
      throw StateError('El formato del QR pisa otro módulo.');
    }
    funcion[fila][columna] = true;
  }

  void _reservarFormato() {
    for (var i = 0; i <= 5; i++) {
      _reservar(i, 8);
    }
    _reservar(7, 8);
    _reservar(8, 8);
    _reservar(8, 7);
    for (var i = 9; i < 15; i++) {
      _reservar(8, 14 - i);
    }
    for (var i = 0; i < 8; i++) {
      _reservar(8, tamano - 1 - i);
    }
    for (var i = 8; i < 15; i++) {
      _reservar(tamano - 15 + i, 8);
    }
  }

  void _colocarDatos() {
    var indice = 0;
    bool leer() {
      if (indice >= flujo.length * 8) return false;
      final byte = flujo[indice >> 3];
      final bit = (byte >> (7 - (indice & 7))) & 1;
      indice++;
      return bit == 1;
    }

    var derecha = tamano - 1;
    while (derecha >= 1) {
      if (derecha == 6) derecha = 5;
      final haciaArriba = ((derecha + 1) & 2) == 0;
      for (var paso = 0; paso < tamano; paso++) {
        final fila = haciaArriba ? tamano - 1 - paso : paso;
        for (var j = 0; j < 2; j++) {
          final columna = derecha - j;
          if (funcion[fila][columna]) continue;
          modulos[fila][columna] = leer();
        }
      }
      derecha -= 2;
    }
    if (indice < flujo.length * 8) {
      throw StateError('Quedaron datos del QR sin colocar.');
    }
  }

  List<List<bool>> _aplicar(int mascara) {
    final copia = [
      for (final fila in modulos) List<bool>.from(fila),
    ];
    for (var fila = 0; fila < tamano; fila++) {
      for (var columna = 0; columna < tamano; columna++) {
        if (funcion[fila][columna]) continue;
        if (_patron(mascara, fila, columna)) {
          copia[fila][columna] = !copia[fila][columna];
        }
      }
    }
    _escribirFormato(copia, mascara);
    return copia;
  }

  void _escribirFormato(List<List<bool>> destino, int mascara) {
    final bits = _bitsFormato(nivel.ecc, mascara);
    bool bit(int i) => ((bits >> i) & 1) == 1;
    for (var i = 0; i <= 5; i++) {
      destino[i][8] = bit(i);
    }
    destino[7][8] = bit(6);
    destino[8][8] = bit(7);
    destino[8][7] = bit(8);
    for (var i = 9; i < 15; i++) {
      destino[8][14 - i] = bit(i);
    }
    for (var i = 0; i < 8; i++) {
      destino[8][tamano - 1 - i] = bit(i);
    }
    for (var i = 8; i < 15; i++) {
      destino[tamano - 15 + i][8] = bit(i);
    }
  }
}

int _bitsFormato(int ecc, int mascara) {
  final datos = (ecc << 3) | mascara;
  var resto = datos << 10;
  for (var i = 14; i >= 10; i--) {
    if (((resto >> i) & 1) != 0) {
      resto ^= 0x537 << (i - 10);
    }
  }
  return ((datos << 10) | (resto & 0x3FF)) ^ 0x5412;
}

bool _patron(int mascara, int fila, int columna) {
  switch (mascara) {
    case 0:
      return (fila + columna).isEven;
    case 1:
      return fila.isEven;
    case 2:
      return columna % 3 == 0;
    case 3:
      return (fila + columna) % 3 == 0;
    case 4:
      return (fila ~/ 2 + columna ~/ 3).isEven;
    case 5:
      return (fila * columna) % 2 + (fila * columna) % 3 == 0;
    case 6:
      return ((fila * columna) % 2 + (fila * columna) % 3).isEven;
    default:
      return ((fila + columna) % 2 + (fila * columna) % 3).isEven;
  }
}

int _penalizacion(List<List<bool>> m) {
  final n = m.length;
  var puntaje = 0;
  for (final fila in m) {
    puntaje += _corrida(fila);
  }
  for (var columna = 0; columna < n; columna++) {
    puntaje += _corrida([for (var fila = 0; fila < n; fila++) m[fila][columna]]);
  }
  for (var fila = 0; fila < n - 1; fila++) {
    for (var columna = 0; columna < n - 1; columna++) {
      final valor = m[fila][columna];
      if (m[fila][columna + 1] == valor &&
          m[fila + 1][columna] == valor &&
          m[fila + 1][columna + 1] == valor) {
        puntaje += 3;
      }
    }
  }
  puntaje += _patrones(m);
  var oscuros = 0;
  for (final fila in m) {
    for (final celda in fila) {
      if (celda) oscuros++;
    }
  }
  final total = n * n;
  final porcentaje = (oscuros * 100) ~/ total;
  puntaje += ((porcentaje - 50).abs() ~/ 5) * 10;
  return puntaje;
}

int _corrida(List<bool> linea) {
  var puntaje = 0;
  var cuenta = 1;
  for (var i = 1; i < linea.length; i++) {
    if (linea[i] == linea[i - 1]) {
      cuenta++;
      if (cuenta == 5) {
        puntaje += 3;
      } else if (cuenta > 5) {
        puntaje += 1;
      }
    } else {
      cuenta = 1;
    }
  }
  return puntaje;
}

const List<bool> _patronBuscadorA = [
  true,
  false,
  true,
  true,
  true,
  false,
  true,
  false,
  false,
  false,
  false,
];

const List<bool> _patronBuscadorB = [
  false,
  false,
  false,
  false,
  true,
  false,
  true,
  true,
  true,
  false,
  true,
];

int _patrones(List<List<bool>> m) {
  final n = m.length;
  var puntaje = 0;

  void revisar(List<bool> linea) {
    for (var i = 0; i + 11 <= linea.length; i++) {
      if (_coincide(linea, i, _patronBuscadorA) || _coincide(linea, i, _patronBuscadorB)) {
        puntaje += 40;
      }
    }
  }

  for (final fila in m) {
    revisar(fila);
  }
  for (var columna = 0; columna < n; columna++) {
    revisar([for (var fila = 0; fila < n; fila++) m[fila][columna]]);
  }
  return puntaje;
}

bool _coincide(List<bool> linea, int inicio, List<bool> patron) {
  for (var i = 0; i < patron.length; i++) {
    if (linea[inicio + i] != patron[i]) return false;
  }
  return true;
}
