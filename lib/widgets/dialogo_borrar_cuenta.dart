import 'package:flutter/material.dart';

import '../backend/borrar_cuenta.dart';
import '../theme/app_theme.dart';

/// Pide escribir BORRAR y recién ahí llama a borrar la cuenta.
class DialogoBorrarCuenta extends StatefulWidget {
  const DialogoBorrarCuenta({super.key});

  @override
  State<DialogoBorrarCuenta> createState() => _DialogoBorrarCuentaState();
}

class _DialogoBorrarCuentaState extends State<DialogoBorrarCuenta> {
  final _controlador = TextEditingController();
  bool _borrando = false;
  String? _error;

  bool get _confirmado => _controlador.text.trim() == 'BORRAR';

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _borrar() async {
    if (!_confirmado || _borrando) return;
    setState(() {
      _borrando = true;
      _error = null;
    });
    try {
      await const BorrarCuenta().ejecutar();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on BorrarCuentaException catch (error) {
      if (!mounted) return;
      setState(() {
        _borrando = false;
        _error = error.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _borrando = false;
        _error = 'No se pudo borrar la cuenta. Probá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_borrando,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Borrar cuenta',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se borran las imágenes, el negocio si sos el dueño, los pedidos y la cuenta con la que entraste. No se puede deshacer.',
              style: TextStyle(color: AppColors.textoSuave, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controlador,
              enabled: !_borrando,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'BORRAR',
                labelText: 'Escribí BORRAR',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.alerta, height: 1.3),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _borrando ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _confirmado && !_borrando ? _borrar : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.alerta,
              disabledBackgroundColor: AppColors.alerta.withValues(alpha: 0.35),
            ),
            child: _borrando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Borrar cuenta'),
          ),
        ],
      ),
    );
  }
}
