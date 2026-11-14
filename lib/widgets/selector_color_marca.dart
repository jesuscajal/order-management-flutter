import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../data/apariencia_tienda.dart';
import '../theme/app_theme.dart';

/// Paleta corta y color propio de la marca. El propio se guarda como `#RRGGBB`.
class SelectorColorMarca extends StatefulWidget {
  const SelectorColorMarca({
    super.key,
    required this.apariencia,
    required this.onPaleta,
    required this.onAcentoHex,
    this.habilitado = true,
    this.permitirHex = false,
  });

  final AparienciaTienda apariencia;
  final ValueChanged<String> onPaleta;
  final ValueChanged<String> onAcentoHex;
  final bool habilitado;

  /// Muestra el código `#RRGGBB` para escribirlo a mano.
  final bool permitirHex;

  @override
  State<SelectorColorMarca> createState() => _SelectorColorMarcaState();
}

class _SelectorColorMarcaState extends State<SelectorColorMarca> {
  final _hex = TextEditingController();
  final _foco = FocusNode();
  String? _errorHex;

  @override
  void initState() {
    super.initState();
    _hex.text = widget.apariencia.acentoHex;
  }

  @override
  void didUpdateWidget(SelectorColorMarca oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apariencia.acentoHex == widget.apariencia.acentoHex) return;
    final actual = widget.apariencia.acentoHex;
    if (_hex.text != actual) _hex.text = actual;
    _errorHex = null;
  }

  @override
  void dispose() {
    _hex.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _elegirPropio() async {
    if (!widget.habilitado) return;
    final elegido = await showDialog<Color>(
      context: context,
      builder: (dialogContext) =>
          _DialogoColorMarca(inicial: widget.apariencia.acento),
    );
    if (elegido == null || !mounted) return;
    widget.onAcentoHex(AparienciaTienda.hexDeColor(elegido));
  }

  void _usarHexEscrito() {
    if (!widget.habilitado) return;
    final texto = _hex.text.trim();
    if (texto.isEmpty) {
      setState(() => _errorHex = null);
      if (widget.apariencia.acentoHex.isNotEmpty) widget.onAcentoHex('');
      return;
    }
    final hex = AparienciaTienda.normalizarHex(texto);
    if (hex.isEmpty) {
      setState(() => _errorHex = 'Escribí el color como #1E293B.');
      return;
    }
    setState(() => _errorHex = null);
    if (hex == widget.apariencia.acentoHex) {
      _hex.text = hex;
      return;
    }
    widget.onAcentoHex(hex);
  }

  @override
  Widget build(BuildContext context) {
    final apariencia = widget.apariencia;
    final paleta = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final id in AparienciaTienda.paletas)
          _CirculoColorMarca(
            color: AparienciaTienda.colorDePaleta(id),
            nombre: AparienciaTienda.nombrePaleta(id),
            elegido: apariencia.acentoHex.isEmpty && apariencia.paleta == id,
            onTap: widget.habilitado ? () => widget.onPaleta(id) : null,
          ),
        _CirculoColorMarca(
          color: apariencia.acentoHex.isEmpty
              ? AppColors.azulClaro
              : apariencia.acento,
          nombre: 'Personalizado',
          elegido: apariencia.acentoHex.isNotEmpty,
          personalizado: apariencia.acentoHex.isEmpty,
          onTap: widget.habilitado ? _elegirPropio : null,
        ),
      ],
    );
    if (!widget.permitirHex) return paleta;
    final preview = AparienciaTienda.colorDeHex(_hex.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        paleta,
        const SizedBox(height: 14),
        TextField(
          controller: _hex,
          focusNode: _foco,
          enabled: widget.habilitado,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          maxLength: 7,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
          ],
          onChanged: (_) => setState(() => _errorHex = null),
          onSubmitted: (_) => _usarHexEscrito(),
          decoration: InputDecoration(
            labelText: 'Color propio',
            hintText: '#1E293B',
            counterText: '',
            errorText: _errorHex,
            helperText:
                'Como #1E293B. Se guarda al aplicar. Vacío vuelve a la paleta.',
            prefixIcon:
                Icon(Icons.circle, color: preview ?? AppColors.textoSuave),
            suffixIcon: IconButton(
              tooltip: 'Usar este color',
              onPressed: widget.habilitado ? _usarHexEscrito : null,
              icon: const Icon(Icons.check_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _CirculoColorMarca extends StatelessWidget {
  const _CirculoColorMarca({
    required this.color,
    required this.nombre,
    required this.elegido,
    required this.onTap,
    this.personalizado = false,
  });

  final Color color;
  final String nombre;
  final bool elegido;
  final VoidCallback? onTap;
  final bool personalizado;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegido,
      label: nombre,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: elegido ? AppColors.texto : Colors.white,
                  width: elegido ? 3 : 2,
                ),
                boxShadow: AppColors.sombraTarjeta,
              ),
              child: personalizado
                  ? const Icon(Icons.add_rounded, color: Colors.white)
                  : elegido
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22)
                      : null,
            ),
            const SizedBox(height: 6),
            Text(
              nombre,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoColorMarca extends StatefulWidget {
  const _DialogoColorMarca({required this.inicial});

  final Color inicial;

  @override
  State<_DialogoColorMarca> createState() => _DialogoColorMarcaState();
}

class _DialogoColorMarcaState extends State<_DialogoColorMarca> {
  late Color _color;

  @override
  void initState() {
    super.initState();
    _color = widget.inicial;
  }

  @override
  Widget build(BuildContext context) {
    final anchoPaleta = 240.0;
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Color personalizado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ColorPicker(
              pickerColor: _color,
              onColorChanged: (color) => setState(() => _color = color),
              paletteType: PaletteType.hsvWithHue,
              enableAlpha: false,
              labelTypes: const [],
              displayThumbColor: true,
              portraitOnly: true,
              colorPickerWidth: anchoPaleta,
              pickerAreaHeightPercent: 0.7,
              pickerAreaBorderRadius:
                  const BorderRadius.all(Radius.circular(12)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _color),
                  child: const Text('Usar este color'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
