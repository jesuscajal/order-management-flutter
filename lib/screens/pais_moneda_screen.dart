import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/paises_latam.dart';
import '../services/convertir_moneda.dart';
import '../services/cotizacion.dart';
import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

/// Nacionalidad de América Latina y cambio de moneda del negocio.
class PaisMonedaScreen extends StatefulWidget {
  const PaisMonedaScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<PaisMonedaScreen> createState() => _PaisMonedaScreenState();
}

class _PaisMonedaScreenState extends State<PaisMonedaScreen> {
  final _store = NegocioStore();
  String _pais = 'AR';
  String _moneda = 'ARS';
  String _monedaGuardada = 'ARS';
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final negocio = await _store.leer();
    final pais = paisPorCodigo(negocio?.pais) ?? paisesLatam.first;
    final moneda = NegocioLocal.normalizarMoneda(negocio?.moneda);
    if (!mounted) return;
    setState(() {
      _pais = pais.codigo;
      _moneda = moneda;
      _monedaGuardada = moneda;
      _cargando = false;
    });
  }

  PaisLatam get _elegido => paisPorCodigo(_pais) ?? paisesLatam.first;

  bool get _cambiaMoneda =>
      NegocioLocal.normalizarMoneda(_moneda) != _monedaGuardada;

  String _tasa(double factor) {
    final decimales = factor >= 1 ? 2 : 6;
    return factor.toStringAsFixed(decimales).replaceAll('.', ',');
  }

  List<PaisLatam> get _monedas {
    final lista = monedasParaElegir();
    if (lista.any((pais) => pais.moneda == _moneda)) return lista;
    return [
      ...lista,
      PaisLatam(
        codigo: 'XX',
        nombre: _moneda,
        nacionalidad: _moneda,
        moneda: _moneda,
        nombreMoneda: _moneda,
        prefijo: '',
        ejemplo: '',
      ),
    ];
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final actual = await _store.leer();
      if (actual == null) {
        throw StateError('No hay un negocio en este teléfono.');
      }
      final pais = _elegido;
      final monedaNueva = NegocioLocal.normalizarMoneda(_moneda);
      if (monedaNueva != _monedaGuardada) {
        final factor = await Cotizacion.factor(
          desde: _monedaGuardada,
          hacia: monedaNueva,
        );
        if (!mounted) return;
        final acepta = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Convertir importes'),
            content: Text(
              '1 $_monedaGuardada = ${_tasa(factor)} $monedaNueva.\n\n'
              'Se convierten precios de costo, precios de venta, pedidos, '
              'deudas y capital. Esos importes se guardan en Supabase y '
              'la página web del negocio pasa a mostrarlos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Convertir'),
              ),
            ],
          ),
        );
        if (acepta != true) {
          if (mounted) setState(() => _guardando = false);
          return;
        }
        await ConvertirMoneda.aplicar(
          database: widget.database,
          factor: factor,
        );
      }
      final nuevo = actual.copiar(
        pais: pais.codigo,
        nacionalidad: pais.nacionalidad,
        moneda: monedaNueva,
      );
      await _store.guardarLocal(nuevo);
      final publicar = NegocioStore.alPublicar;
      if (publicar != null) {
        try {
          await publicar(nuevo);
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Quedó guardado en el teléfono. No se pudo subir a la nube: $error',
              ),
            ),
          );
          Navigator.of(context).pop(true);
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Guardado: ${pais.etiquetaNacionalidad}. Moneda $monedaNueva. '
            'Los teléfonos usan ${pais.prefijo}.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final pais = _elegido;
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar de moneda')),
      body: FondoGexi(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    'Nacionalidad',
                    style: tema.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elegí el país de América Latina. La nacionalidad, la moneda y la característica del teléfono salen de ahí.',
                    style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _pais,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nacionalidad',
                    ),
                    items: [
                      for (final opcion in paisesLatam)
                        DropdownMenuItem(
                          value: opcion.codigo,
                          child: Text(opcion.etiquetaNacionalidad),
                        ),
                    ],
                    onChanged: _guardando
                        ? null
                        : (valor) {
                            final elegido = paisPorCodigo(valor);
                            if (elegido == null) return;
                            setState(() {
                              _pais = elegido.codigo;
                              _moneda = elegido.moneda;
                            });
                          },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Cambiar de moneda',
                    style: tema.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Al elegir la nacionalidad se propone ${pais.nombreMoneda} (${pais.moneda}). Si cambiás la moneda, los precios, las deudas y el capital se convierten con la cotización del día y se actualizan en la página web.',
                    style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_moneda),
                    initialValue: _moneda,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Moneda',
                    ),
                    items: [
                      for (final opcion in _monedas)
                        DropdownMenuItem(
                          value: opcion.moneda,
                          child: Text(opcion.etiquetaMoneda),
                        ),
                    ],
                    onChanged: _guardando
                        ? null
                        : (valor) {
                            if (valor == null) return;
                            setState(() => _moneda = valor);
                          },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppColors.tarjeta,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teléfono de ${pais.nombre}',
                          style: tema.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Característica ${pais.prefijo}. Ejemplo: ${pais.prefijo} ${pais.ejemplo}.',
                          style: tema.textTheme.bodyMedium?.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(
                      _guardando
                          ? 'Guardando...'
                          : (_cambiaMoneda ? 'Convertir y guardar' : 'Guardar'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
