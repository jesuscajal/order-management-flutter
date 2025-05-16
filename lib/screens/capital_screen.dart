import 'package:flutter/material.dart';

class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key});

  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen> {
  // Datos simulados
  final List<String> users = ['Kevin', 'Nildo'];
  final List<String> tipos = [
    'Inversión',
    'Transferencia',
    'Capital a cobrar',
    'Entrada',
    'Salida',
  ];

  List<Map<String, dynamic>> movimientos = [
    {
      'fecha': '24 abr. 2024',
      'descripcion': 'Transferencia a Kevin',
      'monto': -100,
      'tipo': 'Salida',
      'persona': 'Kevin',
    },
    {
      'fecha': '23 abr. 2024',
      'descripcion': 'Transferencia a Nildo',
      'monto': -50,
      'tipo': 'Salida',
      'persona': 'Nildo',
    },
    {
      'fecha': '22 abr. 2024',
      'descripcion': 'Aporte de capital',
      'monto': 200,
      'tipo': 'Entrada',
      'persona': 'Kevin',
    },
    {
      'fecha': '21 abr. 2024',
      'descripcion': 'Pago de TMA S.R.L.',
      'monto': 300,
      'tipo': 'Entrada',
      'persona': 'Nildo',
    },
  ];

  void _addMovimiento(Map<String, dynamic> mov) {
    setState(() {
      movimientos.insert(0, mov);
    });
  }

  Map<String, int> getCapitalPorPersona() {
    final Map<String, int> capital = {for (var u in users) u: 0};
    for (var mov in movimientos) {
      if (capital.containsKey(mov['persona'])) {
        capital[mov['persona']] =
            capital[mov['persona']]! + (mov['monto'] as int);
      }
    }
    return capital;
  }

  void _showAddMovimientoDialog() {
    String? persona = users.first;
    String? tipo = tipos.first;
    String descripcion = '';
    int? monto;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo movimiento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: persona,
                  items: users
                      .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u)),
                      )
                      .toList(),
                  onChanged: (v) => persona = v,
                  decoration: const InputDecoration(labelText: 'Persona'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tipo,
                  items: tipos
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t)),
                      )
                      .toList(),
                  onChanged: (v) => tipo = v,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  onChanged: (v) => descripcion = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Monto (USDT)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => monto = int.tryParse(v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (persona != null && tipo != null && monto != null) {
                  _addMovimiento({
                    'fecha':
                        '${DateTime.now().day} ${_mes(DateTime.now().month)}. ${DateTime.now().year}',
                    'descripcion': descripcion.isEmpty ? tipo! : descripcion,
                    'monto': monto,
                    'tipo': tipo,
                    'persona': persona,
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
  }

  String _mes(int m) {
    const meses = [
      '',
      'ene.',
      'feb.',
      'mar.',
      'abr.',
      'may.',
      'jun.',
      'jul.',
      'ago.',
      'sep.',
      'oct.',
      'nov.',
      'dic.',
    ];
    return meses[m];
  }

  @override
  Widget build(BuildContext context) {
    final capital = getCapitalPorPersona();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Capital',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen del capital',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kevin', style: Theme.of(context).textTheme.bodyLarge),
                    Text('${capital['Kevin'] ?? 0} USDT',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nildo', style: Theme.of(context).textTheme.bodyLarge),
                    Text('${capital['Nildo'] ?? 0} USDT',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Movimientos recientes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Fecha',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Descripción',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Monto',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Tipo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    itemCount: movimientos.length,
                    itemBuilder: (context, index) {
                      final m = movimientos[index];
                      final monto = m['monto'] as int;
                      final isEntrada = monto > 0;
                      Color color = isEntrada ? Colors.green : Colors.red;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(m['fecha'])),
                            Expanded(flex: 3, child: Text(m['descripcion'])),
                            Expanded(
                              flex: 2,
                              child: Text(
                                (isEntrada ? '+' : '') + '$monto USDT',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(flex: 2, child: Text(m['tipo'])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _showAddMovimientoDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: const Text(
                '+ Nuevo movimiento',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
