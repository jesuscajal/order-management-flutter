import 'package:web/web.dart';

bool hayClientIdDeGoogle() {
  final nodo = document.querySelector(
    'meta[name="google-signin-client_id"]',
  );
  if (nodo == null) return false;
  final contenido = nodo.getAttribute('content')?.trim() ?? '';
  if (contenido.isEmpty || contenido.contains('TU_ID')) return false;
  return true;
}
