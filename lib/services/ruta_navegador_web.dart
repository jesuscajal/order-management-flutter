import 'dart:js_interop';

@JS('window.location.pathname')
external JSString get _rutaDelNavegador;

/// La ruta real de la barra, aunque la etiqueta base de Flutter sea `/`.
String rutaDelNavegador() => _rutaDelNavegador.toDart;
