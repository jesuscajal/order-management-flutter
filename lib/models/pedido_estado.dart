enum PedidoEstado { pendiente, pagado, entregado }

String pedidoEstadoToString(PedidoEstado estado) {
  switch (estado) {
    case PedidoEstado.pendiente:
      return 'Pendiente';
    case PedidoEstado.pagado:
      return 'Pagado';
    case PedidoEstado.entregado:
      return 'Entregado';
  }
}

PedidoEstado pedidoEstadoFromString(String estado) {
  switch (estado.toLowerCase()) {
    case 'pagado':
      return PedidoEstado.pagado;
    case 'entregado':
      return PedidoEstado.entregado;
    default:
      return PedidoEstado.pendiente;
  }
}