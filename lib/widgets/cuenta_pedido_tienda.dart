import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/supabase_cliente.dart';
import '../theme/app_theme.dart';

/// Camino elegido antes de pedir el nombre y el WhatsApp.
enum CaminoCuentaPedido { crear, ingresar, manual }

/// Resultado del diálogo de cuenta. [aviso] se muestra en el paso siguiente.
class SesionCuentaPedido {
  const SesionCuentaPedido({
    required this.camino,
    this.correo = '',
    this.nombre = '',
    this.aviso = '',
  });

  final CaminoCuentaPedido camino;
  final String correo;
  final String nombre;
  final String aviso;

  bool get conCuenta => camino != CaminoCuentaPedido.manual;
}

/// Guarda el nombre confirmado para la próxima vez.
///
/// En la nube solo actualiza la sesión si el correo coincide con el usuario
/// que acaba de entrar. Así no se pisa otra sesión abierta en el dispositivo.
Future<void> recordarNombreDePedido({
  required String correo,
  required String nombre,
}) async {
  final email = correo.trim().toLowerCase();
  final limpio = nombre.trim();
  if (email.isEmpty || limpio.isEmpty) return;
  try {
    await const _CuentasPedidoLocal().guardarNombre(email, limpio);
  } catch (_) {}

  final cliente = SupabaseListo.cliente;
  final actual = cliente?.auth.currentUser?.email?.trim().toLowerCase() ?? '';
  if (cliente == null || actual.isEmpty || actual != email) return;
  unawaited(_guardarNombreEnNube(cliente, limpio));
}

Future<void> _guardarNombreEnNube(SupabaseClient cliente, String nombre) async {
  try {
    await cliente.auth
        .updateUser(UserAttributes(data: {'nombre': nombre}))
        .timeout(const Duration(seconds: 8));
  } catch (_) {}
}

/// Tres caminos: crear cuenta, ingresar o pedir sin cuenta.
class DialogoCuentaPedido extends StatefulWidget {
  const DialogoCuentaPedido({super.key});

  @override
  State<DialogoCuentaPedido> createState() => _DialogoCuentaPedidoState();
}

