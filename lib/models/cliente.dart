enum EstadoPago { pendiente, senalado, pagado }

class Cliente {
  final int id;
  final String nombre;
  final String contacto;
  final String? email;
  final bool esPotencial;
  final String? notas;
  final EstadoPago estadoPago;
  final DateTime fechaCreacion;

  Cliente({
    required this.id,
    required this.nombre,
    required this.contacto,
    this.email,
    required this.esPotencial,
    this.notas,
    required this.estadoPago,
    required this.fechaCreacion,
  });

  // Método para crear un nuevo cliente
  static Cliente fromData(Map<String, dynamic> data) {
    final creacion = data['fechaCreacion'];
    return Cliente(
      id: data['id'] as int,
      nombre: (data['nombre'] as String?)?.trim() ?? '',
      contacto: (data['contacto'] as String?)?.trim() ?? '',
      email: data['email'] as String?,
      esPotencial: data['esPotencial'] as bool? ?? false,
      notas: data['notas'] as String?,
      estadoPago: EstadoPago.values.firstWhere(
        (e) => e.toString().split('.').last == data['estadoPago'],
        orElse: () => EstadoPago.pendiente,
      ),
      fechaCreacion: creacion is DateTime
          ? creacion
          : DateTime.tryParse('$creacion') ?? DateTime.now(),
    );
  }

  // Método para crear una copia con cambios
  Cliente copyWith({
    int? id,
    String? nombre,
    String? contacto,
    String? email,
    bool? esPotencial,
    String? notas,
    EstadoPago? estadoPago,
    DateTime? fechaCreacion,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      contacto: contacto ?? this.contacto,
      email: email ?? this.email,
      esPotencial: esPotencial ?? this.esPotencial,
      notas: notas ?? this.notas,
      estadoPago: estadoPago ?? this.estadoPago,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  // Convertir a Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'contacto': contacto,
      'email': email,
      'esPotencial': esPotencial,
      'notas': notas,
      'estadoPago': estadoPago.toString().split('.').last,
      'fechaCreacion': fechaCreacion.toIso8601String(),
    };
  }
}
