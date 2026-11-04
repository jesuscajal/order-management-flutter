class ProductoPedido {
  final String nombre;
  final int cantidad;
  final double precio;

  const ProductoPedido({
    required this.nombre,
    required this.cantidad,
    this.precio = 0,
  });

  double get subtotal => precio * cantidad;

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'cantidad': cantidad,
        'precio': precio,
      };

  factory ProductoPedido.fromJson(Map<String, dynamic> json) {
    final cantidad = json['cantidad'];
    final precio = json['precio'];
    return ProductoPedido(
      nombre: json['nombre'] as String,
      cantidad: cantidad is int ? cantidad : (cantidad as num).toInt(),
      precio: precio is num ? precio.toDouble() : 0,
    );
  }
}
