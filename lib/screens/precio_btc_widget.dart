import 'package:flutter/material.dart';
import '../utils/binance_api.dart';

class PrecioBTCWidget extends StatefulWidget {
  final String label;
  const PrecioBTCWidget({super.key, this.label = 'BTC/USDT'});

  @override
  State<PrecioBTCWidget> createState() => _PrecioBTCWidgetState();
}

class _PrecioBTCWidgetState extends State<PrecioBTCWidget> {
  double? precio;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchBTCUSDT().then((value) {
      setState(() {
        precio = value;
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Text('Cargando precio ${widget.label}...');
    }
    if (precio == null) {
      return const Text('Error al obtener precio');
    }
    return Text(
      '${widget.label}: \$${precio!.toStringAsFixed(2)}',
      style: const TextStyle(
          fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
    );
  }
}
