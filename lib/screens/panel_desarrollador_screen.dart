import 'package:flutter/material.dart';

import '../services/desarrollador.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

/// Conteos globales. Solo se abre desde Más si el email de Supabase está habilitado.
class PanelDesarrolladorScreen extends StatefulWidget {
  const PanelDesarrolladorScreen({super.key});

  @override
  State<PanelDesarrolladorScreen> createState() => _PanelDesarrolladorScreenState();
}

class _PanelDesarrolladorScreenState extends State<PanelDesarrolladorScreen> {
  ResumenDesarrollador? _resumen;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!esDesarrollador(emailSesionDesarrollador())) {
      _cargando = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }
    _cargar();
  }

  Future<void> _cargar() async {
    if (!esDesarrollador(emailSesionDesarrollador())) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _error = null;
      if (_resumen == null) _cargando = true;
    });
    try {
      final resumen = await cargarResumenDesarrollador();
      if (!mounted) return;
      if (resumen == null) {
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo leer el resumen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text('Panel del desarrollador')),
      body: FondoGexi(
        child: _cargando && resumen == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.alerta,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _Tarjeta(
                      icono: Icons.storefront_rounded,
                      titulo: 'Tiendas activas',
                      valor: _miles(resumen?.tiendasActivas ?? 0),
                    ),
                    const SizedBox(height: 12),
                    _Tarjeta(
                      icono: Icons.people_alt_rounded,
                      titulo: 'Usuarios',
                      valor: _miles(resumen?.usuarios ?? 0),
                    ),
                    const SizedBox(height: 12),
                    _Tarjeta(
                      icono: Icons.token_rounded,
                      titulo: 'Tokens del asistente',
                      valor: _miles(resumen?.tokens ?? 0),
                    ),
                    const SizedBox(height: 12),
                    _Tarjeta(
                      icono: Icons.forum_rounded,
                      titulo: 'Chats disponibles',
                      valor: _miles(resumen?.chatsDisponibles ?? 0),
                    ),
                    if (resumen?.asistenteSinDatos == true) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Todavía no hay datos del asistente',
                        style: TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.tarjeta,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: AppColors.primario, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _miles(int valor) {
  final negativo = valor < 0;
  final texto = valor.abs().toString();
  final miles = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) miles.write('.');
    miles.write(texto[i]);
  }
  return negativo ? '-${miles.toString()}' : miles.toString();
}
