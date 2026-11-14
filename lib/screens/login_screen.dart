import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/sesion_remota.dart';
import '../services/sesion_google.dart';
import '../widgets/google_logo.dart';
import '../widgets/logo_gexi.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.alEntrar,
    required this.alContinuar,
  });

  final ValueChanged<SesionGoogle> alEntrar;
  final Future<void> Function(String correo) alContinuar;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _entrando = false;
  bool _porCorreo = false;
  bool _verClave = false;
  bool _creando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _conGoogle() async {
    setState(() {
      _entrando = true;
      _porCorreo = false;
      _error = null;
    });
    try {
      final sesion = await AuthGoogle.instancia.entrar();
      if (!mounted) return;
      if (sesion != null) widget.alEntrar(sesion);
    } on SesionRemotaException catch (error) {
      _avisar(error.mensaje);
    } catch (error) {
      final texto = error.toString();
      if (texto.contains('ClientID') || texto.contains('client_id')) {
        _avisar(
          'Falta el Client ID de Google. Por ahora entrá con correo y contraseña.',
        );
      } else {
        _avisar('No se pudo iniciar sesión con Google.');
      }
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  Future<void> _continuar() async {
    final correo = _correo.text.trim();
    final clave = _clave.text;
    final error = _validar(correo, clave);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _entrando = true;
      _porCorreo = true;
      _error = null;
    });
    try {
      await const SesionRemota().entrarOCrear(correo: correo, clave: clave);
      await widget.alContinuar(correo);
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  String? _validar(String correo, String clave) {
    final partes = correo.split('@');
    if (partes.length != 2 || partes[0].isEmpty || !partes[1].contains('.')) {
      return 'Ingresá un correo válido.';
    }
    if (clave.trim().length < 4) {
      return 'La contraseña necesita al menos 4 caracteres.';
    }
    return null;
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _ManchasFondo(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, limites) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: limites.maxHeight - 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _contenido(tema),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contenido(ThemeData tema) {
    return [
                  const Center(child: LogoGexi(ancho: 140)),
                  const SizedBox(height: 2),
                  if (_creando) ...[
                    Text(
                      'Creá tu cuenta',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF0E3154),
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Con Google o con tu correo. Si la cuenta ya existe, entrás directo.',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                  ] else
                    Text.rich(
                      TextSpan(
                        style: tema.textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0E3154),
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.4,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Impulsa tu negocio\ncon gestión inteligente.\nCrea, vende, ',
                          ),
                          TextSpan(
                            text: 'crece.',
                            style: TextStyle(color: Color(0xFF16C96A)),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (!_creando) ...[
                    const SizedBox(height: 10),
                    const _Modulos(),
                  ],
                  const SizedBox(height: 12),
                  _Campo(
                    controller: _correo,
                    hint: 'Correo electrónico',
                    icono: Icons.mail_outline_rounded,
                    teclado: TextInputType.emailAddress,
                    accion: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),
                  _Campo(
                    controller: _clave,
                    hint: 'Contraseña',
                    icono: Icons.lock_outline_rounded,
                    oculta: !_verClave,
                    accion: TextInputAction.done,
                    alEnviar: _entrando ? null : _continuar,
                    sufijo: IconButton(
                      onPressed: () => setState(() => _verClave = !_verClave),
                      icon: Icon(
                        _verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF98A2B3),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _BotonContinuar(
                    texto: _creando ? 'Crear cuenta  →' : 'Continuar  →',
                    cargando: _porCorreo,
                    alPulsar: _entrando ? null : _continuar,
                  ),
                  const SizedBox(height: 8),
                  _BotonGoogle(
                    texto: _creando ? 'Crear cuenta con Google' : 'Ingresar con Google',
                    cargando: _entrando && !_porCorreo,
                    alPulsar: _entrando ? null : _conGoogle,
                  ),
                  const SizedBox(height: 4),
                  if (!_creando)
                    TextButton(
                      onPressed: _entrando
                          ? null
                          : () => _avisar(
                                'En este prototipo no enviamos correos. Entrá con Continuar usando el correo que quieras.',
                              ),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          color: Color(0xFF2F6BFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _creando ? '¿Ya tienes una cuenta? ' : '¿No tienes una cuenta? ',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      GestureDetector(
                        onTap: _entrando
                            ? null
                            : () => setState(() {
                                  _creando = !_creando;
                                  _error = null;
                                }),
                        child: Text(
                          _creando ? 'Ingresar' : 'Crear cuenta',
                          style: const TextStyle(
                            color: Color(0xFF16C96A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
    ];
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.controller,
    required this.hint,
    required this.icono,
    this.oculta = false,
    this.teclado,
    this.accion,
    this.sufijo,
    this.alEnviar,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icono;
  final bool oculta;
  final TextInputType? teclado;
  final TextInputAction? accion;
  final Widget? sufijo;
  final VoidCallback? alEnviar;

  @override
  Widget build(BuildContext context) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE4E8EE)),
    );
    return TextField(
      controller: controller,
      obscureText: oculta,
      keyboardType: teclado,
      textInputAction: accion,
      onSubmitted: alEnviar == null ? null : (_) => alEnviar!(),
      style: const TextStyle(color: Color(0xFF0E3154), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA3B3), fontWeight: FontWeight.w500),
        prefixIcon: Icon(icono, color: const Color(0xFF98A2B3)),
        suffixIcon: sufijo,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: borde,
        border: borde,
        focusedBorder: borde.copyWith(
          borderSide: const BorderSide(color: Color(0xFF1B6BFF), width: 1.4),
        ),
      ),
    );
  }
}

class _BotonContinuar extends StatelessWidget {
  const _BotonContinuar({
    required this.texto,
    required this.cargando,
    required this.alPulsar,
  });

  final String texto;
  final bool cargando;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3DDE6E), Color(0xFF1A56F0)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331A56F0),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: cargando ? null : alPulsar,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 52,
            child: Center(
              child: cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(
                      texto,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonGoogle extends StatelessWidget {
  const _BotonGoogle({
    required this.texto,
    required this.cargando,
    required this.alPulsar,
  });

  final String texto;
  final bool cargando;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDADCE0), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F3A5A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: cargando ? null : alPulsar,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 52,
            child: Center(
              child: cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFF4285F4),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GoogleLogo(size: 22),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            texto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Modulos extends StatelessWidget {
  const _Modulos();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 86,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(child: CustomPaint(painter: _FlechaCrecimiento())),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _TarjetaModulo(icono: Icons.storefront_rounded, color: Color(0xFF14B8A6), fondo: Color(0xFFE7FBF6), titulo: 'Ventas')),
              SizedBox(width: 8),
              Expanded(child: _TarjetaModulo(icono: Icons.inventory_2_rounded, color: Color(0xFFD97706), fondo: Color(0xFFFFF4E5), titulo: 'Stock')),
              SizedBox(width: 8),
              Expanded(child: _TarjetaModulo(icono: Icons.assignment_rounded, color: Color(0xFF2563EB), fondo: Color(0xFFE8F0FF), titulo: 'Pedidos')),
              SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _TarjetaModulo(
                    icono: Icons.trending_up_rounded,
                    color: Color(0xFF16A34A),
                    fondo: Color(0xFFE8F9EE),
                    titulo: 'Crecimiento',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaModulo extends StatelessWidget {
  const _TarjetaModulo({
    required this.icono,
    required this.color,
    required this.fondo,
    required this.titulo,
  });

  final IconData icono;
  final Color color;
  final Color fondo;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F3A5A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF12324F),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlechaCrecimiento extends CustomPainter {
  const _FlechaCrecimiento();

  @override
  void paint(Canvas canvas, Size size) {
    final shader = const LinearGradient(
      colors: [Color(0xFF5EEAD4), Color(0xFF22C55E)],
    ).createShader(Offset.zero & size);
    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.98,
        size.width * 0.72,
        size.height * 0.38,
      );
    canvas.drawPath(path, paint);
    final punta = Offset(size.width * 0.78, size.height * 0.22);
    final cabeza = Path()
      ..moveTo(punta.dx - 12, punta.dy + 4)
      ..lineTo(punta.dx + 2, punta.dy - 8)
      ..lineTo(punta.dx - 4, punta.dy + 12);
    canvas.drawPath(
      cabeza,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ManchasFondo extends StatelessWidget {
  const _ManchasFondo();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _Mancha(color: Color(0xFFB7F6E4), tamano: 280),
          ),
          Positioned(
            top: -40,
            right: -90,
            child: _Mancha(color: Color(0xFFD7F7C8), tamano: 220),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: _Mancha(color: Color(0xFFC7E7FF), tamano: 300),
          ),
          Positioned(
            bottom: -40,
            left: -100,
            child: _Mancha(color: Color(0xFFD9FBE8), tamano: 240),
          ),
        ],
      ),
    );
  }
}

class _Mancha extends StatelessWidget {
  const _Mancha({required this.color, required this.tamano});

  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 8,
      child: Container(
        width: tamano,
        height: tamano * 0.72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tamano),
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
