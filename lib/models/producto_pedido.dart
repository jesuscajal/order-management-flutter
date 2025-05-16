class ProductoPedido {
  final String nombre;
  final int cantidad;

  ProductoPedido({required this.nombre, required this.cantidad});

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'cantidad': cantidad,
      };

  factory ProductoPedido.fromJson(Map<String, dynamic> json) => ProductoPedido(
        nombre: json['nombre'],
        cantidad: json['cantidad'],
      );
}