enum EstadoPago { pendiente, senalado, pagado }

class Cliente {
  final String id;
  final String nombre;
  final String contacto;
  final String? email;
  final bool esPotencial;
  final String? notas;
  final EstadoPago estadoPago;

  Cliente({
    required this.id,
    required this.nombre,
    required this.contacto,
    this.email,
    required this.esPotencial,
    this.notas,
    required this.estadoPago,
  });

  // Método para crear un ID único
  static String generarId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Método para crear un nuevo cliente
  static Cliente crear({
    required String nombre,
    required String contacto,
    String? email,
    required bool esPotencial,
    String? notas,
    EstadoPago estadoPago = EstadoPago.pendiente,
  }) {
    return Cliente(
      id: generarId(),
      nombre: nombre,
      contacto: contacto,
      email: email,
      esPotencial: esPotencial,
      notas: notas,
      estadoPago: estadoPago,
    );
  }

  // Método para crear una copia con cambios
  Cliente copyWith({
    String? nombre,
    String? contacto,
    String? email,
    bool? esPotencial,
    String? notas,
    EstadoPago? estadoPago,
  }) {
    return Cliente(
      id: id,
      nombre: nombre ?? this.nombre,
      contacto: contacto ?? this.contacto,
      email: email ?? this.email,
      esPotencial: esPotencial ?? this.esPotencial,
      notas: notas ?? this.notas,
      estadoPago: estadoPago ?? this.estadoPago,
    );
  }
}
