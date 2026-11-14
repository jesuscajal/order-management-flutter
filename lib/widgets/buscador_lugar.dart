import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LugarElegido {
  const LugarElegido({
    required this.etiqueta,
    required this.lat,
    required this.lng,
    this.numero = '',
  });

  final String etiqueta;
  final double lat;
  final double lng;

  /// Numeración de la puerta, si el lugar la trae.
  final String numero;
}

/// Separa «Calle 123, Ciudad» en la calle y el número de puerta.
({String base, String numero}) partirDireccion(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty) return (base: '', numero: '');
  final partes = limpio.split(',');
  final primera = partes.first.trim();
  final resto = partes.skip(1).map((parte) => parte.trim()).where((parte) => parte.isNotEmpty);
  final numero = RegExp(r'^(.*\D)\s+(\d+[A-Za-z]?)$').firstMatch(primera);
  if (numero == null) return (base: limpio, numero: '');
  final calle = numero.group(1)!.trim();
  final puerta = numero.group(2)!;
  final cola = resto.join(', ');
  return (base: cola.isEmpty ? calle : '$calle, $cola', numero: puerta);
}

String direccionConNumero(String base, String numero) {
  final puerta = numero.trim();
  final limpia = base.trim();
  if (puerta.isEmpty) return limpia;
  if (limpia.isEmpty) return puerta;
  final partes = limpia.split(',');
  final calle = partes.first.trim();
  final yaTiene = RegExp('\\b${RegExp.escape(puerta)}\\b').hasMatch(calle);
  final via = yaTiene ? calle : '$calle $puerta';
  final cola = partes.skip(1).map((parte) => parte.trim()).where((parte) => parte.isNotEmpty).join(', ');
  return cola.isEmpty ? via : '$via, $cola';
}

/// Campo de lugar. Mientras se escribe, busca direcciones y la persona elige una.
///
/// Guarda la dirección con su numeración y el punto. La página abre Google Maps ahí.
class BuscadorLugar extends StatefulWidget {
  const BuscadorLugar({
    super.key,
    required this.controller,
    this.habilitado = true,
    this.onElegido,
    this.onCambioManual,
  });

  final TextEditingController controller;
  final bool habilitado;
  final ValueChanged<LugarElegido>? onElegido;
  final VoidCallback? onCambioManual;

  @override
  State<BuscadorLugar> createState() => _BuscadorLugarState();
}

class _BuscadorLugarState extends State<BuscadorLugar> {
  final _foco = FocusNode();
  final _numero = TextEditingController();
  Timer? _espera;
  Timer? _esperaNumero;
  int _consulta = 0;
  String? _elegido;
  String _base = '';
  String _avisoNumero = '';
  List<_Lugar> _resultados = const [];
  bool _buscando = false;
  bool _silencio = false;

  @override
  void initState() {
    super.initState();
    final partida = partirDireccion(widget.controller.text);
    _base = partida.base;
    _numero.text = partida.numero;
    widget.controller.addListener(_alCambiar);
    _numero.addListener(_alCambiarNumero);
    _foco.addListener(() {
      if (!_foco.hasFocus && mounted) {
        setState(() => _resultados = const []);
      }
    });
  }

