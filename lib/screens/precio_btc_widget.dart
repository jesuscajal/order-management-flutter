import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
    final texto = loading
        ? 'Cargando ${widget.label}...'
        : precio == null
            ? 'No se pudo leer ${widget.label}'
            : '\$${precio!.toStringAsFixed(2)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppColors.tarjeta,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F9EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.trending_up_rounded, color: AppColors.verde, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(color: AppColors.textoSuave, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            texto,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
