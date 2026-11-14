import 'package:flutter/material.dart';

import '../../data/tienda_catalogo.dart';
import '../../theme/app_theme.dart';
import 'controles_vidriera.dart';
import 'foto_vidriera.dart';
import 'modelo_vidriera.dart';

/// Dibuja el catálogo con la plantilla elegida. El pedido lo resuelve la pantalla.
List<Widget> sliversVidriera({
  required List<SeccionVidriera> secciones,
  required PresentacionVidriera presentacion,
  required CromoVidriera cromo,
  required String moneda,
  required PedidoItemVidriera pedido,
}) {
  final salida = <Widget>[];
  for (final seccion in secciones) {
    if (seccion.titulo.isNotEmpty) {
      salida.add(
        SliverToBoxAdapter(
          child: _TituloSeccion(
            titulo: seccion.titulo,
            presentacion: presentacion,
            cromo: cromo,
          ),
        ),
      );
    }
    salida.add(
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          _margen(presentacion.plantillaId),
          0,
          _margen(presentacion.plantillaId),
          8,
        ),
        sliver: SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _GrillaPlantilla(
                items: seccion.items,
                ancho: constraints.maxWidth,
                presentacion: presentacion,
                cromo: cromo,
                moneda: moneda,
                pedido: pedido,
              );
            },
          ),
        ),
      ),
    );
  }
  return salida;
}

class _GrillaPlantilla extends StatelessWidget {
  const _GrillaPlantilla({
    required this.items,
    required this.ancho,
    required this.presentacion,
    required this.cromo,
    required this.moneda,
    required this.pedido,
  });

  final List<ItemVidriera> items;
  final double ancho;
  final PresentacionVidriera presentacion;
  final CromoVidriera cromo;
  final String moneda;
  final PedidoItemVidriera pedido;

  @override
  Widget build(BuildContext context) {
    if (!ancho.isFinite || ancho <= 0) return const SizedBox.shrink();
    final columnas = columnasDePlantilla(
      plantillaId: presentacion.plantillaId,
      pedidas: presentacion.columnas,
      ancho: ancho,
    );
    final espacio = _espacio(presentacion.plantillaId);
    final anchoItem = columnas == 1
        ? ancho
        : ((ancho - espacio * (columnas - 1)) / columnas) - 0.5;
    return Wrap(
      spacing: espacio,
      runSpacing: espacio,
      children: [
        for (final item in items)
          SizedBox(
            width: anchoItem,
            child: _tarjeta(item),
          ),
      ],
    );
  }

  Widget _tarjeta(ItemVidriera item) {
    switch (presentacion.plantillaId) {
      case 'menu':
        return _TarjetaMenu(
          item: item,
          cromo: cromo,
          moneda: moneda,
          pedido: pedido,
          etiqueta: presentacion.etiquetaProducto,
        );
      case 'tecnologia':
        return _TarjetaTecnologia(
          item: item,
          cromo: cromo,
          moneda: moneda,
          pedido: pedido,
          etiqueta: presentacion.etiquetaProducto,
        );
      case 'ropa':
        return _TarjetaRopa(
          item: item,
          cromo: cromo,
          moneda: moneda,
          pedido: pedido,
          etiqueta: presentacion.etiquetaProducto,
        );
      case 'cosmeticos':
        return _TarjetaCosmeticos(
          item: item,
          cromo: cromo,
          moneda: moneda,
          pedido: pedido,
          etiqueta: presentacion.etiquetaProducto,
        );
      case 'servicios':
        return _TarjetaServicios(
          item: item,
          cromo: cromo,
          moneda: moneda,
          pedido: pedido,
        );
      case 'perfumes':
        return _TarjetaPerfumes(
          item: item,
          cromo: cromo,
          moneda: moneda,
          pedido: pedido,
          etiqueta: presentacion.etiquetaProducto,
        );
      default:
        return _TarjetaGeneral(
          item: item,
          cromo: cromo,
          moneda: moneda,
          pedido: pedido,
          etiqueta: presentacion.etiquetaProducto,
        );
    }
  }
}

class _TarjetaMenu extends StatelessWidget {
  const _TarjetaMenu({
    required this.item,
    required this.cromo,
    required this.moneda,
    required this.pedido,
    required this.etiqueta,
  });