  @override
  void didUpdateWidget(BuscadorLugar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_alCambiar);
    widget.controller.addListener(_alCambiar);
  }

  @override
  void dispose() {
    _espera?.cancel();
    _esperaNumero?.cancel();
    widget.controller.removeListener(_alCambiar);
    _numero.removeListener(_alCambiarNumero);
    _numero.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _alCambiarNumero() {
    if (_silencio) return;
    _esperaNumero?.cancel();
    _esperaNumero = Timer(const Duration(milliseconds: 600), _ubicarNumero);
  }

  Future<void> _ubicarNumero() async {
    final puerta = _numero.text.trim();
    final base = _base.trim().isEmpty ? partirDireccion(widget.controller.text).base : _base.trim();
    if (base.isEmpty) return;
    final direccion = direccionConNumero(base, puerta);
    if (puerta.isEmpty) {
      final calle = await _buscarUno(base);
      if (!mounted) return;
      _ponerDireccion(calle?.etiqueta ?? direccion);
      if (calle != null) {
        widget.onElegido?.call(
          LugarElegido(etiqueta: calle.etiqueta, lat: calle.lat, lng: calle.lng),
        );
      }
      setState(() => _avisoNumero = '');
      return;
    }
    final lugar = await _buscarUno(direccion);
    if (!mounted || _numero.text.trim() != puerta) return;
    if (lugar == null) {
      _ponerDireccion(direccion);
      setState(() => _avisoNumero = 'No encontré ese número. Se guarda la dirección y el punto de la calle.');
      return;
    }
    _base = partirDireccion(lugar.etiqueta).base;
    if (_base.isEmpty) _base = base;
    _ponerDireccion(lugar.etiqueta);
    widget.onElegido?.call(
      LugarElegido(
        etiqueta: lugar.etiqueta,
        lat: lugar.lat,
        lng: lugar.lng,
        numero: puerta,
      ),
    );
    setState(() => _avisoNumero = '');
  }

  void _ponerDireccion(String texto) {
    _elegido = texto;
    if (widget.controller.text == texto) return;
    widget.controller.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  void _alCambiar() {
    _espera?.cancel();
    final texto = widget.controller.text.trim();
    if (texto == _elegido) return;
    _base = partirDireccion(texto).base;
    widget.onCambioManual?.call();
    if (!widget.habilitado || texto.length < 3 || texto.contains('://')) {
      if (_resultados.isNotEmpty || _buscando) {
        setState(() {
          _resultados = const [];
          _buscando = false;
        });
      }
      return;
    }
    _espera = Timer(const Duration(milliseconds: 500), () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    final consulta = ++_consulta;
    setState(() => _buscando = true);
    try {
      final lugares = await _pedir(texto);
      if (!mounted || consulta != _consulta) return;
      if (widget.controller.text.trim() != texto) return;
      setState(() => _resultados = lugares);
    } catch (_) {
      if (!mounted || consulta != _consulta) return;
      setState(() => _resultados = const []);
    } finally {
      if (mounted && consulta == _consulta) setState(() => _buscando = false);
    }
  }

  Future<_Lugar?> _buscarUno(String texto) async {
    try {
      final lugares = await _pedir(texto);
      if (lugares.isEmpty) return null;
      return lugares.first;
    } catch (_) {
      return null;
    }
  }

  Future<List<_Lugar>> _pedir(String texto) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'limit': '5',
      'addressdetails': '1',
      'q': texto,
    });
    final respuesta = await http.get(uri, headers: const {
      'User-Agent': 'Gexi/1.0 (https://gexi.com.ar)',
      'Accept': 'application/json',
      'Accept-Language': 'es',
    }).timeout(const Duration(seconds: 8));
    if (respuesta.statusCode != 200) return const [];
    final decoded = jsonDecode(respuesta.body);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) _Lugar.de(Map<String, dynamic>.from(item)),
    ].whereType<_Lugar>().take(5).toList();
  }

  void _elegir(_Lugar lugar) {
    _consulta++;
    _espera?.cancel();
    _esperaNumero?.cancel();
    final partida = partirDireccion(lugar.etiqueta);
    _base = partida.base.isEmpty ? lugar.etiqueta : partida.base;
    _avisoNumero = '';
    _ponerNumero(lugar.numero.isNotEmpty ? lugar.numero : partida.numero);
    _ponerDireccion(lugar.etiqueta);
    widget.onElegido?.call(
      LugarElegido(
        etiqueta: lugar.etiqueta,
        lat: lugar.lat,
        lng: lugar.lng,
        numero: _numero.text.trim(),
      ),
    );
    setState(() => _resultados = const []);
    _foco.unfocus();
  }

  void _ponerNumero(String numero) {
    _silencio = true;
    _numero.text = numero;
    _silencio = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _foco,
          enabled: widget.habilitado,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 400,
          decoration: InputDecoration(
            labelText: 'Ubicación del local',
            hintText: 'Calle, barrio o ciudad',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            helperText:
                'Elegí la calle en la lista. Después cargá el número de la puerta.',
          ),
        ),
        if (_resultados.isNotEmpty)
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                for (final lugar in _resultados)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(lugar.etiqueta),
                    onTap: () => _elegir(lugar),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _numero,
          enabled: widget.habilitado,
          keyboardType: TextInputType.text,
          maxLength: 12,
          decoration: InputDecoration(
            labelText: 'Numeración',
            hintText: '1234',
            prefixIcon: const Icon(Icons.pin_outlined),
            helperText: _avisoNumero.isEmpty
                ? 'Con el número, Cómo llegar abre ese punto en Google Maps.'
                : _avisoNumero,
          ),
        ),
      ],
    );
  }
}

class _Lugar {
  const _Lugar(this.etiqueta, this.lat, this.lng, {this.numero = ''});

  final String etiqueta;
  final double lat;
  final double lng;
  final String numero;

  static _Lugar? de(Map<String, dynamic> fila) {
    final lat = double.tryParse(fila['lat']?.toString() ?? '');
    final lng = double.tryParse(fila['lon']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    final direccion = fila['address'];
    final mapa = direccion is Map
        ? Map<String, dynamic>.from(direccion)
        : const <String, dynamic>{};
    String texto(String clave) => mapa[clave]?.toString().trim() ?? '';
    final via = [texto('road'), texto('house_number')]
        .where((parte) => parte.isNotEmpty)
        .join(' ');
    final partes = <String>[
      if (via.isNotEmpty) via,
      for (final clave in ['suburb', 'city', 'town', 'village', 'state', 'country'])
        if (texto(clave).isNotEmpty) texto(clave),
    ];
    final vistos = <String>{};
    final unicos = [
      for (final parte in partes)
        if (vistos.add(parte.toLowerCase())) parte,
    ];
    var etiqueta = unicos.take(4).join(', ');
    if (etiqueta.isEmpty) {
      etiqueta = (fila['display_name']?.toString() ?? '').trim();
    }
    if (etiqueta.length > 180) etiqueta = etiqueta.substring(0, 180);
    if (etiqueta.isEmpty) return null;
    return _Lugar(etiqueta, lat, lng, numero: texto('house_number'));
  }
}
