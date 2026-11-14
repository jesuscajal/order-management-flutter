// Sirve el panel local del desarrollador en http://localhost:3000.
// Ese origen es el que Google ya acepta para el ingreso de la app.
//
// Lee SUPABASE_URL y SUPABASE_ANON_KEY desde dart_defines.json (raíz del
// repo, gitignoreado) y las inyecta solo en la respuesta HTTP. No escribe
// la clave en disco.
//
// Si el correo del enlace mágico no vuelve a esta página, en Supabase:
// Authentication → URL Configuration → Redirect URLs, agregá
// http://localhost:3000
// La misma URL sirve para la vuelta de Google.

import 'dart:convert';
import 'dart:io';

const _host = 'localhost';
const _port = 3000;
const _marca = 'GEXI_PANEL_JSON';

Future<void> main() async {
  final claves = _leerClaves();
  final carpeta = _carpetaDelPanel();
  final server = await _abrir();
  stdout.writeln('Panel del desarrollador: http://$_host:$_port');
  await for (final request in server) {
    try {
      await _responder(request, carpeta, claves);
    } catch (_) {
      final response = request.response;
      response.statusCode = HttpStatus.internalServerError;
      await response.close();
    }
  }
}

({String url, String anonKey}) _leerClaves() {
  final archivo = _buscarDefines();
  var texto = archivo.readAsStringSync();
  if (texto.startsWith('\uFEFF')) texto = texto.substring(1);
  final Object? datos;
  try {
    datos = jsonDecode(texto);
  } on FormatException {
    stderr.writeln('dart_defines.json no es un JSON válido.');
    exit(1);
  }
  if (datos is! Map) {
    stderr.writeln('dart_defines.json no tiene el formato esperado.');
    exit(1);
  }
  final url = (datos['SUPABASE_URL'] ?? '').toString().trim();
  final anon = (datos['SUPABASE_ANON_KEY'] ?? '').toString().trim();
  if (url.isEmpty || anon.isEmpty) {
    stderr.writeln(
      'dart_defines.json tiene que traer SUPABASE_URL y SUPABASE_ANON_KEY.',
    );
    exit(1);
  }
  return (url: url, anonKey: anon);
}

File _buscarDefines() {
  for (final base in _bases()) {
    final archivo = File(_unir(base.path, 'dart_defines.json'));
    if (archivo.existsSync()) return archivo;
  }
  stderr.writeln('No encuentro dart_defines.json en la raíz del proyecto.');
  exit(1);
}

Directory _carpetaDelPanel() {
  for (final base in _bases()) {
    final carpeta = Directory(_unir(_unir(base.path, 'dev'), 'panel'));
    if (File(_unir(carpeta.path, 'index.html')).existsSync()) return carpeta;
  }
  if (Platform.script.scheme == 'file') {
    final junto = File(Platform.script.toFilePath()).parent;
    if (File(_unir(junto.path, 'index.html')).existsSync()) return junto;
  }
  stderr.writeln('No encuentro dev/panel/index.html.');
  exit(1);
}

List<Directory> _bases() {
  final bases = <Directory>[];
  if (Platform.script.scheme == 'file') {
    final script = File(Platform.script.toFilePath());
    bases.add(script.parent.parent.parent);
  }
  bases.add(Directory.current);
  return bases;
}

Future<HttpServer> _abrir() async {
  try {
    return await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  } on SocketException catch (error) {
    stderr.writeln('No pude abrir http://$_host:$_port ($error).');
    exit(1);
  }
}

Future<void> _responder(
  HttpRequest request,
  Directory carpeta,
  ({String url, String anonKey}) claves,
) async {
  final host = request.headers.value(HttpHeaders.hostHeader) ?? '';
  if (host.startsWith('127.0.0.1')) {
    final destino = 'http://$_host:$_port${request.uri}';
    request.response.statusCode = HttpStatus.movedPermanently;
    request.response.headers.set(HttpHeaders.locationHeader, destino);
    await request.response.close();
    return;
  }
  if (request.method != 'GET') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    await request.response.close();
    return;
  }
  final ruta = request.uri.path;
  if (ruta == '/' || ruta == '/index.html') {
    await _enviarHtml(request, carpeta, claves);
    return;
  }
  if (ruta == '/panel.js') {
    await _enviarArchivo(
      request,
      File(_unir(carpeta.path, 'panel.js')),
      'text/javascript; charset=utf-8',
    );
    return;
  }
  await _enviarTexto(request, HttpStatus.notFound, 'No encontrado');
}

Future<void> _enviarHtml(
  HttpRequest request,
  Directory carpeta,
  ({String url, String anonKey}) claves,
) async {
  final plantilla = File(_unir(carpeta.path, 'index.html')).readAsStringSync();
  if (!plantilla.contains(_marca)) {
    await _enviarTexto(
      request,
      HttpStatus.internalServerError,
      'La página no tiene el lugar de la configuración.',
    );
    return;
  }
  final config = jsonEncode({
    'url': claves.url,
    'anonKey': claves.anonKey,
  });
  if (config.contains(_marca)) {
    await _enviarTexto(
      request,
      HttpStatus.internalServerError,
      'No se pudo armar la página.',
    );
    return;
  }
  final html = plantilla.replaceFirst(_marca, config);
  await _enviarBytes(
    request,
    HttpStatus.ok,
    utf8.encode(html),
    'text/html; charset=utf-8',
  );
}

Future<void> _enviarArchivo(
  HttpRequest request,
  File archivo,
  String contentType,
) async {
  if (!archivo.existsSync()) {
    await _enviarTexto(request, HttpStatus.notFound, 'No encontrado');
    return;
  }
  await _enviarBytes(request, HttpStatus.ok, archivo.readAsBytesSync(), contentType);
}

Future<void> _enviarTexto(HttpRequest request, int status, String mensaje) {
  return _enviarBytes(
    request,
    status,
    utf8.encode(mensaje),
    'text/plain; charset=utf-8',
  );
}

Future<void> _enviarBytes(
  HttpRequest request,
  int status,
  List<int> cuerpo,
  String contentType,
) async {
  final response = request.response;
  response.statusCode = status;
  response.headers.set(HttpHeaders.contentTypeHeader, contentType);
  response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.contentLength = cuerpo.length;
  response.add(cuerpo);
  await response.close();
}

String _unir(String base, String nombre) {
  if (base.endsWith(Platform.pathSeparator)) return '$base$nombre';
  return '$base${Platform.pathSeparator}$nombre';
}
