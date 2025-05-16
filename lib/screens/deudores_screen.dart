import 'package:flutter/material.dart';
import '../models/movimiento_capital.dart';

class DeudoresScreen extends StatefulWidget {
  const DeudoresScreen({super.key});

  @override
  State<DeudoresScreen> createState() => _DeudoresScreenState();
}

class _DeudoresScreenState extends State<DeudoresScreen> {
  // Lista de movimientos de ejemplo
  final List<MovimientoCapital> _movimientos = [
    MovimientoCapital.crear(
      persona: 'Juan Pérez',
      monto: 1000,
      tipo: TipoMovimiento.prestamo,
      descripcion: 'Préstamo inicial',
    ),
    MovimientoCapital.crear(
      persona: 'Juan Pérez',
      monto: 500,
      tipo: TipoMovimiento.devolucion,
      descripcion: 'Primera devolución',
    ),
    MovimientoCapital.crear(
      persona: 'María García',
      monto: 2000,
      tipo: TipoMovimiento.prestamo,
      descripcion: 'Préstamo para negocio',
    ),
  ];

  // Obtener resumen de deudores
  List<ResumenDeudor> get _resumenDeudores {
    final Map<String, List<MovimientoCapital>> movimientosPorPersona = {};

    for (var movimiento in _movimientos) {
      movimientosPorPersona
          .putIfAbsent(movimiento.persona, () => [])
          .add(movimiento);
    }

    return movimientosPorPersona.entries
        .map((e) => ResumenDeudor(persona: e.key, movimientos: e.value))
        .where((r) => r.montoAdeudado > 0)
        .toList();
  }

  // Calcular total global adeudado
  double get _totalGlobalAdeudado {
    return _resumenDeudores.fold(0, (sum, r) => sum + r.montoAdeudado);
  }

  void _mostrarDialogoDevolucion(ResumenDeudor deudor) {
    final controllerMonto = TextEditingController();
    final controllerDescripcion = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Registrar Devolución'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controllerMonto,
                  decoration: const InputDecoration(
                    labelText: 'Monto devuelto',
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controllerDescripcion,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final monto = double.tryParse(controllerMonto.text) ?? 0;
                  if (monto > 0) {
                    setState(() {
                      _movimientos.add(
                        MovimientoCapital.crear(
                          persona: deudor.persona,
                          monto: monto,
                          tipo: TipoMovimiento.devolucion,
                          descripcion:
                              controllerDescripcion.text.isEmpty
                                  ? 'Devolución'
                                  : controllerDescripcion.text,
                        ),
                      );
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Deudores',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Resumen global
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Adeudado',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_totalGlobalAdeudado.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lista de deudores
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _resumenDeudores.length,
              itemBuilder: (context, index) {
                final deudor = _resumenDeudores[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              deudor.persona,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '\$${deudor.montoAdeudado.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        if (deudor.ultimoMovimiento != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Último movimiento: ${deudor.ultimoMovimiento!.descripcion}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    () => _mostrarDialogoDevolucion(deudor),
                                icon: const Icon(Icons.payment),
                                label: const Text('Registrar Devolución'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}