  final ItemVidriera item;
  final CromoVidriera cromo;
  final String moneda;
  final PedidoItemVidriera pedido;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final foto = item.fotos.isEmpty ? null : item.fotos.first;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cromo.linea)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FotoVidriera(
            bytes: foto?.bytes,
            url: foto?.url,
            color: cromo.acento,
            inicial: item.inicial,
            alto: 64,
            ancho: 64,
            circular: true,
            tamanoInicial: 22,
            fondo: cromo.acento.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cromo.texto,
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (item.variantes.isEmpty) ...[
                      const SizedBox(width: 12),
                      Text(
                        monedaTienda(item.precio, moneda),
                        style: TextStyle(
                          color: cromo.acento,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.descripcion.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.descripcion.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cromo.textoSuave,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                if (item.variantes.isEmpty) ...[
                  Text(
                    item.stock <= 0 ? 'Agotado' : 'Stock: ${item.stock}',
                    style: TextStyle(
                      color: item.stock <= 0
                          ? AppColors.alerta
                          : cromo.textoSuave,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 168),
                      child: ControlPedidoVidriera(
                        elegida: pedido.cantidadDe(item),
                        tope: item.stock,
                        subtotal: item.precio * pedido.cantidadDe(item),
                        moneda: moneda,
                        etiqueta: etiqueta,
                        cromo: cromo,
                        trazo: TrazoControl.denso,
                        onMenos: () => pedido.onCambiar(item, -1),
                        onMas: () => pedido.onCambiar(item, 1),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  VariantesVidriera(
                    item: item,
                    moneda: moneda,
                    cromo: cromo,
                    pedido: pedido,
                    etiqueta: etiqueta,
                    trazo: TrazoControl.denso,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _TarjetaTecnologia extends StatelessWidget {
  const _TarjetaTecnologia({
    required this.item,
    required this.cromo,
    required this.moneda,
    required this.pedido,
    required this.etiqueta,
  });

  final ItemVidriera item;
  final CromoVidriera cromo;
  final String moneda;
  final PedidoItemVidriera pedido;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final foto = item.fotos.isEmpty ? null : item.fotos.first;
    final categoria = item.categorias.isEmpty ? '' : item.categorias.first;
    final cantidad = pedido.cantidadDe(item);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cromo.tarjeta,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cromo.linea),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ColoredBox(
            color: cromo.oscuro
                ? const Color(0xFF0E141A)
                : const Color(0xFFE7EDF3),
            child: FotoVidriera(
              bytes: foto?.bytes,
              url: foto?.url,
              color: cromo.acento,
              inicial: item.inicial,
              alto: 132,
              ajuste: BoxFit.contain,
              fondo: Colors.transparent,
              tamanoInicial: 32,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categoria.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cromo.acento.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      categoria.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cromo.acento,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                Text(
                  item.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cromo.texto,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.descripcion.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.descripcion.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cromo.textoSuave,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                if (item.pieFotos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.pieFotos,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cromo.textoSuave, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 10),
                if (item.variantes.isEmpty) ...[
                  Text(
                    monedaTienda(item.precio, moneda),
                    style: TextStyle(
                      color: cromo.acento,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    item.stock <= 0 ? 'Sin stock' : 'Disp. ${item.stock}',
                    style: TextStyle(
                      color: item.stock <= 0
                          ? AppColors.alerta
                          : cromo.textoSuave,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ControlPedidoVidriera(
                    elegida: cantidad,
                    tope: item.stock,
                    subtotal: item.precio * cantidad,
                    moneda: moneda,
                    etiqueta: etiqueta,
                    cromo: cromo,
                    onMenos: () => pedido.onCambiar(item, -1),
                    onMas: () => pedido.onCambiar(item, 1),
                  ),
                ] else
                  VariantesVidriera(
                    item: item,
                    moneda: moneda,
                    cromo: cromo,
                    pedido: pedido,
                    etiqueta: etiqueta,
                    trazo: TrazoControl.denso,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaRopa extends StatelessWidget {
  const _TarjetaRopa({
    required this.item,
    required this.cromo,
    required this.moneda,
    required this.pedido,
    required this.etiqueta,
  });

  final ItemVidriera item;
  final CromoVidriera cromo;
  final String moneda;
  final PedidoItemVidriera pedido;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final foto = item.fotos.isEmpty ? null : item.fotos.first;
    final cantidad = pedido.cantidadDe(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: FotoVidriera(
            bytes: foto?.bytes,
            url: foto?.url,
            color: cromo.acento,
            inicial: item.inicial,
            ajuste: BoxFit.cover,
            fondo: cromo.oscuro
                ? const Color(0xFF1C1C1C)
                : const Color(0xFFE6E6E6),
            tamanoInicial: 42,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.nombre,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cromo.texto,
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        if (item.variantes.isEmpty)
          Text(
            monedaTienda(item.precio, moneda),
            style: TextStyle(
              color: cromo.texto,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Text(
            'Desde ${monedaTienda(_menor(item), moneda)}',
            style: TextStyle(
              color: cromo.texto,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (item.variantes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              item.stock <= 0 ? 'Agotado' : 'Stock: ${item.stock}',
              style: TextStyle(
                color: item.stock <= 0 ? AppColors.alerta : cromo.textoSuave,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (item.variantes.isEmpty)
          ControlPedidoVidriera(
            elegida: cantidad,
            tope: item.stock,
            subtotal: item.precio * cantidad,
            moneda: moneda,
            etiqueta: etiqueta,
            cromo: cromo,
            trazo: TrazoControl.contorno,
            onMenos: () => pedido.onCambiar(item, -1),
            onMas: () => pedido.onCambiar(item, 1),
          )
        else
          VariantesVidriera(
            item: item,
            moneda: moneda,
            cromo: cromo,
            pedido: pedido,
            etiqueta: etiqueta,
            trazo: TrazoControl.denso,
          ),
      ],
    );
  }
}

class _TarjetaCosmeticos extends StatelessWidget {
  const _TarjetaCosmeticos({
    required this.item,
    required this.cromo,
    required this.moneda,
    required this.pedido,
    required this.etiqueta,
  });

  final ItemVidriera item;
  final CromoVidriera cromo;
  final String moneda;
  final PedidoItemVidriera pedido;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final foto = item.fotos.isEmpty ? null : item.fotos.first;
    final cantidad = pedido.cantidadDe(item);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        color: cromo.acento.withValues(alpha: cromo.oscuro ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          FotoVidriera(
            bytes: foto?.bytes,
            url: foto?.url,
            color: cromo.acento,
            inicial: item.inicial,
            alto: 112,
            ancho: 112,
            circular: true,
            tamanoInicial: 32,
            fondo: cromo.tarjeta,
          ),
          const SizedBox(height: 12),
          Text(
            item.nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cromo.texto,
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (item.descripcion.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.descripcion.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cromo.textoSuave,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (item.variantes.isEmpty) ...[
            Text(
              monedaTienda(item.precio, moneda),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cromo.acento,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              item.stock <= 0 ? 'Agotado' : 'Stock: ${item.stock}',
              style: TextStyle(
                color: item.stock <= 0 ? AppColors.alerta : cromo.textoSuave,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            ControlPedidoVidriera(
              elegida: cantidad,
              tope: item.stock,
              subtotal: item.precio * cantidad,
              moneda: moneda,
              etiqueta: etiqueta,
              cromo: _cromoRedondo(cromo),
              onMenos: () => pedido.onCambiar(item, -1),
              onMas: () => pedido.onCambiar(item, 1),
            ),
          ] else
            VariantesVidriera(
              item: item,
              moneda: moneda,
              cromo: cromo,
              pedido: pedido,
              etiqueta: etiqueta,
              centrado: true,
              trazo: TrazoControl.denso,
            ),
        ],
      ),
    );
  }
}

class _TarjetaServicios extends StatelessWidget {
  const _TarjetaServicios({
    required this.item,
    required this.cromo,
    required this.moneda,
    required this.pedido,
  });

  final ItemVidriera item;
  final CromoVidriera cromo;
  final String moneda;
  final PedidoItemVidriera pedido;

  @override
  Widget build(BuildContext context) {
    final cantidad = pedido.cantidadDe(item);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: cromo.tarjeta,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: cromo.acento, width: 4),
          top: BorderSide(color: cromo.linea),
          right: BorderSide(color: cromo.linea),
          bottom: BorderSide(color: cromo.linea),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cromo.acento.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  item.inicial,
                  style: TextStyle(
                    color: cromo.acento,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre,
                      style: TextStyle(
                        color: cromo.texto,
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.variantes.isEmpty
                          ? monedaTienda(item.precio, moneda)
                          : 'Desde ${monedaTienda(_menor(item), moneda)}',
                      style: TextStyle(
                        color: cromo.acento,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.descripcion.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                item.descripcion.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cromo.textoSuave,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (item.variantes.isEmpty)
            ControlPedidoVidriera(
              elegida: cantidad,
              tope: item.stock,
              subtotal: item.precio * cantidad,
              moneda: moneda,
              etiqueta: 'Consultar',
              cromo: cromo,
              trazo: TrazoControl.contorno,
              onMenos: () => pedido.onCambiar(item, -1),
              onMas: () => pedido.onCambiar(item, 1),
            )
          else
            VariantesVidriera(
              item: item,
              moneda: moneda,
              cromo: cromo,
              pedido: pedido,
              etiqueta: 'Consultar',
              mostrarStock: false,
              trazo: TrazoControl.contorno,
            ),
        ],
      ),
    );
  }
}

class _TarjetaPerfumes extends StatelessWidget {
  const _TarjetaPerfumes({
    required this.item,
    required this.cromo,
    required this.moneda,
    required this.pedido,
    required this.etiqueta,
  });

  final ItemVidriera item;
  final CromoVidriera cromo;
  final String moneda;
  final PedidoItemVidriera pedido;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final foto = item.fotos.isEmpty ? null : item.fotos.first;
    final cantidad = pedido.cantidadDe(item);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: cromo.acento.withValues(alpha: 0.35),
                ),
              ),
              child: FotoVidriera(
                bytes: foto?.bytes,
                url: foto?.url,
                color: cromo.acento,
                inicial: item.inicial,
                ajuste: BoxFit.cover,
                fondo: cromo.oscuro
                    ? const Color(0xFF141218)
                    : const Color(0xFFEDE8E1),
                tamanoInicial: 48,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            item.nombre.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cromo.texto,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w300,
              letterSpacing: 3.2,
            ),
          ),
          const SizedBox(height: 10),
          Container(width: 36, height: 1, color: cromo.acento),
          if (item.descripcion.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                item.descripcion.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cromo.textoSuave,
                  fontSize: 14,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (item.variantes.isEmpty) ...[
            Text(
              monedaTienda(item.precio, moneda),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cromo.texto,
                fontSize: 15,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.stock <= 0 ? 'Agotado' : 'Stock: ${item.stock}',
                style: TextStyle(
                  color: item.stock <= 0 ? AppColors.alerta : cromo.textoSuave,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ControlPedidoVidriera(
              elegida: cantidad,
              tope: item.stock,
              subtotal: item.precio * cantidad,
              moneda: moneda,
              etiqueta: etiqueta,
              cromo: cromo,
              trazo: TrazoControl.contorno,
              onMenos: () => pedido.onCambiar(item, -1),
              onMas: () => pedido.onCambiar(item, 1),
            ),
          ] else
            VariantesVidriera(
              item: item,
              moneda: moneda,
              cromo: cromo,
              pedido: pedido,
              etiqueta: etiqueta,
              centrado: true,
              trazo: TrazoControl.contorno,
            ),
        ],
      ),
    );
  }
}

class _TarjetaGeneral extends StatelessWidget {
  const _TarjetaGeneral({
    required this.item,
    required this.cromo,
    required this.moneda,
    required this.pedido,
    required this.etiqueta,
  });

  final ItemVidriera item;
  final CromoVidriera cromo;
  final String moneda;
  final PedidoItemVidriera pedido;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final foto = item.fotos.isEmpty ? null : item.fotos.first;
    final cantidad = pedido.cantidadDe(item);
    final descripcion = item.descripcion.trim();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cromo.tarjeta,
        borderRadius: BorderRadius.circular(cromo.radio),
        boxShadow: cromo.oscuro ? null : AppColors.sombraTarjeta,
        border: cromo.oscuro ? Border.all(color: cromo.linea) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FotoVidriera(
            bytes: foto?.bytes,
            url: foto?.url,
            color: cromo.acento,
            inicial: item.inicial,
            alto: 188,
            fondo: cromo.acento.withValues(alpha: 0.08),
            tamanoInicial: 36,
            iconoSiFalta: true,
          ),
          if (item.pieFotos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                item.pieFotos,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cromo.textoSuave, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: item.variantes.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cromo.texto,
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (descripcion.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cromo.textoSuave,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        monedaTienda(item.precio, moneda),
                        style: TextStyle(
                          color: cromo.acento,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.stock <= 0 ? 'Agotado' : 'Stock: ${item.stock}',
                        style: TextStyle(
                          color: item.stock <= 0
                              ? AppColors.alerta
                              : cromo.textoSuave,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ControlPedidoVidriera(
                        elegida: cantidad,
                        tope: item.stock,
                        subtotal: item.precio * cantidad,
                        moneda: moneda,
                        etiqueta: etiqueta,
                        cromo: cromo,
                        onMenos: () => pedido.onCambiar(item, -1),
                        onMas: () => pedido.onCambiar(item, 1),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cromo.texto,
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (descripcion.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cromo.textoSuave,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      VariantesVidriera(
                        item: item,
                        moneda: moneda,
                        cromo: cromo,
                        pedido: pedido,
                        etiqueta: etiqueta,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({
    required this.titulo,
    required this.presentacion,
    required this.cromo,
  });

  final String titulo;
  final PresentacionVidriera presentacion;
  final CromoVidriera cromo;

  @override
  Widget build(BuildContext context) {
    final id = presentacion.plantillaId;
    final centrado = id == 'perfumes' || id == 'cosmeticos';
    final estilo = switch (id) {
      'menu' => TextStyle(
          color: cromo.texto,
          fontSize: 26,
          height: 1.1,
          fontWeight: FontWeight.w900,
        ),
      'tecnologia' => TextStyle(
          color: cromo.textoSuave,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      'ropa' => TextStyle(
          color: cromo.texto,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 2.4,
        ),
      'cosmeticos' => TextStyle(
          color: cromo.texto,
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
      'perfumes' => TextStyle(
          color: cromo.texto,
          fontSize: 13,
          fontWeight: FontWeight.w300,
          letterSpacing: 4,
        ),
      'servicios' => TextStyle(
          color: cromo.texto,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      _ => TextStyle(
          color: cromo.texto,
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w900,
        ),
    };
    final visible = id == 'tecnologia' || id == 'ropa' || id == 'perfumes'
        ? titulo.toUpperCase()
        : titulo;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _margen(id),
        id == 'perfumes' ? 28 : 22,
        _margen(id),
        12,
      ),
      child: Row(
        children: [
          if (id == 'general' || id == 'servicios') ...[
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: cromo.acento,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              visible,
              textAlign: centrado ? TextAlign.center : TextAlign.start,
              style: estilo,
            ),
          ),
        ],
      ),
    );
  }
}

double _menor(ItemVidriera item) {
  var menor = item.precio;
  for (final variante in item.variantes) {
    if (variante.precio < menor) menor = variante.precio;
  }
  return menor;
}

CromoVidriera _cromoRedondo(CromoVidriera cromo) {
  return CromoVidriera(
    oscuro: cromo.oscuro,
    acento: cromo.acento,
    sobreAcento: cromo.sobreAcento,
    fondo: cromo.fondo,
    texto: cromo.texto,
    textoSuave: cromo.textoSuave,
    tarjeta: cromo.tarjeta,
    linea: cromo.linea,
    radio: 28,
  );
}

double _margen(String plantillaId) {
  switch (plantillaId) {
    case 'perfumes':
      return 28;
    case 'ropa':
      return 14;
    default:
      return 18;
  }
}

double _espacio(String plantillaId) {
  switch (plantillaId) {
    case 'menu':
      return 0;
    case 'perfumes':
      return 28;
    case 'ropa':
      return 18;
    case 'cosmeticos':
      return 14;
    case 'tecnologia':
      return 12;
    default:
      return 14;
  }
}