class _DialogoCuentaPedidoState extends State<DialogoCuentaPedido> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _repite = TextEditingController();
  _PasoCuenta _paso = _PasoCuenta.elegir;
  String? _error;
  bool _ocupado = false;
  bool _ocultarClave = true;
  bool _ocultarRepite = true;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _repite.dispose();
    super.dispose();
  }

  void _volver() {
    if (_ocupado) return;
    setState(() {
      _paso = _PasoCuenta.elegir;
      _error = null;
    });
  }

  void _irA(_PasoCuenta paso) {
    setState(() {
      _paso = paso;
      _error = null;
    });
  }

  Future<void> _crear() async {
    await _enviar(alta: true);
  }

  Future<void> _ingresar() async {
    await _enviar(alta: false);
  }

  Future<void> _enviar({required bool alta}) async {
    if (_ocupado) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final resultado = alta
          ? await _crearCuenta(_correo.text, _clave.text)
          : await _ingresarCuenta(_correo.text, _clave.text);
      if (!mounted) return;
      Navigator.pop(context, resultado);
    } on _CuentaPedidoException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.mensaje);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _traducirAuth(error, alta: alta));
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _error = 'La cuenta tardó demasiado. Probá de nuevo.');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = alta
            ? 'No se pudo crear la cuenta. Probá de nuevo.'
            : 'No se pudo ingresar. Probá de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creando = _paso == _PasoCuenta.crear;
    return PopScope(
      canPop: !_ocupado,
      child: AlertDialog(
        backgroundColor: AppColors.fondoClaro,
        title: Text(
          _titulo,
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SingleChildScrollView(
          child: _paso == _PasoCuenta.elegir ? _elegir() : _formulario(creando),
        ),
        actions: [
          if (_paso != _PasoCuenta.elegir)
            TextButton(
              onPressed: _ocupado ? null : _volver,
              child: const Text('Volver'),
            ),
          TextButton(
            onPressed: _ocupado ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  String get _titulo {
    switch (_paso) {
      case _PasoCuenta.elegir:
        return 'Cómo seguís con el pedido';
      case _PasoCuenta.crear:
        return 'Crear cuenta';
      case _PasoCuenta.ingresar:
        return 'Ingresar';
    }
  }

  Widget _elegir() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Elegí una opción. El nombre y el WhatsApp los pedimos después.',
          style: TextStyle(color: AppColors.textoSuave, height: 1.35),
        ),
        const SizedBox(height: 16),
        _camino(
          icono: Icons.person_add_alt_1_rounded,
          titulo: 'Crear cuenta',
          detalle: 'Con correo y contraseña',
          onTap: () => _irA(_PasoCuenta.crear),
        ),
        _camino(
          icono: Icons.login_rounded,
          titulo: 'Ingresar',
          detalle: 'Si ya tenés cuenta',
          onTap: () => _irA(_PasoCuenta.ingresar),
        ),
        _camino(
          icono: Icons.shopping_bag_outlined,
          titulo: 'Pedir sin cuenta',
          detalle: 'El pedido no exige una cuenta',
          onTap: () => Navigator.pop(
            context,
            const SesionCuentaPedido(camino: CaminoCuentaPedido.manual),
          ),
        ),
      ],
    );
  }

  Widget _camino({
    required IconData icono,
    required String titulo,
    required String detalle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.linea),
            ),
            child: Row(
              children: [
                Icon(icono, color: AppColors.primario),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textoSuave),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario(bool alta) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alta
                ? 'Creá la cuenta con tu correo. Después confirmás el nombre y el WhatsApp.'
                : 'Ingresá con tu correo y contraseña. Después confirmás el nombre y el WhatsApp.',
            style: const TextStyle(color: AppColors.textoSuave, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _correo,
            enabled: !_ocupado,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo',
              hintText: 'tu@correo.com',
            ),
            validator: _validarCorreo,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _clave,
            enabled: !_ocupado,
            obscureText: _ocultarClave,
            textInputAction:
                alta ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: alta ? null : (_) => _ingresar(),
            autofillHints: [
              alta ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                icon: Icon(
                  _ocultarClave
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: _validarClave,
          ),
          if (alta) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _repite,
              enabled: !_ocupado,
              obscureText: _ocultarRepite,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _crear(),
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Repetir contraseña',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _ocultarRepite = !_ocultarRepite),
                  icon: Icon(
                    _ocultarRepite
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (valor) {
                if (valor != _clave.text) {
                  return 'Las contraseñas no coinciden.';
                }
                return null;
              },
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.alerta, height: 1.35),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _ocupado ? null : (alta ? _crear : _ingresar),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primario,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: _ocupado
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(alta ? 'Crear cuenta' : 'Ingresar'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _ocupado
                  ? null
                  : () => _irA(alta ? _PasoCuenta.ingresar : _PasoCuenta.crear),
              child: Text(alta ? 'Ya tengo cuenta' : 'Crear cuenta'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PasoCuenta { elegir, crear, ingresar }

class _CuentaPedidoException implements Exception {
  const _CuentaPedidoException(this.mensaje);

  final String mensaje;
}

String? _validarCorreo(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Ingresá tu correo.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
    return 'Ese correo no es válido.';
  }
  return null;
}

String? _validarClave(String? valor) {
  if (valor == null || valor.length < 6) {
    return 'Usá al menos 6 caracteres.';
  }
  return null;
}

Future<SesionCuentaPedido> _crearCuenta(String correo, String clave) async {
  final email = correo.trim().toLowerCase();
  final cliente = SupabaseListo.cliente;
  if (cliente == null) {
    await const _CuentasPedidoLocal().crear(correo: email, clave: clave);
    return SesionCuentaPedido(
      camino: CaminoCuentaPedido.crear,
      correo: email,
      aviso:
          'Guardamos tu cuenta en este dispositivo. El correo de bienvenida sale cuando hay sesión.',
    );
  }

  final alta = await cliente.auth
      .signUp(email: email, password: clave)
      .timeout(const Duration(seconds: 20));
  if (_yaHabiaCuenta(alta.user)) {
    throw const _CuentaPedidoException(
      'Ese correo ya tiene cuenta. Ingresá con tu contraseña.',
    );
  }
  if (alta.user == null) {
    throw const _CuentaPedidoException(
      'No se pudo crear la cuenta. Probá de nuevo.',
    );
  }
  final sesion = alta.session ?? cliente.auth.currentSession;
  final mismaSesion =
      cliente.auth.currentUser?.email?.trim().toLowerCase() == email;
  final conSesion = sesion != null && mismaSesion;
  final nombre = await _nombrePara(email, alta.user);
  return SesionCuentaPedido(
    camino: CaminoCuentaPedido.crear,
    correo: email,
    nombre: nombre,
    aviso: conSesion
        ? ''
        : 'Te enviamos un correo para confirmar la cuenta. Podés seguir y confirmar tu nombre y tu WhatsApp.',
  );
}

Future<SesionCuentaPedido> _ingresarCuenta(String correo, String clave) async {
  final email = correo.trim().toLowerCase();
  final cliente = SupabaseListo.cliente;
  if (cliente == null) {
    final local = await const _CuentasPedidoLocal().ingresar(
      correo: email,
      clave: clave,
    );
    return SesionCuentaPedido(
      camino: CaminoCuentaPedido.ingresar,
      correo: local.correo,
      nombre: local.nombre,
    );
  }

  final respuesta = await cliente.auth
      .signInWithPassword(email: email, password: clave)
      .timeout(const Duration(seconds: 20));
  final nombre = await _nombrePara(email, respuesta.user);
  return SesionCuentaPedido(
    camino: CaminoCuentaPedido.ingresar,
    correo: (respuesta.user?.email ?? email).trim().toLowerCase(),
    nombre: nombre,
  );
}

Future<String> _nombrePara(String correo, User? usuario) async {
  final remoto = _nombreDeUsuario(usuario);
  if (remoto.isNotEmpty) return remoto;
  try {
    return await const _CuentasPedidoLocal().nombreDe(correo);
  } catch (_) {
    return '';
  }
}

String _nombreDeUsuario(User? usuario) {
  final datos = usuario?.userMetadata;
  if (datos == null) return '';
  for (final clave in const ['nombre', 'full_name', 'name', 'display_name']) {
    final valor = datos[clave]?.toString().trim() ?? '';
    if (valor.isNotEmpty) return valor;
  }
  return '';
}

bool _yaHabiaCuenta(User? usuario) {
  final identidades = usuario?.identities;
  return usuario != null && identidades != null && identidades.isEmpty;
}

String _traducirAuth(AuthException error, {required bool alta}) {
  final codigo = (error.code ?? '').toLowerCase();
  final mensaje = error.message.toLowerCase();
  if (codigo == 'user_already_exists' ||
      codigo == 'email_exists' ||
      mensaje.contains('already registered') ||
      mensaje.contains('already been registered') ||
      mensaje.contains('user already exists')) {
    return 'Ese correo ya tiene cuenta. Ingresá con tu contraseña.';
  }
  if (codigo == 'invalid_credentials' ||
      mensaje.contains('invalid login') ||
      mensaje.contains('invalid credentials')) {
    return 'El correo o la contraseña no coinciden.';
  }
  if (codigo == 'email_not_confirmed' ||
      mensaje.contains('email not confirmed')) {
    return 'Confirmá el correo antes de ingresar. Revisá tu bandeja.';
  }
  if (codigo == 'weak_password' ||
      mensaje.contains('password should be') ||
      mensaje.contains('at least')) {
    return 'La contraseña es muy corta. Usá al menos 6 caracteres.';
  }
  if (codigo == 'over_request_rate_limit' ||
      codigo == 'over_email_send_rate_limit' ||
      mensaje.contains('rate limit')) {
    return 'Esperá un momento y volvé a intentar.';
  }
  if (mensaje.contains('invalid') && mensaje.contains('email')) {
    return 'Ese correo no es válido.';
  }
  if (alta) return 'No se pudo crear la cuenta. Probá de nuevo.';
  return 'No se pudo ingresar. Probá de nuevo.';
}

/// Huella estable en web y móvil, sin guardar la contraseña.
String _huellaLocal(String correo, String clave) {
  final bytes = utf8.encode('gexi-pedido-local|$correo|$clave');
  const semillas = [5381, 7919, 104729, 224737];
  final partes = <String>[];
  for (final semilla in semillas) {
    var hash = semilla;
    for (final byte in bytes) {
      hash = ((hash * 33) ^ byte) & 0x7fffffff;
    }
    partes.add(hash.toRadixString(16).padLeft(8, '0'));
  }
  return partes.join();
}

class _CuentaLocal {
  const _CuentaLocal({
    required this.correo,
    required this.nombre,
    required this.huella,
  });

  final String correo;
  final String nombre;
  final String huella;

  _CuentaLocal copiar({String? nombre, String? huella}) {
    return _CuentaLocal(
      correo: correo,
      nombre: nombre ?? this.nombre,
      huella: huella ?? this.huella,
    );
  }

  Map<String, String> toJson() => {
        'correo': correo,
        'nombre': nombre,
        'huella': huella,
      };

  factory _CuentaLocal.fromJson(Map<dynamic, dynamic> json) {
    return _CuentaLocal(
      correo: json['correo']?.toString().trim().toLowerCase() ?? '',
      nombre: json['nombre']?.toString().trim() ?? '',
      huella: json['huella']?.toString() ?? '',
    );
  }
}

class _CuentasPedidoLocal {
  const _CuentasPedidoLocal();

  static const _clave = 'gexi_cuentas_pedido_tienda_v1';

  Future<List<_CuentaLocal>> _leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return [];
    try {
      final decoded = jsonDecode(crudo);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map) _CuentaLocal.fromJson(item),
      ].where((cuenta) => cuenta.correo.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _guardar(List<_CuentaLocal> cuentas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode([for (final cuenta in cuentas) cuenta.toJson()]),
    );
  }

  Future<void> crear({required String correo, required String clave}) async {
    final cuentas = await _leer();
    final indice = cuentas.indexWhere((cuenta) => cuenta.correo == correo);
    if (indice >= 0 && cuentas[indice].huella.isNotEmpty) {
      throw const _CuentaPedidoException(
        'Ese correo ya tiene cuenta en este dispositivo. Ingresá con tu contraseña.',
      );
    }
    final nueva = _CuentaLocal(
      correo: correo,
      nombre: indice >= 0 ? cuentas[indice].nombre : '',
      huella: _huellaLocal(correo, clave),
    );
    if (indice >= 0) {
      cuentas[indice] = nueva;
    } else {
      cuentas.add(nueva);
    }
    await _guardar(cuentas);
  }

  Future<_CuentaLocal> ingresar({
    required String correo,
    required String clave,
  }) async {
    final cuentas = await _leer();
    _CuentaLocal? hallada;
    for (final cuenta in cuentas) {
      if (cuenta.correo == correo) {
        hallada = cuenta;
        break;
      }
    }
    if (hallada == null || hallada.huella.isEmpty) {
      throw const _CuentaPedidoException(
        'No hay una cuenta con ese correo en este dispositivo. Creá una o pedí sin cuenta.',
      );
    }
    if (hallada.huella != _huellaLocal(correo, clave)) {
      throw const _CuentaPedidoException('La contraseña no coincide.');
    }
    return hallada;
  }

  Future<String> nombreDe(String correo) async {
    final email = correo.trim().toLowerCase();
    for (final cuenta in await _leer()) {
      if (cuenta.correo == email && cuenta.nombre.isNotEmpty) {
        return cuenta.nombre;
      }
    }
    return '';
  }

  Future<void> guardarNombre(String correo, String nombre) async {
    final email = correo.trim().toLowerCase();
    final limpio = nombre.trim();
    if (email.isEmpty || limpio.isEmpty) return;
    final cuentas = await _leer();
    final indice = cuentas.indexWhere((cuenta) => cuenta.correo == email);
    if (indice >= 0) {
      cuentas[indice] = cuentas[indice].copiar(nombre: limpio);
    } else {
      cuentas.add(_CuentaLocal(correo: email, nombre: limpio, huella: ''));
    }
    await _guardar(cuentas);
  }
}
