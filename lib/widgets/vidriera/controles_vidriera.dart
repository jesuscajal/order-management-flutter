import 'package:flutter/material.dart';

import '../../data/tienda_catalogo.dart';
import '../../theme/app_theme.dart';
import 'modelo_vidriera.dart';

class PedidoItemVidriera {
  const PedidoItemVidriera({
    required this.cantidadDe,
    required this.cantidadVariante,
    required this.onCambiar,
    required this.onVariante,
  });

  final int Function(ItemVidriera item) cantidadDe;
  final int Function(ItemVidriera item, String etiqueta) cantidadVariante;
  final void Function(ItemVidriera item, int delta) onCambiar;
  final void Function(ItemVidriera item, String etiqueta, int delta) onVariante;
}

enum TrazoControl { lleno, contorno, denso }

class ControlPedidoVidriera extends StatelessWidget {
  const ControlPedidoVidriera({
    super.key,
    required this.elegida,
    required this.tope,
    required this.subtotal,
    required this.moneda,
    required this.etiqueta,
    required this.cromo,
    required this.onMenos,
    required this.onMas,
    this.trazo = TrazoControl.lleno,
    this.alinear = Alignment.centerLeft,
  });

  final int elegida;
  final int tope;
  final double subtotal;
  final String moneda;
  final String etiqueta;
  final CromoVidriera cromo;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final TrazoControl trazo;
  final Alignment alinear;

  @override
  Widget build(BuildContext context) {
    final agotado = tope <= 0;
    if (elegida <= 0) {
      return Align(alignment: alinear, child: _boton(agotado));
    }
    final pasos = Row(
      mainAxisSize: trazo == TrazoControl.denso
          ? MainAxisSize.min
          : MainAxisSize.max,
      children: [
        _Paso(
          icono: Icons.remove,
          habilitado: true,
          onPressed: onMenos,
          cromo: cromo,
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$elegida',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cromo.texto,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _Paso(
          icono: Icons.add,
          habilitado: elegida < tope,
          onPressed: onMas,
          cromo: cromo,
        ),
        if (trazo != TrazoControl.denso) ...[
          const Spacer(),
          Flexible(
            child: Text(
              monedaTienda(subtotal, moneda),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: cromo.texto,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
    if (trazo != TrazoControl.denso) return pasos;
    return Column(
      crossAxisAlignment: alinear == Alignment.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        pasos,
        const SizedBox(height: 4),
        Text(
          monedaTienda(subtotal, moneda),
          style: TextStyle(
            color: cromo.texto,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _boton(bool agotado) {
    final alto = trazo == TrazoControl.denso ? 40.0 : 48.0;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        trazo == TrazoControl.denso ? 8 : cromo.radio,
      ),
    );
    final texto = Text(
      agotado ? 'Agotado' : etiqueta,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final estilo = TextStyle(
      fontSize: trazo == TrazoControl.denso ? 14 : 16,
      fontWeight: FontWeight.w800,
      letterSpacing: trazo == TrazoControl.contorno ? 1.1 : 0,
    );
    if (trazo == TrazoControl.contorno) {
      return OutlinedButton(
        onPressed: agotado ? null : onMas,
        style: OutlinedButton.styleFrom(
          foregroundColor: cromo.acento,
          disabledForegroundColor: cromo.textoSuave,
          side: BorderSide(color: agotado ? cromo.linea : cromo.acento),
          minimumSize: Size(double.infinity, alto),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: forma,
          textStyle: estilo,
        ),
        child: texto,
      );
    }
    return FilledButton(
      onPressed: agotado ? null : onMas,
      style: FilledButton.styleFrom(
        backgroundColor: cromo.acento,
        foregroundColor: cromo.sobreAcento,
        disabledBackgroundColor: cromo.oscuro ? cromo.linea : AppColors.linea,
        disabledForegroundColor: cromo.textoSuave,
        elevation: 0,
        minimumSize: Size(double.infinity, alto),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: forma,
        textStyle: estilo,
      ),
      child: texto,
    );
  }
}

class VariantesVidriera extends StatelessWidget {
  const VariantesVidriera({
    super.key,
    required this.item,
    required this.moneda,
    required this.cromo,
    required this.pedido,
    required this.etiqueta,
    this.mostrarStock = true,
    this.trazo = TrazoControl.lleno,
    this.centrado = false,
  });

  final ItemVidriera item;
  final String moneda;
  final CromoVidriera cromo;
  final PedidoItemVidriera pedido;
  final String etiqueta;
  final bool mostrarStock;
  final TrazoControl trazo;
  final bool centrado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          centrado ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < item.variantes.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _fila(item.variantes[i]),
        ],
      ],
    );
  }

  Widget _fila(VarianteItemVidriera variante) {
    final elegida = pedido.cantidadVariante(item, variante.etiqueta);
    final agotada = variante.stock <= 0;
    return Column(
      crossAxisAlignment:
          centrado ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          variante.etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centrado ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: cromo.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          monedaTienda(variante.precio, moneda),
          style: TextStyle(color: cromo.acento, fontWeight: FontWeight.w800),
        ),
        if (mostrarStock || agotada)
          Text(
            agotada
                ? 'Agotada'
                : (mostrarStock ? 'Stock: ${variante.stock}' : ''),
            style: TextStyle(
              color: agotada ? AppColors.alerta : cromo.textoSuave,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 8),
        ControlPedidoVidriera(
          elegida: elegida,
          tope: variante.stock,
          subtotal: variante.precio * elegida,
          moneda: moneda,
          etiqueta: etiqueta,
          cromo: cromo,
          trazo: trazo,
          alinear: centrado ? Alignment.center : Alignment.centerLeft,
          onMenos: () => pedido.onVariante(item, variante.etiqueta, -1),
          onMas: () => pedido.onVariante(item, variante.etiqueta, 1),
        ),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.icono,
    required this.habilitado,
    required this.onPressed,
    required this.cromo,
  });

  final IconData icono;
  final bool habilitado;
  final VoidCallback onPressed;
  final CromoVidriera cromo;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: habilitado ? onPressed : null,
      visualDensity: VisualDensity.compact,
      icon: Icon(icono, size: 18),
      color: cromo.acento,
      disabledColor: cromo.textoSuave,
      style: IconButton.styleFrom(
        backgroundColor: cromo.acento.withValues(alpha: 0.14),
        disabledBackgroundColor: cromo.oscuro ? cromo.linea : AppColors.linea,
        shape: const CircleBorder(),
      ),
    );
  }
}
