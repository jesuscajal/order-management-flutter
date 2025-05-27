// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsuariosTable extends Usuarios with TableInfo<$UsuariosTable, Usuario> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsuariosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
      'nombre', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
      'tipo', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('usuario'));
  @override
  List<GeneratedColumn> get $columns => [id, nombre, tipo];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usuarios';
  @override
  VerificationContext validateIntegrity(Insertable<Usuario> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nombre')) {
      context.handle(_nombreMeta,
          nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta));
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
          _tipoMeta, tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Usuario map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Usuario(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      nombre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nombre'])!,
      tipo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tipo'])!,
    );
  }

  @override
  $UsuariosTable createAlias(String alias) {
    return $UsuariosTable(attachedDatabase, alias);
  }
}

class Usuario extends DataClass implements Insertable<Usuario> {
  final int id;
  final String nombre;
  final String tipo;
  const Usuario({required this.id, required this.nombre, required this.tipo});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nombre'] = Variable<String>(nombre);
    map['tipo'] = Variable<String>(tipo);
    return map;
  }

  UsuariosCompanion toCompanion(bool nullToAbsent) {
    return UsuariosCompanion(
      id: Value(id),
      nombre: Value(nombre),
      tipo: Value(tipo),
    );
  }

  factory Usuario.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Usuario(
      id: serializer.fromJson<int>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      tipo: serializer.fromJson<String>(json['tipo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nombre': serializer.toJson<String>(nombre),
      'tipo': serializer.toJson<String>(tipo),
    };
  }

  Usuario copyWith({int? id, String? nombre, String? tipo}) => Usuario(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        tipo: tipo ?? this.tipo,
      );
  Usuario copyWithCompanion(UsuariosCompanion data) {
    return Usuario(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Usuario(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('tipo: $tipo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, tipo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Usuario &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.tipo == this.tipo);
}

class UsuariosCompanion extends UpdateCompanion<Usuario> {
  final Value<int> id;
  final Value<String> nombre;
  final Value<String> tipo;
  const UsuariosCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.tipo = const Value.absent(),
  });
  UsuariosCompanion.insert({
    this.id = const Value.absent(),
    required String nombre,
    this.tipo = const Value.absent(),
  }) : nombre = Value(nombre);
  static Insertable<Usuario> custom({
    Expression<int>? id,
    Expression<String>? nombre,
    Expression<String>? tipo,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (tipo != null) 'tipo': tipo,
    });
  }

  UsuariosCompanion copyWith(
      {Value<int>? id, Value<String>? nombre, Value<String>? tipo}) {
    return UsuariosCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsuariosCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('tipo: $tipo')
          ..write(')'))
        .toString();
  }
}

class $ClientesTable extends Clientes with TableInfo<$ClientesTable, Cliente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
      'nombre', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contactoMeta =
      const VerificationMeta('contacto');
  @override
  late final GeneratedColumn<String> contacto = GeneratedColumn<String>(
      'contacto', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _esPotencialMeta =
      const VerificationMeta('esPotencial');
  @override
  late final GeneratedColumn<bool> esPotencial = GeneratedColumn<bool>(
      'es_potencial', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("es_potencial" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _notasMeta = const VerificationMeta('notas');
  @override
  late final GeneratedColumn<String> notas = GeneratedColumn<String>(
      'notas', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _estadoPagoMeta =
      const VerificationMeta('estadoPago');
  @override
  late final GeneratedColumn<String> estadoPago = GeneratedColumn<String>(
      'estado_pago', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pendiente'));
  static const VerificationMeta _fechaCreacionMeta =
      const VerificationMeta('fechaCreacion');
  @override
  late final GeneratedColumn<DateTime> fechaCreacion =
      GeneratedColumn<DateTime>('fecha_creacion', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        nombre,
        contacto,
        email,
        esPotencial,
        notas,
        estadoPago,
        fechaCreacion
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clientes';
  @override
  VerificationContext validateIntegrity(Insertable<Cliente> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nombre')) {
      context.handle(_nombreMeta,
          nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta));
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('contacto')) {
      context.handle(_contactoMeta,
          contacto.isAcceptableOrUnknown(data['contacto']!, _contactoMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('es_potencial')) {
      context.handle(
          _esPotencialMeta,
          esPotencial.isAcceptableOrUnknown(
              data['es_potencial']!, _esPotencialMeta));
    }
    if (data.containsKey('notas')) {
      context.handle(
          _notasMeta, notas.isAcceptableOrUnknown(data['notas']!, _notasMeta));
    }
    if (data.containsKey('estado_pago')) {
      context.handle(
          _estadoPagoMeta,
          estadoPago.isAcceptableOrUnknown(
              data['estado_pago']!, _estadoPagoMeta));
    }
    if (data.containsKey('fecha_creacion')) {
      context.handle(
          _fechaCreacionMeta,
          fechaCreacion.isAcceptableOrUnknown(
              data['fecha_creacion']!, _fechaCreacionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cliente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cliente(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      nombre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nombre'])!,
      contacto: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contacto']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      esPotencial: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}es_potencial'])!,
      notas: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notas']),
      estadoPago: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}estado_pago'])!,
      fechaCreacion: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}fecha_creacion'])!,
    );
  }

  @override
  $ClientesTable createAlias(String alias) {
    return $ClientesTable(attachedDatabase, alias);
  }
}

class Cliente extends DataClass implements Insertable<Cliente> {
  final int id;
  final String nombre;
  final String? contacto;
  final String? email;
  final bool esPotencial;
  final String? notas;
  final String estadoPago;
  final DateTime fechaCreacion;
  const Cliente(
      {required this.id,
      required this.nombre,
      this.contacto,
      this.email,
      required this.esPotencial,
      this.notas,
      required this.estadoPago,
      required this.fechaCreacion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nombre'] = Variable<String>(nombre);
    if (!nullToAbsent || contacto != null) {
      map['contacto'] = Variable<String>(contacto);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['es_potencial'] = Variable<bool>(esPotencial);
    if (!nullToAbsent || notas != null) {
      map['notas'] = Variable<String>(notas);
    }
    map['estado_pago'] = Variable<String>(estadoPago);
    map['fecha_creacion'] = Variable<DateTime>(fechaCreacion);
    return map;
  }

  ClientesCompanion toCompanion(bool nullToAbsent) {
    return ClientesCompanion(
      id: Value(id),
      nombre: Value(nombre),
      contacto: contacto == null && nullToAbsent
          ? const Value.absent()
          : Value(contacto),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      esPotencial: Value(esPotencial),
      notas:
          notas == null && nullToAbsent ? const Value.absent() : Value(notas),
      estadoPago: Value(estadoPago),
      fechaCreacion: Value(fechaCreacion),
    );
  }

  factory Cliente.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cliente(
      id: serializer.fromJson<int>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      contacto: serializer.fromJson<String?>(json['contacto']),
      email: serializer.fromJson<String?>(json['email']),
      esPotencial: serializer.fromJson<bool>(json['esPotencial']),
      notas: serializer.fromJson<String?>(json['notas']),
      estadoPago: serializer.fromJson<String>(json['estadoPago']),
      fechaCreacion: serializer.fromJson<DateTime>(json['fechaCreacion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nombre': serializer.toJson<String>(nombre),
      'contacto': serializer.toJson<String?>(contacto),
      'email': serializer.toJson<String?>(email),
      'esPotencial': serializer.toJson<bool>(esPotencial),
      'notas': serializer.toJson<String?>(notas),
      'estadoPago': serializer.toJson<String>(estadoPago),
      'fechaCreacion': serializer.toJson<DateTime>(fechaCreacion),
    };
  }

  Cliente copyWith(
          {int? id,
          String? nombre,
          Value<String?> contacto = const Value.absent(),
          Value<String?> email = const Value.absent(),
          bool? esPotencial,
          Value<String?> notas = const Value.absent(),
          String? estadoPago,
          DateTime? fechaCreacion}) =>
      Cliente(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        contacto: contacto.present ? contacto.value : this.contacto,
        email: email.present ? email.value : this.email,
        esPotencial: esPotencial ?? this.esPotencial,
        notas: notas.present ? notas.value : this.notas,
        estadoPago: estadoPago ?? this.estadoPago,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      );
  Cliente copyWithCompanion(ClientesCompanion data) {
    return Cliente(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      contacto: data.contacto.present ? data.contacto.value : this.contacto,
      email: data.email.present ? data.email.value : this.email,
      esPotencial:
          data.esPotencial.present ? data.esPotencial.value : this.esPotencial,
      notas: data.notas.present ? data.notas.value : this.notas,
      estadoPago:
          data.estadoPago.present ? data.estadoPago.value : this.estadoPago,
      fechaCreacion: data.fechaCreacion.present
          ? data.fechaCreacion.value
          : this.fechaCreacion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cliente(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('contacto: $contacto, ')
          ..write('email: $email, ')
          ..write('esPotencial: $esPotencial, ')
          ..write('notas: $notas, ')
          ..write('estadoPago: $estadoPago, ')
          ..write('fechaCreacion: $fechaCreacion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, contacto, email, esPotencial,
      notas, estadoPago, fechaCreacion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cliente &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.contacto == this.contacto &&
          other.email == this.email &&
          other.esPotencial == this.esPotencial &&
          other.notas == this.notas &&
          other.estadoPago == this.estadoPago &&
          other.fechaCreacion == this.fechaCreacion);
}

class ClientesCompanion extends UpdateCompanion<Cliente> {
  final Value<int> id;
  final Value<String> nombre;
  final Value<String?> contacto;
  final Value<String?> email;
  final Value<bool> esPotencial;
  final Value<String?> notas;
  final Value<String> estadoPago;
  final Value<DateTime> fechaCreacion;
  const ClientesCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.contacto = const Value.absent(),
    this.email = const Value.absent(),
    this.esPotencial = const Value.absent(),
    this.notas = const Value.absent(),
    this.estadoPago = const Value.absent(),
    this.fechaCreacion = const Value.absent(),
  });
  ClientesCompanion.insert({
    this.id = const Value.absent(),
    required String nombre,
    this.contacto = const Value.absent(),
    this.email = const Value.absent(),
    this.esPotencial = const Value.absent(),
    this.notas = const Value.absent(),
    this.estadoPago = const Value.absent(),
    this.fechaCreacion = const Value.absent(),
  }) : nombre = Value(nombre);
  static Insertable<Cliente> custom({
    Expression<int>? id,
    Expression<String>? nombre,
    Expression<String>? contacto,
    Expression<String>? email,
    Expression<bool>? esPotencial,
    Expression<String>? notas,
    Expression<String>? estadoPago,
    Expression<DateTime>? fechaCreacion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (contacto != null) 'contacto': contacto,
      if (email != null) 'email': email,
      if (esPotencial != null) 'es_potencial': esPotencial,
      if (notas != null) 'notas': notas,
      if (estadoPago != null) 'estado_pago': estadoPago,
      if (fechaCreacion != null) 'fecha_creacion': fechaCreacion,
    });
  }

  ClientesCompanion copyWith(
      {Value<int>? id,
      Value<String>? nombre,
      Value<String?>? contacto,
      Value<String?>? email,
      Value<bool>? esPotencial,
      Value<String?>? notas,
      Value<String>? estadoPago,
      Value<DateTime>? fechaCreacion}) {
    return ClientesCompanion(
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

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (contacto.present) {
      map['contacto'] = Variable<String>(contacto.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (esPotencial.present) {
      map['es_potencial'] = Variable<bool>(esPotencial.value);
    }
    if (notas.present) {
      map['notas'] = Variable<String>(notas.value);
    }
    if (estadoPago.present) {
      map['estado_pago'] = Variable<String>(estadoPago.value);
    }
    if (fechaCreacion.present) {
      map['fecha_creacion'] = Variable<DateTime>(fechaCreacion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientesCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('contacto: $contacto, ')
          ..write('email: $email, ')
          ..write('esPotencial: $esPotencial, ')
          ..write('notas: $notas, ')
          ..write('estadoPago: $estadoPago, ')
          ..write('fechaCreacion: $fechaCreacion')
          ..write(')'))
        .toString();
  }
}

class $ProductosTable extends Productos
    with TableInfo<$ProductosTable, Producto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
      'nombre', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _precioCompraMeta =
      const VerificationMeta('precioCompra');
  @override
  late final GeneratedColumn<double> precioCompra = GeneratedColumn<double>(
      'precio_compra', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _precioVentaMeta =
      const VerificationMeta('precioVenta');
  @override
  late final GeneratedColumn<double> precioVenta = GeneratedColumn<double>(
      'precio_venta', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _fechaCreacionMeta =
      const VerificationMeta('fechaCreacion');
  @override
  late final GeneratedColumn<DateTime> fechaCreacion =
      GeneratedColumn<DateTime>('fecha_creacion', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, nombre, precioCompra, precioVenta, fechaCreacion];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'productos';
  @override
  VerificationContext validateIntegrity(Insertable<Producto> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nombre')) {
      context.handle(_nombreMeta,
          nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta));
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('precio_compra')) {
      context.handle(
          _precioCompraMeta,
          precioCompra.isAcceptableOrUnknown(
              data['precio_compra']!, _precioCompraMeta));
    }
    if (data.containsKey('precio_venta')) {
      context.handle(
          _precioVentaMeta,
          precioVenta.isAcceptableOrUnknown(
              data['precio_venta']!, _precioVentaMeta));
    }
    if (data.containsKey('fecha_creacion')) {
      context.handle(
          _fechaCreacionMeta,
          fechaCreacion.isAcceptableOrUnknown(
              data['fecha_creacion']!, _fechaCreacionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Producto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Producto(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      nombre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nombre'])!,
      precioCompra: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}precio_compra'])!,
      precioVenta: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}precio_venta'])!,
      fechaCreacion: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}fecha_creacion'])!,
    );
  }

  @override
  $ProductosTable createAlias(String alias) {
    return $ProductosTable(attachedDatabase, alias);
  }
}

class Producto extends DataClass implements Insertable<Producto> {
  final int id;
  final String nombre;
  final double precioCompra;
  final double precioVenta;
  final DateTime fechaCreacion;
  const Producto(
      {required this.id,
      required this.nombre,
      required this.precioCompra,
      required this.precioVenta,
      required this.fechaCreacion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nombre'] = Variable<String>(nombre);
    map['precio_compra'] = Variable<double>(precioCompra);
    map['precio_venta'] = Variable<double>(precioVenta);
    map['fecha_creacion'] = Variable<DateTime>(fechaCreacion);
    return map;
  }

  ProductosCompanion toCompanion(bool nullToAbsent) {
    return ProductosCompanion(
      id: Value(id),
      nombre: Value(nombre),
      precioCompra: Value(precioCompra),
      precioVenta: Value(precioVenta),
      fechaCreacion: Value(fechaCreacion),
    );
  }

  factory Producto.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Producto(
      id: serializer.fromJson<int>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      precioCompra: serializer.fromJson<double>(json['precioCompra']),
      precioVenta: serializer.fromJson<double>(json['precioVenta']),
      fechaCreacion: serializer.fromJson<DateTime>(json['fechaCreacion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nombre': serializer.toJson<String>(nombre),
      'precioCompra': serializer.toJson<double>(precioCompra),
      'precioVenta': serializer.toJson<double>(precioVenta),
      'fechaCreacion': serializer.toJson<DateTime>(fechaCreacion),
    };
  }

  Producto copyWith(
          {int? id,
          String? nombre,
          double? precioCompra,
          double? precioVenta,
          DateTime? fechaCreacion}) =>
      Producto(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        precioCompra: precioCompra ?? this.precioCompra,
        precioVenta: precioVenta ?? this.precioVenta,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      );
  Producto copyWithCompanion(ProductosCompanion data) {
    return Producto(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      precioCompra: data.precioCompra.present
          ? data.precioCompra.value
          : this.precioCompra,
      precioVenta:
          data.precioVenta.present ? data.precioVenta.value : this.precioVenta,
      fechaCreacion: data.fechaCreacion.present
          ? data.fechaCreacion.value
          : this.fechaCreacion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Producto(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('precioCompra: $precioCompra, ')
          ..write('precioVenta: $precioVenta, ')
          ..write('fechaCreacion: $fechaCreacion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, nombre, precioCompra, precioVenta, fechaCreacion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Producto &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.precioCompra == this.precioCompra &&
          other.precioVenta == this.precioVenta &&
          other.fechaCreacion == this.fechaCreacion);
}

class ProductosCompanion extends UpdateCompanion<Producto> {
  final Value<int> id;
  final Value<String> nombre;
  final Value<double> precioCompra;
  final Value<double> precioVenta;
  final Value<DateTime> fechaCreacion;
  const ProductosCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.precioCompra = const Value.absent(),
    this.precioVenta = const Value.absent(),
    this.fechaCreacion = const Value.absent(),
  });
  ProductosCompanion.insert({
    this.id = const Value.absent(),
    required String nombre,
    this.precioCompra = const Value.absent(),
    this.precioVenta = const Value.absent(),
    this.fechaCreacion = const Value.absent(),
  }) : nombre = Value(nombre);
  static Insertable<Producto> custom({
    Expression<int>? id,
    Expression<String>? nombre,
    Expression<double>? precioCompra,
    Expression<double>? precioVenta,
    Expression<DateTime>? fechaCreacion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (precioCompra != null) 'precio_compra': precioCompra,
      if (precioVenta != null) 'precio_venta': precioVenta,
      if (fechaCreacion != null) 'fecha_creacion': fechaCreacion,
    });
  }

  ProductosCompanion copyWith(
      {Value<int>? id,
      Value<String>? nombre,
      Value<double>? precioCompra,
      Value<double>? precioVenta,
      Value<DateTime>? fechaCreacion}) {
    return ProductosCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precioCompra: precioCompra ?? this.precioCompra,
      precioVenta: precioVenta ?? this.precioVenta,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (precioCompra.present) {
      map['precio_compra'] = Variable<double>(precioCompra.value);
    }
    if (precioVenta.present) {
      map['precio_venta'] = Variable<double>(precioVenta.value);
    }
    if (fechaCreacion.present) {
      map['fecha_creacion'] = Variable<DateTime>(fechaCreacion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductosCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('precioCompra: $precioCompra, ')
          ..write('precioVenta: $precioVenta, ')
          ..write('fechaCreacion: $fechaCreacion')
          ..write(')'))
        .toString();
  }
}

class $StockTable extends Stock with TableInfo<$StockTable, StockData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _productoIdMeta =
      const VerificationMeta('productoId');
  @override
  late final GeneratedColumn<int> productoId = GeneratedColumn<int>(
      'producto_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES productos (id)'));
  static const VerificationMeta _usuarioIdMeta =
      const VerificationMeta('usuarioId');
  @override
  late final GeneratedColumn<int> usuarioId = GeneratedColumn<int>(
      'usuario_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES usuarios (id)'));
  static const VerificationMeta _cantidadActualMeta =
      const VerificationMeta('cantidadActual');
  @override
  late final GeneratedColumn<int> cantidadActual = GeneratedColumn<int>(
      'cantidad_actual', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, productoId, usuarioId, cantidadActual];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock';
  @override
  VerificationContext validateIntegrity(Insertable<StockData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('producto_id')) {
      context.handle(
          _productoIdMeta,
          productoId.isAcceptableOrUnknown(
              data['producto_id']!, _productoIdMeta));
    } else if (isInserting) {
      context.missing(_productoIdMeta);
    }
    if (data.containsKey('usuario_id')) {
      context.handle(_usuarioIdMeta,
          usuarioId.isAcceptableOrUnknown(data['usuario_id']!, _usuarioIdMeta));
    } else if (isInserting) {
      context.missing(_usuarioIdMeta);
    }
    if (data.containsKey('cantidad_actual')) {
      context.handle(
          _cantidadActualMeta,
          cantidadActual.isAcceptableOrUnknown(
              data['cantidad_actual']!, _cantidadActualMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      productoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}producto_id'])!,
      usuarioId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}usuario_id'])!,
      cantidadActual: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cantidad_actual'])!,
    );
  }

  @override
  $StockTable createAlias(String alias) {
    return $StockTable(attachedDatabase, alias);
  }
}

class StockData extends DataClass implements Insertable<StockData> {
  final int id;
  final int productoId;
  final int usuarioId;
  final int cantidadActual;
  const StockData(
      {required this.id,
      required this.productoId,
      required this.usuarioId,
      required this.cantidadActual});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['producto_id'] = Variable<int>(productoId);
    map['usuario_id'] = Variable<int>(usuarioId);
    map['cantidad_actual'] = Variable<int>(cantidadActual);
    return map;
  }

  StockCompanion toCompanion(bool nullToAbsent) {
    return StockCompanion(
      id: Value(id),
      productoId: Value(productoId),
      usuarioId: Value(usuarioId),
      cantidadActual: Value(cantidadActual),
    );
  }

  factory StockData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockData(
      id: serializer.fromJson<int>(json['id']),
      productoId: serializer.fromJson<int>(json['productoId']),
      usuarioId: serializer.fromJson<int>(json['usuarioId']),
      cantidadActual: serializer.fromJson<int>(json['cantidadActual']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productoId': serializer.toJson<int>(productoId),
      'usuarioId': serializer.toJson<int>(usuarioId),
      'cantidadActual': serializer.toJson<int>(cantidadActual),
    };
  }

  StockData copyWith(
          {int? id, int? productoId, int? usuarioId, int? cantidadActual}) =>
      StockData(
        id: id ?? this.id,
        productoId: productoId ?? this.productoId,
        usuarioId: usuarioId ?? this.usuarioId,
        cantidadActual: cantidadActual ?? this.cantidadActual,
      );
  StockData copyWithCompanion(StockCompanion data) {
    return StockData(
      id: data.id.present ? data.id.value : this.id,
      productoId:
          data.productoId.present ? data.productoId.value : this.productoId,
      usuarioId: data.usuarioId.present ? data.usuarioId.value : this.usuarioId,
      cantidadActual: data.cantidadActual.present
          ? data.cantidadActual.value
          : this.cantidadActual,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockData(')
          ..write('id: $id, ')
          ..write('productoId: $productoId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('cantidadActual: $cantidadActual')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productoId, usuarioId, cantidadActual);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockData &&
          other.id == this.id &&
          other.productoId == this.productoId &&
          other.usuarioId == this.usuarioId &&
          other.cantidadActual == this.cantidadActual);
}

class StockCompanion extends UpdateCompanion<StockData> {
  final Value<int> id;
  final Value<int> productoId;
  final Value<int> usuarioId;
  final Value<int> cantidadActual;
  const StockCompanion({
    this.id = const Value.absent(),
    this.productoId = const Value.absent(),
    this.usuarioId = const Value.absent(),
    this.cantidadActual = const Value.absent(),
  });
  StockCompanion.insert({
    this.id = const Value.absent(),
    required int productoId,
    required int usuarioId,
    this.cantidadActual = const Value.absent(),
  })  : productoId = Value(productoId),
        usuarioId = Value(usuarioId);
  static Insertable<StockData> custom({
    Expression<int>? id,
    Expression<int>? productoId,
    Expression<int>? usuarioId,
    Expression<int>? cantidadActual,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productoId != null) 'producto_id': productoId,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (cantidadActual != null) 'cantidad_actual': cantidadActual,
    });
  }

  StockCompanion copyWith(
      {Value<int>? id,
      Value<int>? productoId,
      Value<int>? usuarioId,
      Value<int>? cantidadActual}) {
    return StockCompanion(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      usuarioId: usuarioId ?? this.usuarioId,
      cantidadActual: cantidadActual ?? this.cantidadActual,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productoId.present) {
      map['producto_id'] = Variable<int>(productoId.value);
    }
    if (usuarioId.present) {
      map['usuario_id'] = Variable<int>(usuarioId.value);
    }
    if (cantidadActual.present) {
      map['cantidad_actual'] = Variable<int>(cantidadActual.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockCompanion(')
          ..write('id: $id, ')
          ..write('productoId: $productoId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('cantidadActual: $cantidadActual')
          ..write(')'))
        .toString();
  }
}

class $MovimientosStockTable extends MovimientosStock
    with TableInfo<$MovimientosStockTable, MovimientosStockData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MovimientosStockTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _productoIdMeta =
      const VerificationMeta('productoId');
  @override
  late final GeneratedColumn<int> productoId = GeneratedColumn<int>(
      'producto_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES productos (id)'));
  static const VerificationMeta _usuarioIdMeta =
      const VerificationMeta('usuarioId');
  @override
  late final GeneratedColumn<int> usuarioId = GeneratedColumn<int>(
      'usuario_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES usuarios (id)'));
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
      'tipo', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cantidadMeta =
      const VerificationMeta('cantidad');
  @override
  late final GeneratedColumn<int> cantidad = GeneratedColumn<int>(
      'cantidad', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _descripcionMeta =
      const VerificationMeta('descripcion');
  @override
  late final GeneratedColumn<String> descripcion = GeneratedColumn<String>(
      'descripcion', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fechaCargaMeta =
      const VerificationMeta('fechaCarga');
  @override
  late final GeneratedColumn<DateTime> fechaCarga = GeneratedColumn<DateTime>(
      'fecha_carga', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _fechaSalidaMeta =
      const VerificationMeta('fechaSalida');
  @override
  late final GeneratedColumn<DateTime> fechaSalida = GeneratedColumn<DateTime>(
      'fecha_salida', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        productoId,
        usuarioId,
        tipo,
        cantidad,
        descripcion,
        fechaCarga,
        fechaSalida
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movimientos_stock';
  @override
  VerificationContext validateIntegrity(
      Insertable<MovimientosStockData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('producto_id')) {
      context.handle(
          _productoIdMeta,
          productoId.isAcceptableOrUnknown(
              data['producto_id']!, _productoIdMeta));
    } else if (isInserting) {
      context.missing(_productoIdMeta);
    }
    if (data.containsKey('usuario_id')) {
      context.handle(_usuarioIdMeta,
          usuarioId.isAcceptableOrUnknown(data['usuario_id']!, _usuarioIdMeta));
    } else if (isInserting) {
      context.missing(_usuarioIdMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
          _tipoMeta, tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta));
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('cantidad')) {
      context.handle(_cantidadMeta,
          cantidad.isAcceptableOrUnknown(data['cantidad']!, _cantidadMeta));
    } else if (isInserting) {
      context.missing(_cantidadMeta);
    }
    if (data.containsKey('descripcion')) {
      context.handle(
          _descripcionMeta,
          descripcion.isAcceptableOrUnknown(
              data['descripcion']!, _descripcionMeta));
    }
    if (data.containsKey('fecha_carga')) {
      context.handle(
          _fechaCargaMeta,
          fechaCarga.isAcceptableOrUnknown(
              data['fecha_carga']!, _fechaCargaMeta));
    }
    if (data.containsKey('fecha_salida')) {
      context.handle(
          _fechaSalidaMeta,
          fechaSalida.isAcceptableOrUnknown(
              data['fecha_salida']!, _fechaSalidaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MovimientosStockData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MovimientosStockData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      productoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}producto_id'])!,
      usuarioId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}usuario_id'])!,
      tipo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tipo'])!,
      cantidad: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cantidad'])!,
      descripcion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}descripcion']),
      fechaCarga: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fecha_carga'])!,
      fechaSalida: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fecha_salida']),
    );
  }

  @override
  $MovimientosStockTable createAlias(String alias) {
    return $MovimientosStockTable(attachedDatabase, alias);
  }
}

class MovimientosStockData extends DataClass
    implements Insertable<MovimientosStockData> {
  final int id;
  final int productoId;
  final int usuarioId;
  final String tipo;
  final int cantidad;
  final String? descripcion;
  final DateTime fechaCarga;
  final DateTime? fechaSalida;
  const MovimientosStockData(
      {required this.id,
      required this.productoId,
      required this.usuarioId,
      required this.tipo,
      required this.cantidad,
      this.descripcion,
      required this.fechaCarga,
      this.fechaSalida});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['producto_id'] = Variable<int>(productoId);
    map['usuario_id'] = Variable<int>(usuarioId);
    map['tipo'] = Variable<String>(tipo);
    map['cantidad'] = Variable<int>(cantidad);
    if (!nullToAbsent || descripcion != null) {
      map['descripcion'] = Variable<String>(descripcion);
    }
    map['fecha_carga'] = Variable<DateTime>(fechaCarga);
    if (!nullToAbsent || fechaSalida != null) {
      map['fecha_salida'] = Variable<DateTime>(fechaSalida);
    }
    return map;
  }

  MovimientosStockCompanion toCompanion(bool nullToAbsent) {
    return MovimientosStockCompanion(
      id: Value(id),
      productoId: Value(productoId),
      usuarioId: Value(usuarioId),
      tipo: Value(tipo),
      cantidad: Value(cantidad),
      descripcion: descripcion == null && nullToAbsent
          ? const Value.absent()
          : Value(descripcion),
      fechaCarga: Value(fechaCarga),
      fechaSalida: fechaSalida == null && nullToAbsent
          ? const Value.absent()
          : Value(fechaSalida),
    );
  }

  factory MovimientosStockData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MovimientosStockData(
      id: serializer.fromJson<int>(json['id']),
      productoId: serializer.fromJson<int>(json['productoId']),
      usuarioId: serializer.fromJson<int>(json['usuarioId']),
      tipo: serializer.fromJson<String>(json['tipo']),
      cantidad: serializer.fromJson<int>(json['cantidad']),
      descripcion: serializer.fromJson<String?>(json['descripcion']),
      fechaCarga: serializer.fromJson<DateTime>(json['fechaCarga']),
      fechaSalida: serializer.fromJson<DateTime?>(json['fechaSalida']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productoId': serializer.toJson<int>(productoId),
      'usuarioId': serializer.toJson<int>(usuarioId),
      'tipo': serializer.toJson<String>(tipo),
      'cantidad': serializer.toJson<int>(cantidad),
      'descripcion': serializer.toJson<String?>(descripcion),
      'fechaCarga': serializer.toJson<DateTime>(fechaCarga),
      'fechaSalida': serializer.toJson<DateTime?>(fechaSalida),
    };
  }

  MovimientosStockData copyWith(
          {int? id,
          int? productoId,
          int? usuarioId,
          String? tipo,
          int? cantidad,
          Value<String?> descripcion = const Value.absent(),
          DateTime? fechaCarga,
          Value<DateTime?> fechaSalida = const Value.absent()}) =>
      MovimientosStockData(
        id: id ?? this.id,
        productoId: productoId ?? this.productoId,
        usuarioId: usuarioId ?? this.usuarioId,
        tipo: tipo ?? this.tipo,
        cantidad: cantidad ?? this.cantidad,
        descripcion: descripcion.present ? descripcion.value : this.descripcion,
        fechaCarga: fechaCarga ?? this.fechaCarga,
        fechaSalida: fechaSalida.present ? fechaSalida.value : this.fechaSalida,
      );
  MovimientosStockData copyWithCompanion(MovimientosStockCompanion data) {
    return MovimientosStockData(
      id: data.id.present ? data.id.value : this.id,
      productoId:
          data.productoId.present ? data.productoId.value : this.productoId,
      usuarioId: data.usuarioId.present ? data.usuarioId.value : this.usuarioId,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      cantidad: data.cantidad.present ? data.cantidad.value : this.cantidad,
      descripcion:
          data.descripcion.present ? data.descripcion.value : this.descripcion,
      fechaCarga:
          data.fechaCarga.present ? data.fechaCarga.value : this.fechaCarga,
      fechaSalida:
          data.fechaSalida.present ? data.fechaSalida.value : this.fechaSalida,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MovimientosStockData(')
          ..write('id: $id, ')
          ..write('productoId: $productoId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('tipo: $tipo, ')
          ..write('cantidad: $cantidad, ')
          ..write('descripcion: $descripcion, ')
          ..write('fechaCarga: $fechaCarga, ')
          ..write('fechaSalida: $fechaSalida')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productoId, usuarioId, tipo, cantidad,
      descripcion, fechaCarga, fechaSalida);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovimientosStockData &&
          other.id == this.id &&
          other.productoId == this.productoId &&
          other.usuarioId == this.usuarioId &&
          other.tipo == this.tipo &&
          other.cantidad == this.cantidad &&
          other.descripcion == this.descripcion &&
          other.fechaCarga == this.fechaCarga &&
          other.fechaSalida == this.fechaSalida);
}

class MovimientosStockCompanion extends UpdateCompanion<MovimientosStockData> {
  final Value<int> id;
  final Value<int> productoId;
  final Value<int> usuarioId;
  final Value<String> tipo;
  final Value<int> cantidad;
  final Value<String?> descripcion;
  final Value<DateTime> fechaCarga;
  final Value<DateTime?> fechaSalida;
  const MovimientosStockCompanion({
    this.id = const Value.absent(),
    this.productoId = const Value.absent(),
    this.usuarioId = const Value.absent(),
    this.tipo = const Value.absent(),
    this.cantidad = const Value.absent(),
    this.descripcion = const Value.absent(),
    this.fechaCarga = const Value.absent(),
    this.fechaSalida = const Value.absent(),
  });
  MovimientosStockCompanion.insert({
    this.id = const Value.absent(),
    required int productoId,
    required int usuarioId,
    required String tipo,
    required int cantidad,
    this.descripcion = const Value.absent(),
    this.fechaCarga = const Value.absent(),
    this.fechaSalida = const Value.absent(),
  })  : productoId = Value(productoId),
        usuarioId = Value(usuarioId),
        tipo = Value(tipo),
        cantidad = Value(cantidad);
  static Insertable<MovimientosStockData> custom({
    Expression<int>? id,
    Expression<int>? productoId,
    Expression<int>? usuarioId,
    Expression<String>? tipo,
    Expression<int>? cantidad,
    Expression<String>? descripcion,
    Expression<DateTime>? fechaCarga,
    Expression<DateTime>? fechaSalida,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productoId != null) 'producto_id': productoId,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (tipo != null) 'tipo': tipo,
      if (cantidad != null) 'cantidad': cantidad,
      if (descripcion != null) 'descripcion': descripcion,
      if (fechaCarga != null) 'fecha_carga': fechaCarga,
      if (fechaSalida != null) 'fecha_salida': fechaSalida,
    });
  }

  MovimientosStockCompanion copyWith(
      {Value<int>? id,
      Value<int>? productoId,
      Value<int>? usuarioId,
      Value<String>? tipo,
      Value<int>? cantidad,
      Value<String?>? descripcion,
      Value<DateTime>? fechaCarga,
      Value<DateTime?>? fechaSalida}) {
    return MovimientosStockCompanion(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      usuarioId: usuarioId ?? this.usuarioId,
      tipo: tipo ?? this.tipo,
      cantidad: cantidad ?? this.cantidad,
      descripcion: descripcion ?? this.descripcion,
      fechaCarga: fechaCarga ?? this.fechaCarga,
      fechaSalida: fechaSalida ?? this.fechaSalida,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productoId.present) {
      map['producto_id'] = Variable<int>(productoId.value);
    }
    if (usuarioId.present) {
      map['usuario_id'] = Variable<int>(usuarioId.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (cantidad.present) {
      map['cantidad'] = Variable<int>(cantidad.value);
    }
    if (descripcion.present) {
      map['descripcion'] = Variable<String>(descripcion.value);
    }
    if (fechaCarga.present) {
      map['fecha_carga'] = Variable<DateTime>(fechaCarga.value);
    }
    if (fechaSalida.present) {
      map['fecha_salida'] = Variable<DateTime>(fechaSalida.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MovimientosStockCompanion(')
          ..write('id: $id, ')
          ..write('productoId: $productoId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('tipo: $tipo, ')
          ..write('cantidad: $cantidad, ')
          ..write('descripcion: $descripcion, ')
          ..write('fechaCarga: $fechaCarga, ')
          ..write('fechaSalida: $fechaSalida')
          ..write(')'))
        .toString();
  }
}

class $PedidosTable extends Pedidos with TableInfo<$PedidosTable, Pedido> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PedidosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _clienteIdMeta =
      const VerificationMeta('clienteId');
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
      'cliente_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES clientes (id)'));
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<DateTime> fecha = GeneratedColumn<DateTime>(
      'fecha', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
      'estado', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pendiente'));
  static const VerificationMeta _montoSenadoMeta =
      const VerificationMeta('montoSenado');
  @override
  late final GeneratedColumn<double> montoSenado = GeneratedColumn<double>(
      'monto_senado', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, clienteId, fecha, estado, montoSenado];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pedidos';
  @override
  VerificationContext validateIntegrity(Insertable<Pedido> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cliente_id')) {
      context.handle(_clienteIdMeta,
          clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta));
    } else if (isInserting) {
      context.missing(_clienteIdMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
          _fechaMeta, fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta));
    }
    if (data.containsKey('estado')) {
      context.handle(_estadoMeta,
          estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta));
    }
    if (data.containsKey('monto_senado')) {
      context.handle(
          _montoSenadoMeta,
          montoSenado.isAcceptableOrUnknown(
              data['monto_senado']!, _montoSenadoMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pedido map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pedido(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      clienteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cliente_id'])!,
      fecha: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fecha'])!,
      estado: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}estado'])!,
      montoSenado: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}monto_senado'])!,
    );
  }

  @override
  $PedidosTable createAlias(String alias) {
    return $PedidosTable(attachedDatabase, alias);
  }
}

class Pedido extends DataClass implements Insertable<Pedido> {
  final int id;
  final int clienteId;
  final DateTime fecha;
  final String estado;
  final double montoSenado;
  const Pedido(
      {required this.id,
      required this.clienteId,
      required this.fecha,
      required this.estado,
      required this.montoSenado});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cliente_id'] = Variable<int>(clienteId);
    map['fecha'] = Variable<DateTime>(fecha);
    map['estado'] = Variable<String>(estado);
    map['monto_senado'] = Variable<double>(montoSenado);
    return map;
  }

  PedidosCompanion toCompanion(bool nullToAbsent) {
    return PedidosCompanion(
      id: Value(id),
      clienteId: Value(clienteId),
      fecha: Value(fecha),
      estado: Value(estado),
      montoSenado: Value(montoSenado),
    );
  }

  factory Pedido.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pedido(
      id: serializer.fromJson<int>(json['id']),
      clienteId: serializer.fromJson<int>(json['clienteId']),
      fecha: serializer.fromJson<DateTime>(json['fecha']),
      estado: serializer.fromJson<String>(json['estado']),
      montoSenado: serializer.fromJson<double>(json['montoSenado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clienteId': serializer.toJson<int>(clienteId),
      'fecha': serializer.toJson<DateTime>(fecha),
      'estado': serializer.toJson<String>(estado),
      'montoSenado': serializer.toJson<double>(montoSenado),
    };
  }

  Pedido copyWith(
          {int? id,
          int? clienteId,
          DateTime? fecha,
          String? estado,
          double? montoSenado}) =>
      Pedido(
        id: id ?? this.id,
        clienteId: clienteId ?? this.clienteId,
        fecha: fecha ?? this.fecha,
        estado: estado ?? this.estado,
        montoSenado: montoSenado ?? this.montoSenado,
      );
  Pedido copyWithCompanion(PedidosCompanion data) {
    return Pedido(
      id: data.id.present ? data.id.value : this.id,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      estado: data.estado.present ? data.estado.value : this.estado,
      montoSenado:
          data.montoSenado.present ? data.montoSenado.value : this.montoSenado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pedido(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('fecha: $fecha, ')
          ..write('estado: $estado, ')
          ..write('montoSenado: $montoSenado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, clienteId, fecha, estado, montoSenado);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pedido &&
          other.id == this.id &&
          other.clienteId == this.clienteId &&
          other.fecha == this.fecha &&
          other.estado == this.estado &&
          other.montoSenado == this.montoSenado);
}

class PedidosCompanion extends UpdateCompanion<Pedido> {
  final Value<int> id;
  final Value<int> clienteId;
  final Value<DateTime> fecha;
  final Value<String> estado;
  final Value<double> montoSenado;
  const PedidosCompanion({
    this.id = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.fecha = const Value.absent(),
    this.estado = const Value.absent(),
    this.montoSenado = const Value.absent(),
  });
  PedidosCompanion.insert({
    this.id = const Value.absent(),
    required int clienteId,
    this.fecha = const Value.absent(),
    this.estado = const Value.absent(),
    this.montoSenado = const Value.absent(),
  }) : clienteId = Value(clienteId);
  static Insertable<Pedido> custom({
    Expression<int>? id,
    Expression<int>? clienteId,
    Expression<DateTime>? fecha,
    Expression<String>? estado,
    Expression<double>? montoSenado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clienteId != null) 'cliente_id': clienteId,
      if (fecha != null) 'fecha': fecha,
      if (estado != null) 'estado': estado,
      if (montoSenado != null) 'monto_senado': montoSenado,
    });
  }

  PedidosCompanion copyWith(
      {Value<int>? id,
      Value<int>? clienteId,
      Value<DateTime>? fecha,
      Value<String>? estado,
      Value<double>? montoSenado}) {
    return PedidosCompanion(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      fecha: fecha ?? this.fecha,
      estado: estado ?? this.estado,
      montoSenado: montoSenado ?? this.montoSenado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<DateTime>(fecha.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (montoSenado.present) {
      map['monto_senado'] = Variable<double>(montoSenado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PedidosCompanion(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('fecha: $fecha, ')
          ..write('estado: $estado, ')
          ..write('montoSenado: $montoSenado')
          ..write(')'))
        .toString();
  }
}

class $ProductosPedidoTable extends ProductosPedido
    with TableInfo<$ProductosPedidoTable, ProductosPedidoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductosPedidoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _pedidoIdMeta =
      const VerificationMeta('pedidoId');
  @override
  late final GeneratedColumn<int> pedidoId = GeneratedColumn<int>(
      'pedido_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pedidos (id)'));
  static const VerificationMeta _productoIdMeta =
      const VerificationMeta('productoId');
  @override
  late final GeneratedColumn<int> productoId = GeneratedColumn<int>(
      'producto_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES productos (id)'));
  static const VerificationMeta _cantidadMeta =
      const VerificationMeta('cantidad');
  @override
  late final GeneratedColumn<int> cantidad = GeneratedColumn<int>(
      'cantidad', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, pedidoId, productoId, cantidad];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'productos_pedido';
  @override
  VerificationContext validateIntegrity(
      Insertable<ProductosPedidoData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pedido_id')) {
      context.handle(_pedidoIdMeta,
          pedidoId.isAcceptableOrUnknown(data['pedido_id']!, _pedidoIdMeta));
    } else if (isInserting) {
      context.missing(_pedidoIdMeta);
    }
    if (data.containsKey('producto_id')) {
      context.handle(
          _productoIdMeta,
          productoId.isAcceptableOrUnknown(
              data['producto_id']!, _productoIdMeta));
    } else if (isInserting) {
      context.missing(_productoIdMeta);
    }
    if (data.containsKey('cantidad')) {
      context.handle(_cantidadMeta,
          cantidad.isAcceptableOrUnknown(data['cantidad']!, _cantidadMeta));
    } else if (isInserting) {
      context.missing(_cantidadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductosPedidoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductosPedidoData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      pedidoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pedido_id'])!,
      productoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}producto_id'])!,
      cantidad: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cantidad'])!,
    );
  }

  @override
  $ProductosPedidoTable createAlias(String alias) {
    return $ProductosPedidoTable(attachedDatabase, alias);
  }
}

class ProductosPedidoData extends DataClass
    implements Insertable<ProductosPedidoData> {
  final int id;
  final int pedidoId;
  final int productoId;
  final int cantidad;
  const ProductosPedidoData(
      {required this.id,
      required this.pedidoId,
      required this.productoId,
      required this.cantidad});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pedido_id'] = Variable<int>(pedidoId);
    map['producto_id'] = Variable<int>(productoId);
    map['cantidad'] = Variable<int>(cantidad);
    return map;
  }

  ProductosPedidoCompanion toCompanion(bool nullToAbsent) {
    return ProductosPedidoCompanion(
      id: Value(id),
      pedidoId: Value(pedidoId),
      productoId: Value(productoId),
      cantidad: Value(cantidad),
    );
  }

  factory ProductosPedidoData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductosPedidoData(
      id: serializer.fromJson<int>(json['id']),
      pedidoId: serializer.fromJson<int>(json['pedidoId']),
      productoId: serializer.fromJson<int>(json['productoId']),
      cantidad: serializer.fromJson<int>(json['cantidad']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pedidoId': serializer.toJson<int>(pedidoId),
      'productoId': serializer.toJson<int>(productoId),
      'cantidad': serializer.toJson<int>(cantidad),
    };
  }

  ProductosPedidoData copyWith(
          {int? id, int? pedidoId, int? productoId, int? cantidad}) =>
      ProductosPedidoData(
        id: id ?? this.id,
        pedidoId: pedidoId ?? this.pedidoId,
        productoId: productoId ?? this.productoId,
        cantidad: cantidad ?? this.cantidad,
      );
  ProductosPedidoData copyWithCompanion(ProductosPedidoCompanion data) {
    return ProductosPedidoData(
      id: data.id.present ? data.id.value : this.id,
      pedidoId: data.pedidoId.present ? data.pedidoId.value : this.pedidoId,
      productoId:
          data.productoId.present ? data.productoId.value : this.productoId,
      cantidad: data.cantidad.present ? data.cantidad.value : this.cantidad,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductosPedidoData(')
          ..write('id: $id, ')
          ..write('pedidoId: $pedidoId, ')
          ..write('productoId: $productoId, ')
          ..write('cantidad: $cantidad')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pedidoId, productoId, cantidad);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductosPedidoData &&
          other.id == this.id &&
          other.pedidoId == this.pedidoId &&
          other.productoId == this.productoId &&
          other.cantidad == this.cantidad);
}

class ProductosPedidoCompanion extends UpdateCompanion<ProductosPedidoData> {
  final Value<int> id;
  final Value<int> pedidoId;
  final Value<int> productoId;
  final Value<int> cantidad;
  const ProductosPedidoCompanion({
    this.id = const Value.absent(),
    this.pedidoId = const Value.absent(),
    this.productoId = const Value.absent(),
    this.cantidad = const Value.absent(),
  });
  ProductosPedidoCompanion.insert({
    this.id = const Value.absent(),
    required int pedidoId,
    required int productoId,
    required int cantidad,
  })  : pedidoId = Value(pedidoId),
        productoId = Value(productoId),
        cantidad = Value(cantidad);
  static Insertable<ProductosPedidoData> custom({
    Expression<int>? id,
    Expression<int>? pedidoId,
    Expression<int>? productoId,
    Expression<int>? cantidad,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pedidoId != null) 'pedido_id': pedidoId,
      if (productoId != null) 'producto_id': productoId,
      if (cantidad != null) 'cantidad': cantidad,
    });
  }

  ProductosPedidoCompanion copyWith(
      {Value<int>? id,
      Value<int>? pedidoId,
      Value<int>? productoId,
      Value<int>? cantidad}) {
    return ProductosPedidoCompanion(
      id: id ?? this.id,
      pedidoId: pedidoId ?? this.pedidoId,
      productoId: productoId ?? this.productoId,
      cantidad: cantidad ?? this.cantidad,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pedidoId.present) {
      map['pedido_id'] = Variable<int>(pedidoId.value);
    }
    if (productoId.present) {
      map['producto_id'] = Variable<int>(productoId.value);
    }
    if (cantidad.present) {
      map['cantidad'] = Variable<int>(cantidad.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductosPedidoCompanion(')
          ..write('id: $id, ')
          ..write('pedidoId: $pedidoId, ')
          ..write('productoId: $productoId, ')
          ..write('cantidad: $cantidad')
          ..write(')'))
        .toString();
  }
}

class $HistorialPedidosTable extends HistorialPedidos
    with TableInfo<$HistorialPedidosTable, HistorialPedido> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistorialPedidosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _pedidoIdMeta =
      const VerificationMeta('pedidoId');
  @override
  late final GeneratedColumn<int> pedidoId = GeneratedColumn<int>(
      'pedido_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES pedidos (id)'));
  static const VerificationMeta _estadoAnteriorMeta =
      const VerificationMeta('estadoAnterior');
  @override
  late final GeneratedColumn<String> estadoAnterior = GeneratedColumn<String>(
      'estado_anterior', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _estadoNuevoMeta =
      const VerificationMeta('estadoNuevo');
  @override
  late final GeneratedColumn<String> estadoNuevo = GeneratedColumn<String>(
      'estado_nuevo', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fechaCambioMeta =
      const VerificationMeta('fechaCambio');
  @override
  late final GeneratedColumn<DateTime> fechaCambio = GeneratedColumn<DateTime>(
      'fecha_cambio', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, pedidoId, estadoAnterior, estadoNuevo, fechaCambio];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'historial_pedidos';
  @override
  VerificationContext validateIntegrity(Insertable<HistorialPedido> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pedido_id')) {
      context.handle(_pedidoIdMeta,
          pedidoId.isAcceptableOrUnknown(data['pedido_id']!, _pedidoIdMeta));
    } else if (isInserting) {
      context.missing(_pedidoIdMeta);
    }
    if (data.containsKey('estado_anterior')) {
      context.handle(
          _estadoAnteriorMeta,
          estadoAnterior.isAcceptableOrUnknown(
              data['estado_anterior']!, _estadoAnteriorMeta));
    } else if (isInserting) {
      context.missing(_estadoAnteriorMeta);
    }
    if (data.containsKey('estado_nuevo')) {
      context.handle(
          _estadoNuevoMeta,
          estadoNuevo.isAcceptableOrUnknown(
              data['estado_nuevo']!, _estadoNuevoMeta));
    } else if (isInserting) {
      context.missing(_estadoNuevoMeta);
    }
    if (data.containsKey('fecha_cambio')) {
      context.handle(
          _fechaCambioMeta,
          fechaCambio.isAcceptableOrUnknown(
              data['fecha_cambio']!, _fechaCambioMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistorialPedido map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistorialPedido(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      pedidoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pedido_id'])!,
      estadoAnterior: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}estado_anterior'])!,
      estadoNuevo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}estado_nuevo'])!,
      fechaCambio: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fecha_cambio'])!,
    );
  }

  @override
  $HistorialPedidosTable createAlias(String alias) {
    return $HistorialPedidosTable(attachedDatabase, alias);
  }
}

class HistorialPedido extends DataClass implements Insertable<HistorialPedido> {
  final int id;
  final int pedidoId;
  final String estadoAnterior;
  final String estadoNuevo;
  final DateTime fechaCambio;
  const HistorialPedido(
      {required this.id,
      required this.pedidoId,
      required this.estadoAnterior,
      required this.estadoNuevo,
      required this.fechaCambio});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pedido_id'] = Variable<int>(pedidoId);
    map['estado_anterior'] = Variable<String>(estadoAnterior);
    map['estado_nuevo'] = Variable<String>(estadoNuevo);
    map['fecha_cambio'] = Variable<DateTime>(fechaCambio);
    return map;
  }

  HistorialPedidosCompanion toCompanion(bool nullToAbsent) {
    return HistorialPedidosCompanion(
      id: Value(id),
      pedidoId: Value(pedidoId),
      estadoAnterior: Value(estadoAnterior),
      estadoNuevo: Value(estadoNuevo),
      fechaCambio: Value(fechaCambio),
    );
  }

  factory HistorialPedido.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistorialPedido(
      id: serializer.fromJson<int>(json['id']),
      pedidoId: serializer.fromJson<int>(json['pedidoId']),
      estadoAnterior: serializer.fromJson<String>(json['estadoAnterior']),
      estadoNuevo: serializer.fromJson<String>(json['estadoNuevo']),
      fechaCambio: serializer.fromJson<DateTime>(json['fechaCambio']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pedidoId': serializer.toJson<int>(pedidoId),
      'estadoAnterior': serializer.toJson<String>(estadoAnterior),
      'estadoNuevo': serializer.toJson<String>(estadoNuevo),
      'fechaCambio': serializer.toJson<DateTime>(fechaCambio),
    };
  }

  HistorialPedido copyWith(
          {int? id,
          int? pedidoId,
          String? estadoAnterior,
          String? estadoNuevo,
          DateTime? fechaCambio}) =>
      HistorialPedido(
        id: id ?? this.id,
        pedidoId: pedidoId ?? this.pedidoId,
        estadoAnterior: estadoAnterior ?? this.estadoAnterior,
        estadoNuevo: estadoNuevo ?? this.estadoNuevo,
        fechaCambio: fechaCambio ?? this.fechaCambio,
      );
  HistorialPedido copyWithCompanion(HistorialPedidosCompanion data) {
    return HistorialPedido(
      id: data.id.present ? data.id.value : this.id,
      pedidoId: data.pedidoId.present ? data.pedidoId.value : this.pedidoId,
      estadoAnterior: data.estadoAnterior.present
          ? data.estadoAnterior.value
          : this.estadoAnterior,
      estadoNuevo:
          data.estadoNuevo.present ? data.estadoNuevo.value : this.estadoNuevo,
      fechaCambio:
          data.fechaCambio.present ? data.fechaCambio.value : this.fechaCambio,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistorialPedido(')
          ..write('id: $id, ')
          ..write('pedidoId: $pedidoId, ')
          ..write('estadoAnterior: $estadoAnterior, ')
          ..write('estadoNuevo: $estadoNuevo, ')
          ..write('fechaCambio: $fechaCambio')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, pedidoId, estadoAnterior, estadoNuevo, fechaCambio);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistorialPedido &&
          other.id == this.id &&
          other.pedidoId == this.pedidoId &&
          other.estadoAnterior == this.estadoAnterior &&
          other.estadoNuevo == this.estadoNuevo &&
          other.fechaCambio == this.fechaCambio);
}

class HistorialPedidosCompanion extends UpdateCompanion<HistorialPedido> {
  final Value<int> id;
  final Value<int> pedidoId;
  final Value<String> estadoAnterior;
  final Value<String> estadoNuevo;
  final Value<DateTime> fechaCambio;
  const HistorialPedidosCompanion({
    this.id = const Value.absent(),
    this.pedidoId = const Value.absent(),
    this.estadoAnterior = const Value.absent(),
    this.estadoNuevo = const Value.absent(),
    this.fechaCambio = const Value.absent(),
  });
  HistorialPedidosCompanion.insert({
    this.id = const Value.absent(),
    required int pedidoId,
    required String estadoAnterior,
    required String estadoNuevo,
    this.fechaCambio = const Value.absent(),
  })  : pedidoId = Value(pedidoId),
        estadoAnterior = Value(estadoAnterior),
        estadoNuevo = Value(estadoNuevo);
  static Insertable<HistorialPedido> custom({
    Expression<int>? id,
    Expression<int>? pedidoId,
    Expression<String>? estadoAnterior,
    Expression<String>? estadoNuevo,
    Expression<DateTime>? fechaCambio,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pedidoId != null) 'pedido_id': pedidoId,
      if (estadoAnterior != null) 'estado_anterior': estadoAnterior,
      if (estadoNuevo != null) 'estado_nuevo': estadoNuevo,
      if (fechaCambio != null) 'fecha_cambio': fechaCambio,
    });
  }

  HistorialPedidosCompanion copyWith(
      {Value<int>? id,
      Value<int>? pedidoId,
      Value<String>? estadoAnterior,
      Value<String>? estadoNuevo,
      Value<DateTime>? fechaCambio}) {
    return HistorialPedidosCompanion(
      id: id ?? this.id,
      pedidoId: pedidoId ?? this.pedidoId,
      estadoAnterior: estadoAnterior ?? this.estadoAnterior,
      estadoNuevo: estadoNuevo ?? this.estadoNuevo,
      fechaCambio: fechaCambio ?? this.fechaCambio,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pedidoId.present) {
      map['pedido_id'] = Variable<int>(pedidoId.value);
    }
    if (estadoAnterior.present) {
      map['estado_anterior'] = Variable<String>(estadoAnterior.value);
    }
    if (estadoNuevo.present) {
      map['estado_nuevo'] = Variable<String>(estadoNuevo.value);
    }
    if (fechaCambio.present) {
      map['fecha_cambio'] = Variable<DateTime>(fechaCambio.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistorialPedidosCompanion(')
          ..write('id: $id, ')
          ..write('pedidoId: $pedidoId, ')
          ..write('estadoAnterior: $estadoAnterior, ')
          ..write('estadoNuevo: $estadoNuevo, ')
          ..write('fechaCambio: $fechaCambio')
          ..write(')'))
        .toString();
  }
}

class $HistorialClientesTable extends HistorialClientes
    with TableInfo<$HistorialClientesTable, HistorialCliente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistorialClientesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _clienteIdMeta =
      const VerificationMeta('clienteId');
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
      'cliente_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES clientes (id)'));
  static const VerificationMeta _estadoAnteriorMeta =
      const VerificationMeta('estadoAnterior');
  @override
  late final GeneratedColumn<String> estadoAnterior = GeneratedColumn<String>(
      'estado_anterior', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _estadoNuevoMeta =
      const VerificationMeta('estadoNuevo');
  @override
  late final GeneratedColumn<String> estadoNuevo = GeneratedColumn<String>(
      'estado_nuevo', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fechaCambioMeta =
      const VerificationMeta('fechaCambio');
  @override
  late final GeneratedColumn<DateTime> fechaCambio = GeneratedColumn<DateTime>(
      'fecha_cambio', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, clienteId, estadoAnterior, estadoNuevo, fechaCambio];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'historial_clientes';
  @override
  VerificationContext validateIntegrity(Insertable<HistorialCliente> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cliente_id')) {
      context.handle(_clienteIdMeta,
          clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta));
    } else if (isInserting) {
      context.missing(_clienteIdMeta);
    }
    if (data.containsKey('estado_anterior')) {
      context.handle(
          _estadoAnteriorMeta,
          estadoAnterior.isAcceptableOrUnknown(
              data['estado_anterior']!, _estadoAnteriorMeta));
    } else if (isInserting) {
      context.missing(_estadoAnteriorMeta);
    }
    if (data.containsKey('estado_nuevo')) {
      context.handle(
          _estadoNuevoMeta,
          estadoNuevo.isAcceptableOrUnknown(
              data['estado_nuevo']!, _estadoNuevoMeta));
    } else if (isInserting) {
      context.missing(_estadoNuevoMeta);
    }
    if (data.containsKey('fecha_cambio')) {
      context.handle(
          _fechaCambioMeta,
          fechaCambio.isAcceptableOrUnknown(
              data['fecha_cambio']!, _fechaCambioMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistorialCliente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistorialCliente(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      clienteId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cliente_id'])!,
      estadoAnterior: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}estado_anterior'])!,
      estadoNuevo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}estado_nuevo'])!,
      fechaCambio: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fecha_cambio'])!,
    );
  }

  @override
  $HistorialClientesTable createAlias(String alias) {
    return $HistorialClientesTable(attachedDatabase, alias);
  }
}

class HistorialCliente extends DataClass
    implements Insertable<HistorialCliente> {
  final int id;
  final int clienteId;
  final String estadoAnterior;
  final String estadoNuevo;
  final DateTime fechaCambio;
  const HistorialCliente(
      {required this.id,
      required this.clienteId,
      required this.estadoAnterior,
      required this.estadoNuevo,
      required this.fechaCambio});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cliente_id'] = Variable<int>(clienteId);
    map['estado_anterior'] = Variable<String>(estadoAnterior);
    map['estado_nuevo'] = Variable<String>(estadoNuevo);
    map['fecha_cambio'] = Variable<DateTime>(fechaCambio);
    return map;
  }

  HistorialClientesCompanion toCompanion(bool nullToAbsent) {
    return HistorialClientesCompanion(
      id: Value(id),
      clienteId: Value(clienteId),
      estadoAnterior: Value(estadoAnterior),
      estadoNuevo: Value(estadoNuevo),
      fechaCambio: Value(fechaCambio),
    );
  }

  factory HistorialCliente.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistorialCliente(
      id: serializer.fromJson<int>(json['id']),
      clienteId: serializer.fromJson<int>(json['clienteId']),
      estadoAnterior: serializer.fromJson<String>(json['estadoAnterior']),
      estadoNuevo: serializer.fromJson<String>(json['estadoNuevo']),
      fechaCambio: serializer.fromJson<DateTime>(json['fechaCambio']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clienteId': serializer.toJson<int>(clienteId),
      'estadoAnterior': serializer.toJson<String>(estadoAnterior),
      'estadoNuevo': serializer.toJson<String>(estadoNuevo),
      'fechaCambio': serializer.toJson<DateTime>(fechaCambio),
    };
  }

  HistorialCliente copyWith(
          {int? id,
          int? clienteId,
          String? estadoAnterior,
          String? estadoNuevo,
          DateTime? fechaCambio}) =>
      HistorialCliente(
        id: id ?? this.id,
        clienteId: clienteId ?? this.clienteId,
        estadoAnterior: estadoAnterior ?? this.estadoAnterior,
        estadoNuevo: estadoNuevo ?? this.estadoNuevo,
        fechaCambio: fechaCambio ?? this.fechaCambio,
      );
  HistorialCliente copyWithCompanion(HistorialClientesCompanion data) {
    return HistorialCliente(
      id: data.id.present ? data.id.value : this.id,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      estadoAnterior: data.estadoAnterior.present
          ? data.estadoAnterior.value
          : this.estadoAnterior,
      estadoNuevo:
          data.estadoNuevo.present ? data.estadoNuevo.value : this.estadoNuevo,
      fechaCambio:
          data.fechaCambio.present ? data.fechaCambio.value : this.fechaCambio,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistorialCliente(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('estadoAnterior: $estadoAnterior, ')
          ..write('estadoNuevo: $estadoNuevo, ')
          ..write('fechaCambio: $fechaCambio')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, clienteId, estadoAnterior, estadoNuevo, fechaCambio);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistorialCliente &&
          other.id == this.id &&
          other.clienteId == this.clienteId &&
          other.estadoAnterior == this.estadoAnterior &&
          other.estadoNuevo == this.estadoNuevo &&
          other.fechaCambio == this.fechaCambio);
}

class HistorialClientesCompanion extends UpdateCompanion<HistorialCliente> {
  final Value<int> id;
  final Value<int> clienteId;
  final Value<String> estadoAnterior;
  final Value<String> estadoNuevo;
  final Value<DateTime> fechaCambio;
  const HistorialClientesCompanion({
    this.id = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.estadoAnterior = const Value.absent(),
    this.estadoNuevo = const Value.absent(),
    this.fechaCambio = const Value.absent(),
  });
  HistorialClientesCompanion.insert({
    this.id = const Value.absent(),
    required int clienteId,
    required String estadoAnterior,
    required String estadoNuevo,
    this.fechaCambio = const Value.absent(),
  })  : clienteId = Value(clienteId),
        estadoAnterior = Value(estadoAnterior),
        estadoNuevo = Value(estadoNuevo);
  static Insertable<HistorialCliente> custom({
    Expression<int>? id,
    Expression<int>? clienteId,
    Expression<String>? estadoAnterior,
    Expression<String>? estadoNuevo,
    Expression<DateTime>? fechaCambio,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clienteId != null) 'cliente_id': clienteId,
      if (estadoAnterior != null) 'estado_anterior': estadoAnterior,
      if (estadoNuevo != null) 'estado_nuevo': estadoNuevo,
      if (fechaCambio != null) 'fecha_cambio': fechaCambio,
    });
  }

  HistorialClientesCompanion copyWith(
      {Value<int>? id,
      Value<int>? clienteId,
      Value<String>? estadoAnterior,
      Value<String>? estadoNuevo,
      Value<DateTime>? fechaCambio}) {
    return HistorialClientesCompanion(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      estadoAnterior: estadoAnterior ?? this.estadoAnterior,
      estadoNuevo: estadoNuevo ?? this.estadoNuevo,
      fechaCambio: fechaCambio ?? this.fechaCambio,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (estadoAnterior.present) {
      map['estado_anterior'] = Variable<String>(estadoAnterior.value);
    }
    if (estadoNuevo.present) {
      map['estado_nuevo'] = Variable<String>(estadoNuevo.value);
    }
    if (fechaCambio.present) {
      map['fecha_cambio'] = Variable<DateTime>(fechaCambio.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistorialClientesCompanion(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('estadoAnterior: $estadoAnterior, ')
          ..write('estadoNuevo: $estadoNuevo, ')
          ..write('fechaCambio: $fechaCambio')
          ..write(')'))
        .toString();
  }
}

class $MovimientosCapitalTable extends MovimientosCapital
    with TableInfo<$MovimientosCapitalTable, MovimientosCapitalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MovimientosCapitalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _personaMeta =
      const VerificationMeta('persona');
  @override
  late final GeneratedColumn<String> persona = GeneratedColumn<String>(
      'persona', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _montoMeta = const VerificationMeta('monto');
  @override
  late final GeneratedColumn<double> monto = GeneratedColumn<double>(
      'monto', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
      'tipo', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descripcionMeta =
      const VerificationMeta('descripcion');
  @override
  late final GeneratedColumn<String> descripcion = GeneratedColumn<String>(
      'descripcion', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<DateTime> fecha = GeneratedColumn<DateTime>(
      'fecha', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, persona, monto, tipo, descripcion, fecha];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movimientos_capital';
  @override
  VerificationContext validateIntegrity(
      Insertable<MovimientosCapitalData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('persona')) {
      context.handle(_personaMeta,
          persona.isAcceptableOrUnknown(data['persona']!, _personaMeta));
    } else if (isInserting) {
      context.missing(_personaMeta);
    }
    if (data.containsKey('monto')) {
      context.handle(
          _montoMeta, monto.isAcceptableOrUnknown(data['monto']!, _montoMeta));
    } else if (isInserting) {
      context.missing(_montoMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
          _tipoMeta, tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta));
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('descripcion')) {
      context.handle(
          _descripcionMeta,
          descripcion.isAcceptableOrUnknown(
              data['descripcion']!, _descripcionMeta));
    }
    if (data.containsKey('fecha')) {
      context.handle(
          _fechaMeta, fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MovimientosCapitalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MovimientosCapitalData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      persona: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}persona'])!,
      monto: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}monto'])!,
      tipo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tipo'])!,
      descripcion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}descripcion']),
      fecha: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fecha'])!,
    );
  }

  @override
  $MovimientosCapitalTable createAlias(String alias) {
    return $MovimientosCapitalTable(attachedDatabase, alias);
  }
}

class MovimientosCapitalData extends DataClass
    implements Insertable<MovimientosCapitalData> {
  final int id;
  final String persona;
  final double monto;
  final String tipo;
  final String? descripcion;
  final DateTime fecha;
  const MovimientosCapitalData(
      {required this.id,
      required this.persona,
      required this.monto,
      required this.tipo,
      this.descripcion,
      required this.fecha});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['persona'] = Variable<String>(persona);
    map['monto'] = Variable<double>(monto);
    map['tipo'] = Variable<String>(tipo);
    if (!nullToAbsent || descripcion != null) {
      map['descripcion'] = Variable<String>(descripcion);
    }
    map['fecha'] = Variable<DateTime>(fecha);
    return map;
  }

  MovimientosCapitalCompanion toCompanion(bool nullToAbsent) {
    return MovimientosCapitalCompanion(
      id: Value(id),
      persona: Value(persona),
      monto: Value(monto),
      tipo: Value(tipo),
      descripcion: descripcion == null && nullToAbsent
          ? const Value.absent()
          : Value(descripcion),
      fecha: Value(fecha),
    );
  }

  factory MovimientosCapitalData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MovimientosCapitalData(
      id: serializer.fromJson<int>(json['id']),
      persona: serializer.fromJson<String>(json['persona']),
      monto: serializer.fromJson<double>(json['monto']),
      tipo: serializer.fromJson<String>(json['tipo']),
      descripcion: serializer.fromJson<String?>(json['descripcion']),
      fecha: serializer.fromJson<DateTime>(json['fecha']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'persona': serializer.toJson<String>(persona),
      'monto': serializer.toJson<double>(monto),
      'tipo': serializer.toJson<String>(tipo),
      'descripcion': serializer.toJson<String?>(descripcion),
      'fecha': serializer.toJson<DateTime>(fecha),
    };
  }

  MovimientosCapitalData copyWith(
          {int? id,
          String? persona,
          double? monto,
          String? tipo,
          Value<String?> descripcion = const Value.absent(),
          DateTime? fecha}) =>
      MovimientosCapitalData(
        id: id ?? this.id,
        persona: persona ?? this.persona,
        monto: monto ?? this.monto,
        tipo: tipo ?? this.tipo,
        descripcion: descripcion.present ? descripcion.value : this.descripcion,
        fecha: fecha ?? this.fecha,
      );
  MovimientosCapitalData copyWithCompanion(MovimientosCapitalCompanion data) {
    return MovimientosCapitalData(
      id: data.id.present ? data.id.value : this.id,
      persona: data.persona.present ? data.persona.value : this.persona,
      monto: data.monto.present ? data.monto.value : this.monto,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      descripcion:
          data.descripcion.present ? data.descripcion.value : this.descripcion,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MovimientosCapitalData(')
          ..write('id: $id, ')
          ..write('persona: $persona, ')
          ..write('monto: $monto, ')
          ..write('tipo: $tipo, ')
          ..write('descripcion: $descripcion, ')
          ..write('fecha: $fecha')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, persona, monto, tipo, descripcion, fecha);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovimientosCapitalData &&
          other.id == this.id &&
          other.persona == this.persona &&
          other.monto == this.monto &&
          other.tipo == this.tipo &&
          other.descripcion == this.descripcion &&
          other.fecha == this.fecha);
}

class MovimientosCapitalCompanion
    extends UpdateCompanion<MovimientosCapitalData> {
  final Value<int> id;
  final Value<String> persona;
  final Value<double> monto;
  final Value<String> tipo;
  final Value<String?> descripcion;
  final Value<DateTime> fecha;
  const MovimientosCapitalCompanion({
    this.id = const Value.absent(),
    this.persona = const Value.absent(),
    this.monto = const Value.absent(),
    this.tipo = const Value.absent(),
    this.descripcion = const Value.absent(),
    this.fecha = const Value.absent(),
  });
  MovimientosCapitalCompanion.insert({
    this.id = const Value.absent(),
    required String persona,
    required double monto,
    required String tipo,
    this.descripcion = const Value.absent(),
    this.fecha = const Value.absent(),
  })  : persona = Value(persona),
        monto = Value(monto),
        tipo = Value(tipo);
  static Insertable<MovimientosCapitalData> custom({
    Expression<int>? id,
    Expression<String>? persona,
    Expression<double>? monto,
    Expression<String>? tipo,
    Expression<String>? descripcion,
    Expression<DateTime>? fecha,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (persona != null) 'persona': persona,
      if (monto != null) 'monto': monto,
      if (tipo != null) 'tipo': tipo,
      if (descripcion != null) 'descripcion': descripcion,
      if (fecha != null) 'fecha': fecha,
    });
  }

  MovimientosCapitalCompanion copyWith(
      {Value<int>? id,
      Value<String>? persona,
      Value<double>? monto,
      Value<String>? tipo,
      Value<String?>? descripcion,
      Value<DateTime>? fecha}) {
    return MovimientosCapitalCompanion(
      id: id ?? this.id,
      persona: persona ?? this.persona,
      monto: monto ?? this.monto,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (persona.present) {
      map['persona'] = Variable<String>(persona.value);
    }
    if (monto.present) {
      map['monto'] = Variable<double>(monto.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (descripcion.present) {
      map['descripcion'] = Variable<String>(descripcion.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<DateTime>(fecha.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MovimientosCapitalCompanion(')
          ..write('id: $id, ')
          ..write('persona: $persona, ')
          ..write('monto: $monto, ')
          ..write('tipo: $tipo, ')
          ..write('descripcion: $descripcion, ')
          ..write('fecha: $fecha')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsuariosTable usuarios = $UsuariosTable(this);
  late final $ClientesTable clientes = $ClientesTable(this);
  late final $ProductosTable productos = $ProductosTable(this);
  late final $StockTable stock = $StockTable(this);
  late final $MovimientosStockTable movimientosStock =
      $MovimientosStockTable(this);
  late final $PedidosTable pedidos = $PedidosTable(this);
  late final $ProductosPedidoTable productosPedido =
      $ProductosPedidoTable(this);
  late final $HistorialPedidosTable historialPedidos =
      $HistorialPedidosTable(this);
  late final $HistorialClientesTable historialClientes =
      $HistorialClientesTable(this);
  late final $MovimientosCapitalTable movimientosCapital =
      $MovimientosCapitalTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        usuarios,
        clientes,
        productos,
        stock,
        movimientosStock,
        pedidos,
        productosPedido,
        historialPedidos,
        historialClientes,
        movimientosCapital
      ];
}

typedef $$UsuariosTableCreateCompanionBuilder = UsuariosCompanion Function({
  Value<int> id,
  required String nombre,
  Value<String> tipo,
});
typedef $$UsuariosTableUpdateCompanionBuilder = UsuariosCompanion Function({
  Value<int> id,
  Value<String> nombre,
  Value<String> tipo,
});

final class $$UsuariosTableReferences
    extends BaseReferences<_$AppDatabase, $UsuariosTable, Usuario> {
  $$UsuariosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StockTable, List<StockData>> _stockRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.stock,
          aliasName: $_aliasNameGenerator(db.usuarios.id, db.stock.usuarioId));

  $$StockTableProcessedTableManager get stockRefs {
    final manager = $$StockTableTableManager($_db, $_db.stock)
        .filter((f) => f.usuarioId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$MovimientosStockTable, List<MovimientosStockData>>
      _movimientosStockRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.movimientosStock,
              aliasName: $_aliasNameGenerator(
                  db.usuarios.id, db.movimientosStock.usuarioId));

  $$MovimientosStockTableProcessedTableManager get movimientosStockRefs {
    final manager =
        $$MovimientosStockTableTableManager($_db, $_db.movimientosStock)
            .filter((f) => f.usuarioId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_movimientosStockRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$UsuariosTableFilterComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nombre => $composableBuilder(
      column: $table.nombre, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tipo => $composableBuilder(
      column: $table.tipo, builder: (column) => ColumnFilters(column));

  Expression<bool> stockRefs(
      Expression<bool> Function($$StockTableFilterComposer f) f) {
    final $$StockTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stock,
        getReferencedColumn: (t) => t.usuarioId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockTableFilterComposer(
              $db: $db,
              $table: $db.stock,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> movimientosStockRefs(
      Expression<bool> Function($$MovimientosStockTableFilterComposer f) f) {
    final $$MovimientosStockTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movimientosStock,
        getReferencedColumn: (t) => t.usuarioId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovimientosStockTableFilterComposer(
              $db: $db,
              $table: $db.movimientosStock,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsuariosTableOrderingComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nombre => $composableBuilder(
      column: $table.nombre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tipo => $composableBuilder(
      column: $table.tipo, builder: (column) => ColumnOrderings(column));
}

class $$UsuariosTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsuariosTable> {
  $$UsuariosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  Expression<T> stockRefs<T extends Object>(
      Expression<T> Function($$StockTableAnnotationComposer a) f) {
    final $$StockTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stock,
        getReferencedColumn: (t) => t.usuarioId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockTableAnnotationComposer(
              $db: $db,
              $table: $db.stock,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> movimientosStockRefs<T extends Object>(
      Expression<T> Function($$MovimientosStockTableAnnotationComposer a) f) {
    final $$MovimientosStockTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movimientosStock,
        getReferencedColumn: (t) => t.usuarioId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovimientosStockTableAnnotationComposer(
              $db: $db,
              $table: $db.movimientosStock,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$UsuariosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsuariosTable,
    Usuario,
    $$UsuariosTableFilterComposer,
    $$UsuariosTableOrderingComposer,
    $$UsuariosTableAnnotationComposer,
    $$UsuariosTableCreateCompanionBuilder,
    $$UsuariosTableUpdateCompanionBuilder,
    (Usuario, $$UsuariosTableReferences),
    Usuario,
    PrefetchHooks Function({bool stockRefs, bool movimientosStockRefs})> {
  $$UsuariosTableTableManager(_$AppDatabase db, $UsuariosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsuariosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsuariosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsuariosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> nombre = const Value.absent(),
            Value<String> tipo = const Value.absent(),
          }) =>
              UsuariosCompanion(
            id: id,
            nombre: nombre,
            tipo: tipo,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String nombre,
            Value<String> tipo = const Value.absent(),
          }) =>
              UsuariosCompanion.insert(
            id: id,
            nombre: nombre,
            tipo: tipo,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$UsuariosTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {stockRefs = false, movimientosStockRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (stockRefs) db.stock,
                if (movimientosStockRefs) db.movimientosStock
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (stockRefs)
                    await $_getPrefetchedData<Usuario, $UsuariosTable,
                            StockData>(
                        currentTable: table,
                        referencedTable:
                            $$UsuariosTableReferences._stockRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$UsuariosTableReferences(db, table, p0).stockRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.usuarioId == item.id),
                        typedResults: items),
                  if (movimientosStockRefs)
                    await $_getPrefetchedData<Usuario, $UsuariosTable,
                            MovimientosStockData>(
                        currentTable: table,
                        referencedTable: $$UsuariosTableReferences
                            ._movimientosStockRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$UsuariosTableReferences(db, table, p0)
                                .movimientosStockRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.usuarioId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$UsuariosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsuariosTable,
    Usuario,
    $$UsuariosTableFilterComposer,
    $$UsuariosTableOrderingComposer,
    $$UsuariosTableAnnotationComposer,
    $$UsuariosTableCreateCompanionBuilder,
    $$UsuariosTableUpdateCompanionBuilder,
    (Usuario, $$UsuariosTableReferences),
    Usuario,
    PrefetchHooks Function({bool stockRefs, bool movimientosStockRefs})>;
typedef $$ClientesTableCreateCompanionBuilder = ClientesCompanion Function({
  Value<int> id,
  required String nombre,
  Value<String?> contacto,
  Value<String?> email,
  Value<bool> esPotencial,
  Value<String?> notas,
  Value<String> estadoPago,
  Value<DateTime> fechaCreacion,
});
typedef $$ClientesTableUpdateCompanionBuilder = ClientesCompanion Function({
  Value<int> id,
  Value<String> nombre,
  Value<String?> contacto,
  Value<String?> email,
  Value<bool> esPotencial,
  Value<String?> notas,
  Value<String> estadoPago,
  Value<DateTime> fechaCreacion,
});

final class $$ClientesTableReferences
    extends BaseReferences<_$AppDatabase, $ClientesTable, Cliente> {
  $$ClientesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PedidosTable, List<Pedido>> _pedidosRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.pedidos,
          aliasName:
              $_aliasNameGenerator(db.clientes.id, db.pedidos.clienteId));

  $$PedidosTableProcessedTableManager get pedidosRefs {
    final manager = $$PedidosTableTableManager($_db, $_db.pedidos)
        .filter((f) => f.clienteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pedidosRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$HistorialClientesTable, List<HistorialCliente>>
      _historialClientesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.historialClientes,
              aliasName: $_aliasNameGenerator(
                  db.clientes.id, db.historialClientes.clienteId));

  $$HistorialClientesTableProcessedTableManager get historialClientesRefs {
    final manager =
        $$HistorialClientesTableTableManager($_db, $_db.historialClientes)
            .filter((f) => f.clienteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_historialClientesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ClientesTableFilterComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nombre => $composableBuilder(
      column: $table.nombre, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contacto => $composableBuilder(
      column: $table.contacto, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get esPotencial => $composableBuilder(
      column: $table.esPotencial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notas => $composableBuilder(
      column: $table.notas, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estadoPago => $composableBuilder(
      column: $table.estadoPago, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fechaCreacion => $composableBuilder(
      column: $table.fechaCreacion, builder: (column) => ColumnFilters(column));

  Expression<bool> pedidosRefs(
      Expression<bool> Function($$PedidosTableFilterComposer f) f) {
    final $$PedidosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.pedidos,
        getReferencedColumn: (t) => t.clienteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PedidosTableFilterComposer(
              $db: $db,
              $table: $db.pedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> historialClientesRefs(
      Expression<bool> Function($$HistorialClientesTableFilterComposer f) f) {
    final $$HistorialClientesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.historialClientes,
        getReferencedColumn: (t) => t.clienteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HistorialClientesTableFilterComposer(
              $db: $db,
              $table: $db.historialClientes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ClientesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nombre => $composableBuilder(
      column: $table.nombre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contacto => $composableBuilder(
      column: $table.contacto, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get esPotencial => $composableBuilder(
      column: $table.esPotencial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notas => $composableBuilder(
      column: $table.notas, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estadoPago => $composableBuilder(
      column: $table.estadoPago, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fechaCreacion => $composableBuilder(
      column: $table.fechaCreacion,
      builder: (column) => ColumnOrderings(column));
}

class $$ClientesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get contacto =>
      $composableBuilder(column: $table.contacto, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<bool> get esPotencial => $composableBuilder(
      column: $table.esPotencial, builder: (column) => column);

  GeneratedColumn<String> get notas =>
      $composableBuilder(column: $table.notas, builder: (column) => column);

  GeneratedColumn<String> get estadoPago => $composableBuilder(
      column: $table.estadoPago, builder: (column) => column);

  GeneratedColumn<DateTime> get fechaCreacion => $composableBuilder(
      column: $table.fechaCreacion, builder: (column) => column);

  Expression<T> pedidosRefs<T extends Object>(
      Expression<T> Function($$PedidosTableAnnotationComposer a) f) {
    final $$PedidosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.pedidos,
        getReferencedColumn: (t) => t.clienteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PedidosTableAnnotationComposer(
              $db: $db,
              $table: $db.pedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> historialClientesRefs<T extends Object>(
      Expression<T> Function($$HistorialClientesTableAnnotationComposer a) f) {
    final $$HistorialClientesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.historialClientes,
            getReferencedColumn: (t) => t.clienteId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$HistorialClientesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.historialClientes,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$ClientesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ClientesTable,
    Cliente,
    $$ClientesTableFilterComposer,
    $$ClientesTableOrderingComposer,
    $$ClientesTableAnnotationComposer,
    $$ClientesTableCreateCompanionBuilder,
    $$ClientesTableUpdateCompanionBuilder,
    (Cliente, $$ClientesTableReferences),
    Cliente,
    PrefetchHooks Function({bool pedidosRefs, bool historialClientesRefs})> {
  $$ClientesTableTableManager(_$AppDatabase db, $ClientesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> nombre = const Value.absent(),
            Value<String?> contacto = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<bool> esPotencial = const Value.absent(),
            Value<String?> notas = const Value.absent(),
            Value<String> estadoPago = const Value.absent(),
            Value<DateTime> fechaCreacion = const Value.absent(),
          }) =>
              ClientesCompanion(
            id: id,
            nombre: nombre,
            contacto: contacto,
            email: email,
            esPotencial: esPotencial,
            notas: notas,
            estadoPago: estadoPago,
            fechaCreacion: fechaCreacion,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String nombre,
            Value<String?> contacto = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<bool> esPotencial = const Value.absent(),
            Value<String?> notas = const Value.absent(),
            Value<String> estadoPago = const Value.absent(),
            Value<DateTime> fechaCreacion = const Value.absent(),
          }) =>
              ClientesCompanion.insert(
            id: id,
            nombre: nombre,
            contacto: contacto,
            email: email,
            esPotencial: esPotencial,
            notas: notas,
            estadoPago: estadoPago,
            fechaCreacion: fechaCreacion,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ClientesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {pedidosRefs = false, historialClientesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (pedidosRefs) db.pedidos,
                if (historialClientesRefs) db.historialClientes
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (pedidosRefs)
                    await $_getPrefetchedData<Cliente, $ClientesTable, Pedido>(
                        currentTable: table,
                        referencedTable:
                            $$ClientesTableReferences._pedidosRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ClientesTableReferences(db, table, p0)
                                .pedidosRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.clienteId == item.id),
                        typedResults: items),
                  if (historialClientesRefs)
                    await $_getPrefetchedData<Cliente, $ClientesTable,
                            HistorialCliente>(
                        currentTable: table,
                        referencedTable: $$ClientesTableReferences
                            ._historialClientesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ClientesTableReferences(db, table, p0)
                                .historialClientesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.clienteId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ClientesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ClientesTable,
    Cliente,
    $$ClientesTableFilterComposer,
    $$ClientesTableOrderingComposer,
    $$ClientesTableAnnotationComposer,
    $$ClientesTableCreateCompanionBuilder,
    $$ClientesTableUpdateCompanionBuilder,
    (Cliente, $$ClientesTableReferences),
    Cliente,
    PrefetchHooks Function({bool pedidosRefs, bool historialClientesRefs})>;
typedef $$ProductosTableCreateCompanionBuilder = ProductosCompanion Function({
  Value<int> id,
  required String nombre,
  Value<double> precioCompra,
  Value<double> precioVenta,
  Value<DateTime> fechaCreacion,
});
typedef $$ProductosTableUpdateCompanionBuilder = ProductosCompanion Function({
  Value<int> id,
  Value<String> nombre,
  Value<double> precioCompra,
  Value<double> precioVenta,
  Value<DateTime> fechaCreacion,
});

final class $$ProductosTableReferences
    extends BaseReferences<_$AppDatabase, $ProductosTable, Producto> {
  $$ProductosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StockTable, List<StockData>> _stockRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.stock,
          aliasName:
              $_aliasNameGenerator(db.productos.id, db.stock.productoId));

  $$StockTableProcessedTableManager get stockRefs {
    final manager = $$StockTableTableManager($_db, $_db.stock)
        .filter((f) => f.productoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$MovimientosStockTable, List<MovimientosStockData>>
      _movimientosStockRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.movimientosStock,
              aliasName: $_aliasNameGenerator(
                  db.productos.id, db.movimientosStock.productoId));

  $$MovimientosStockTableProcessedTableManager get movimientosStockRefs {
    final manager =
        $$MovimientosStockTableTableManager($_db, $_db.movimientosStock)
            .filter((f) => f.productoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_movimientosStockRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ProductosPedidoTable, List<ProductosPedidoData>>
      _productosPedidoRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.productosPedido,
              aliasName: $_aliasNameGenerator(
                  db.productos.id, db.productosPedido.productoId));

  $$ProductosPedidoTableProcessedTableManager get productosPedidoRefs {
    final manager =
        $$ProductosPedidoTableTableManager($_db, $_db.productosPedido)
            .filter((f) => f.productoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_productosPedidoRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProductosTableFilterComposer
    extends Composer<_$AppDatabase, $ProductosTable> {
  $$ProductosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nombre => $composableBuilder(
      column: $table.nombre, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get precioCompra => $composableBuilder(
      column: $table.precioCompra, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get precioVenta => $composableBuilder(
      column: $table.precioVenta, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fechaCreacion => $composableBuilder(
      column: $table.fechaCreacion, builder: (column) => ColumnFilters(column));

  Expression<bool> stockRefs(
      Expression<bool> Function($$StockTableFilterComposer f) f) {
    final $$StockTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stock,
        getReferencedColumn: (t) => t.productoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockTableFilterComposer(
              $db: $db,
              $table: $db.stock,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> movimientosStockRefs(
      Expression<bool> Function($$MovimientosStockTableFilterComposer f) f) {
    final $$MovimientosStockTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movimientosStock,
        getReferencedColumn: (t) => t.productoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovimientosStockTableFilterComposer(
              $db: $db,
              $table: $db.movimientosStock,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> productosPedidoRefs(
      Expression<bool> Function($$ProductosPedidoTableFilterComposer f) f) {
    final $$ProductosPedidoTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.productosPedido,
        getReferencedColumn: (t) => t.productoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosPedidoTableFilterComposer(
              $db: $db,
              $table: $db.productosPedido,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProductosTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductosTable> {
  $$ProductosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nombre => $composableBuilder(
      column: $table.nombre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get precioCompra => $composableBuilder(
      column: $table.precioCompra,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get precioVenta => $composableBuilder(
      column: $table.precioVenta, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fechaCreacion => $composableBuilder(
      column: $table.fechaCreacion,
      builder: (column) => ColumnOrderings(column));
}

class $$ProductosTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductosTable> {
  $$ProductosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<double> get precioCompra => $composableBuilder(
      column: $table.precioCompra, builder: (column) => column);

  GeneratedColumn<double> get precioVenta => $composableBuilder(
      column: $table.precioVenta, builder: (column) => column);

  GeneratedColumn<DateTime> get fechaCreacion => $composableBuilder(
      column: $table.fechaCreacion, builder: (column) => column);

  Expression<T> stockRefs<T extends Object>(
      Expression<T> Function($$StockTableAnnotationComposer a) f) {
    final $$StockTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stock,
        getReferencedColumn: (t) => t.productoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockTableAnnotationComposer(
              $db: $db,
              $table: $db.stock,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> movimientosStockRefs<T extends Object>(
      Expression<T> Function($$MovimientosStockTableAnnotationComposer a) f) {
    final $$MovimientosStockTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movimientosStock,
        getReferencedColumn: (t) => t.productoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovimientosStockTableAnnotationComposer(
              $db: $db,
              $table: $db.movimientosStock,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> productosPedidoRefs<T extends Object>(
      Expression<T> Function($$ProductosPedidoTableAnnotationComposer a) f) {
    final $$ProductosPedidoTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.productosPedido,
        getReferencedColumn: (t) => t.productoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosPedidoTableAnnotationComposer(
              $db: $db,
              $table: $db.productosPedido,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProductosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProductosTable,
    Producto,
    $$ProductosTableFilterComposer,
    $$ProductosTableOrderingComposer,
    $$ProductosTableAnnotationComposer,
    $$ProductosTableCreateCompanionBuilder,
    $$ProductosTableUpdateCompanionBuilder,
    (Producto, $$ProductosTableReferences),
    Producto,
    PrefetchHooks Function(
        {bool stockRefs,
        bool movimientosStockRefs,
        bool productosPedidoRefs})> {
  $$ProductosTableTableManager(_$AppDatabase db, $ProductosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> nombre = const Value.absent(),
            Value<double> precioCompra = const Value.absent(),
            Value<double> precioVenta = const Value.absent(),
            Value<DateTime> fechaCreacion = const Value.absent(),
          }) =>
              ProductosCompanion(
            id: id,
            nombre: nombre,
            precioCompra: precioCompra,
            precioVenta: precioVenta,
            fechaCreacion: fechaCreacion,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String nombre,
            Value<double> precioCompra = const Value.absent(),
            Value<double> precioVenta = const Value.absent(),
            Value<DateTime> fechaCreacion = const Value.absent(),
          }) =>
              ProductosCompanion.insert(
            id: id,
            nombre: nombre,
            precioCompra: precioCompra,
            precioVenta: precioVenta,
            fechaCreacion: fechaCreacion,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ProductosTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {stockRefs = false,
              movimientosStockRefs = false,
              productosPedidoRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (stockRefs) db.stock,
                if (movimientosStockRefs) db.movimientosStock,
                if (productosPedidoRefs) db.productosPedido
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (stockRefs)
                    await $_getPrefetchedData<Producto, $ProductosTable,
                            StockData>(
                        currentTable: table,
                        referencedTable:
                            $$ProductosTableReferences._stockRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProductosTableReferences(db, table, p0).stockRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productoId == item.id),
                        typedResults: items),
                  if (movimientosStockRefs)
                    await $_getPrefetchedData<Producto, $ProductosTable,
                            MovimientosStockData>(
                        currentTable: table,
                        referencedTable: $$ProductosTableReferences
                            ._movimientosStockRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProductosTableReferences(db, table, p0)
                                .movimientosStockRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productoId == item.id),
                        typedResults: items),
                  if (productosPedidoRefs)
                    await $_getPrefetchedData<Producto, $ProductosTable,
                            ProductosPedidoData>(
                        currentTable: table,
                        referencedTable: $$ProductosTableReferences
                            ._productosPedidoRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProductosTableReferences(db, table, p0)
                                .productosPedidoRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productoId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProductosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProductosTable,
    Producto,
    $$ProductosTableFilterComposer,
    $$ProductosTableOrderingComposer,
    $$ProductosTableAnnotationComposer,
    $$ProductosTableCreateCompanionBuilder,
    $$ProductosTableUpdateCompanionBuilder,
    (Producto, $$ProductosTableReferences),
    Producto,
    PrefetchHooks Function(
        {bool stockRefs, bool movimientosStockRefs, bool productosPedidoRefs})>;
typedef $$StockTableCreateCompanionBuilder = StockCompanion Function({
  Value<int> id,
  required int productoId,
  required int usuarioId,
  Value<int> cantidadActual,
});
typedef $$StockTableUpdateCompanionBuilder = StockCompanion Function({
  Value<int> id,
  Value<int> productoId,
  Value<int> usuarioId,
  Value<int> cantidadActual,
});

final class $$StockTableReferences
    extends BaseReferences<_$AppDatabase, $StockTable, StockData> {
  $$StockTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductosTable _productoIdTable(_$AppDatabase db) => db.productos
      .createAlias($_aliasNameGenerator(db.stock.productoId, db.productos.id));

  $$ProductosTableProcessedTableManager get productoId {
    final $_column = $_itemColumn<int>('producto_id')!;

    final manager = $$ProductosTableTableManager($_db, $_db.productos)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $UsuariosTable _usuarioIdTable(_$AppDatabase db) => db.usuarios
      .createAlias($_aliasNameGenerator(db.stock.usuarioId, db.usuarios.id));

  $$UsuariosTableProcessedTableManager get usuarioId {
    final $_column = $_itemColumn<int>('usuario_id')!;

    final manager = $$UsuariosTableTableManager($_db, $_db.usuarios)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_usuarioIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$StockTableFilterComposer extends Composer<_$AppDatabase, $StockTable> {
  $$StockTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cantidadActual => $composableBuilder(
      column: $table.cantidadActual,
      builder: (column) => ColumnFilters(column));

  $$ProductosTableFilterComposer get productoId {
    final $$ProductosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableFilterComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$UsuariosTableFilterComposer get usuarioId {
    final $$UsuariosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.usuarioId,
        referencedTable: $db.usuarios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsuariosTableFilterComposer(
              $db: $db,
              $table: $db.usuarios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockTableOrderingComposer
    extends Composer<_$AppDatabase, $StockTable> {
  $$StockTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cantidadActual => $composableBuilder(
      column: $table.cantidadActual,
      builder: (column) => ColumnOrderings(column));

  $$ProductosTableOrderingComposer get productoId {
    final $$ProductosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableOrderingComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$UsuariosTableOrderingComposer get usuarioId {
    final $$UsuariosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.usuarioId,
        referencedTable: $db.usuarios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsuariosTableOrderingComposer(
              $db: $db,
              $table: $db.usuarios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockTable> {
  $$StockTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cantidadActual => $composableBuilder(
      column: $table.cantidadActual, builder: (column) => column);

  $$ProductosTableAnnotationComposer get productoId {
    final $$ProductosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableAnnotationComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$UsuariosTableAnnotationComposer get usuarioId {
    final $$UsuariosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.usuarioId,
        referencedTable: $db.usuarios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsuariosTableAnnotationComposer(
              $db: $db,
              $table: $db.usuarios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StockTable,
    StockData,
    $$StockTableFilterComposer,
    $$StockTableOrderingComposer,
    $$StockTableAnnotationComposer,
    $$StockTableCreateCompanionBuilder,
    $$StockTableUpdateCompanionBuilder,
    (StockData, $$StockTableReferences),
    StockData,
    PrefetchHooks Function({bool productoId, bool usuarioId})> {
  $$StockTableTableManager(_$AppDatabase db, $StockTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> productoId = const Value.absent(),
            Value<int> usuarioId = const Value.absent(),
            Value<int> cantidadActual = const Value.absent(),
          }) =>
              StockCompanion(
            id: id,
            productoId: productoId,
            usuarioId: usuarioId,
            cantidadActual: cantidadActual,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int productoId,
            required int usuarioId,
            Value<int> cantidadActual = const Value.absent(),
          }) =>
              StockCompanion.insert(
            id: id,
            productoId: productoId,
            usuarioId: usuarioId,
            cantidadActual: cantidadActual,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$StockTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({productoId = false, usuarioId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (productoId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productoId,
                    referencedTable:
                        $$StockTableReferences._productoIdTable(db),
                    referencedColumn:
                        $$StockTableReferences._productoIdTable(db).id,
                  ) as T;
                }
                if (usuarioId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.usuarioId,
                    referencedTable: $$StockTableReferences._usuarioIdTable(db),
                    referencedColumn:
                        $$StockTableReferences._usuarioIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$StockTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StockTable,
    StockData,
    $$StockTableFilterComposer,
    $$StockTableOrderingComposer,
    $$StockTableAnnotationComposer,
    $$StockTableCreateCompanionBuilder,
    $$StockTableUpdateCompanionBuilder,
    (StockData, $$StockTableReferences),
    StockData,
    PrefetchHooks Function({bool productoId, bool usuarioId})>;
typedef $$MovimientosStockTableCreateCompanionBuilder
    = MovimientosStockCompanion Function({
  Value<int> id,
  required int productoId,
  required int usuarioId,
  required String tipo,
  required int cantidad,
  Value<String?> descripcion,
  Value<DateTime> fechaCarga,
  Value<DateTime?> fechaSalida,
});
typedef $$MovimientosStockTableUpdateCompanionBuilder
    = MovimientosStockCompanion Function({
  Value<int> id,
  Value<int> productoId,
  Value<int> usuarioId,
  Value<String> tipo,
  Value<int> cantidad,
  Value<String?> descripcion,
  Value<DateTime> fechaCarga,
  Value<DateTime?> fechaSalida,
});

final class $$MovimientosStockTableReferences extends BaseReferences<
    _$AppDatabase, $MovimientosStockTable, MovimientosStockData> {
  $$MovimientosStockTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProductosTable _productoIdTable(_$AppDatabase db) =>
      db.productos.createAlias($_aliasNameGenerator(
          db.movimientosStock.productoId, db.productos.id));

  $$ProductosTableProcessedTableManager get productoId {
    final $_column = $_itemColumn<int>('producto_id')!;

    final manager = $$ProductosTableTableManager($_db, $_db.productos)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $UsuariosTable _usuarioIdTable(_$AppDatabase db) =>
      db.usuarios.createAlias(
          $_aliasNameGenerator(db.movimientosStock.usuarioId, db.usuarios.id));

  $$UsuariosTableProcessedTableManager get usuarioId {
    final $_column = $_itemColumn<int>('usuario_id')!;

    final manager = $$UsuariosTableTableManager($_db, $_db.usuarios)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_usuarioIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MovimientosStockTableFilterComposer
    extends Composer<_$AppDatabase, $MovimientosStockTable> {
  $$MovimientosStockTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tipo => $composableBuilder(
      column: $table.tipo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cantidad => $composableBuilder(
      column: $table.cantidad, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get descripcion => $composableBuilder(
      column: $table.descripcion, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fechaCarga => $composableBuilder(
      column: $table.fechaCarga, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fechaSalida => $composableBuilder(
      column: $table.fechaSalida, builder: (column) => ColumnFilters(column));

  $$ProductosTableFilterComposer get productoId {
    final $$ProductosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableFilterComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$UsuariosTableFilterComposer get usuarioId {
    final $$UsuariosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.usuarioId,
        referencedTable: $db.usuarios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsuariosTableFilterComposer(
              $db: $db,
              $table: $db.usuarios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MovimientosStockTableOrderingComposer
    extends Composer<_$AppDatabase, $MovimientosStockTable> {
  $$MovimientosStockTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tipo => $composableBuilder(
      column: $table.tipo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cantidad => $composableBuilder(
      column: $table.cantidad, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get descripcion => $composableBuilder(
      column: $table.descripcion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fechaCarga => $composableBuilder(
      column: $table.fechaCarga, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fechaSalida => $composableBuilder(
      column: $table.fechaSalida, builder: (column) => ColumnOrderings(column));

  $$ProductosTableOrderingComposer get productoId {
    final $$ProductosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableOrderingComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$UsuariosTableOrderingComposer get usuarioId {
    final $$UsuariosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.usuarioId,
        referencedTable: $db.usuarios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsuariosTableOrderingComposer(
              $db: $db,
              $table: $db.usuarios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MovimientosStockTableAnnotationComposer
    extends Composer<_$AppDatabase, $MovimientosStockTable> {
  $$MovimientosStockTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<int> get cantidad =>
      $composableBuilder(column: $table.cantidad, builder: (column) => column);

  GeneratedColumn<String> get descripcion => $composableBuilder(
      column: $table.descripcion, builder: (column) => column);

  GeneratedColumn<DateTime> get fechaCarga => $composableBuilder(
      column: $table.fechaCarga, builder: (column) => column);

  GeneratedColumn<DateTime> get fechaSalida => $composableBuilder(
      column: $table.fechaSalida, builder: (column) => column);

  $$ProductosTableAnnotationComposer get productoId {
    final $$ProductosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableAnnotationComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$UsuariosTableAnnotationComposer get usuarioId {
    final $$UsuariosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.usuarioId,
        referencedTable: $db.usuarios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$UsuariosTableAnnotationComposer(
              $db: $db,
              $table: $db.usuarios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MovimientosStockTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MovimientosStockTable,
    MovimientosStockData,
    $$MovimientosStockTableFilterComposer,
    $$MovimientosStockTableOrderingComposer,
    $$MovimientosStockTableAnnotationComposer,
    $$MovimientosStockTableCreateCompanionBuilder,
    $$MovimientosStockTableUpdateCompanionBuilder,
    (MovimientosStockData, $$MovimientosStockTableReferences),
    MovimientosStockData,
    PrefetchHooks Function({bool productoId, bool usuarioId})> {
  $$MovimientosStockTableTableManager(
      _$AppDatabase db, $MovimientosStockTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MovimientosStockTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MovimientosStockTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MovimientosStockTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> productoId = const Value.absent(),
            Value<int> usuarioId = const Value.absent(),
            Value<String> tipo = const Value.absent(),
            Value<int> cantidad = const Value.absent(),
            Value<String?> descripcion = const Value.absent(),
            Value<DateTime> fechaCarga = const Value.absent(),
            Value<DateTime?> fechaSalida = const Value.absent(),
          }) =>
              MovimientosStockCompanion(
            id: id,
            productoId: productoId,
            usuarioId: usuarioId,
            tipo: tipo,
            cantidad: cantidad,
            descripcion: descripcion,
            fechaCarga: fechaCarga,
            fechaSalida: fechaSalida,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int productoId,
            required int usuarioId,
            required String tipo,
            required int cantidad,
            Value<String?> descripcion = const Value.absent(),
            Value<DateTime> fechaCarga = const Value.absent(),
            Value<DateTime?> fechaSalida = const Value.absent(),
          }) =>
              MovimientosStockCompanion.insert(
            id: id,
            productoId: productoId,
            usuarioId: usuarioId,
            tipo: tipo,
            cantidad: cantidad,
            descripcion: descripcion,
            fechaCarga: fechaCarga,
            fechaSalida: fechaSalida,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MovimientosStockTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({productoId = false, usuarioId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (productoId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productoId,
                    referencedTable:
                        $$MovimientosStockTableReferences._productoIdTable(db),
                    referencedColumn: $$MovimientosStockTableReferences
                        ._productoIdTable(db)
                        .id,
                  ) as T;
                }
                if (usuarioId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.usuarioId,
                    referencedTable:
                        $$MovimientosStockTableReferences._usuarioIdTable(db),
                    referencedColumn: $$MovimientosStockTableReferences
                        ._usuarioIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MovimientosStockTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MovimientosStockTable,
    MovimientosStockData,
    $$MovimientosStockTableFilterComposer,
    $$MovimientosStockTableOrderingComposer,
    $$MovimientosStockTableAnnotationComposer,
    $$MovimientosStockTableCreateCompanionBuilder,
    $$MovimientosStockTableUpdateCompanionBuilder,
    (MovimientosStockData, $$MovimientosStockTableReferences),
    MovimientosStockData,
    PrefetchHooks Function({bool productoId, bool usuarioId})>;
typedef $$PedidosTableCreateCompanionBuilder = PedidosCompanion Function({
  Value<int> id,
  required int clienteId,
  Value<DateTime> fecha,
  Value<String> estado,
  Value<double> montoSenado,
});
typedef $$PedidosTableUpdateCompanionBuilder = PedidosCompanion Function({
  Value<int> id,
  Value<int> clienteId,
  Value<DateTime> fecha,
  Value<String> estado,
  Value<double> montoSenado,
});

final class $$PedidosTableReferences
    extends BaseReferences<_$AppDatabase, $PedidosTable, Pedido> {
  $$PedidosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientesTable _clienteIdTable(_$AppDatabase db) => db.clientes
      .createAlias($_aliasNameGenerator(db.pedidos.clienteId, db.clientes.id));

  $$ClientesTableProcessedTableManager get clienteId {
    final $_column = $_itemColumn<int>('cliente_id')!;

    final manager = $$ClientesTableTableManager($_db, $_db.clientes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clienteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$ProductosPedidoTable, List<ProductosPedidoData>>
      _productosPedidoRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.productosPedido,
              aliasName: $_aliasNameGenerator(
                  db.pedidos.id, db.productosPedido.pedidoId));

  $$ProductosPedidoTableProcessedTableManager get productosPedidoRefs {
    final manager =
        $$ProductosPedidoTableTableManager($_db, $_db.productosPedido)
            .filter((f) => f.pedidoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_productosPedidoRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$HistorialPedidosTable, List<HistorialPedido>>
      _historialPedidosRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.historialPedidos,
              aliasName: $_aliasNameGenerator(
                  db.pedidos.id, db.historialPedidos.pedidoId));

  $$HistorialPedidosTableProcessedTableManager get historialPedidosRefs {
    final manager =
        $$HistorialPedidosTableTableManager($_db, $_db.historialPedidos)
            .filter((f) => f.pedidoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_historialPedidosRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PedidosTableFilterComposer
    extends Composer<_$AppDatabase, $PedidosTable> {
  $$PedidosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fecha => $composableBuilder(
      column: $table.fecha, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estado => $composableBuilder(
      column: $table.estado, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get montoSenado => $composableBuilder(
      column: $table.montoSenado, builder: (column) => ColumnFilters(column));

  $$ClientesTableFilterComposer get clienteId {
    final $$ClientesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clienteId,
        referencedTable: $db.clientes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientesTableFilterComposer(
              $db: $db,
              $table: $db.clientes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> productosPedidoRefs(
      Expression<bool> Function($$ProductosPedidoTableFilterComposer f) f) {
    final $$ProductosPedidoTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.productosPedido,
        getReferencedColumn: (t) => t.pedidoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosPedidoTableFilterComposer(
              $db: $db,
              $table: $db.productosPedido,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> historialPedidosRefs(
      Expression<bool> Function($$HistorialPedidosTableFilterComposer f) f) {
    final $$HistorialPedidosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.historialPedidos,
        getReferencedColumn: (t) => t.pedidoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HistorialPedidosTableFilterComposer(
              $db: $db,
              $table: $db.historialPedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PedidosTableOrderingComposer
    extends Composer<_$AppDatabase, $PedidosTable> {
  $$PedidosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fecha => $composableBuilder(
      column: $table.fecha, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estado => $composableBuilder(
      column: $table.estado, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get montoSenado => $composableBuilder(
      column: $table.montoSenado, builder: (column) => ColumnOrderings(column));

  $$ClientesTableOrderingComposer get clienteId {
    final $$ClientesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clienteId,
        referencedTable: $db.clientes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientesTableOrderingComposer(
              $db: $db,
              $table: $db.clientes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PedidosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PedidosTable> {
  $$PedidosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<double> get montoSenado => $composableBuilder(
      column: $table.montoSenado, builder: (column) => column);

  $$ClientesTableAnnotationComposer get clienteId {
    final $$ClientesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clienteId,
        referencedTable: $db.clientes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientesTableAnnotationComposer(
              $db: $db,
              $table: $db.clientes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> productosPedidoRefs<T extends Object>(
      Expression<T> Function($$ProductosPedidoTableAnnotationComposer a) f) {
    final $$ProductosPedidoTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.productosPedido,
        getReferencedColumn: (t) => t.pedidoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosPedidoTableAnnotationComposer(
              $db: $db,
              $table: $db.productosPedido,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> historialPedidosRefs<T extends Object>(
      Expression<T> Function($$HistorialPedidosTableAnnotationComposer a) f) {
    final $$HistorialPedidosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.historialPedidos,
        getReferencedColumn: (t) => t.pedidoId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HistorialPedidosTableAnnotationComposer(
              $db: $db,
              $table: $db.historialPedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PedidosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PedidosTable,
    Pedido,
    $$PedidosTableFilterComposer,
    $$PedidosTableOrderingComposer,
    $$PedidosTableAnnotationComposer,
    $$PedidosTableCreateCompanionBuilder,
    $$PedidosTableUpdateCompanionBuilder,
    (Pedido, $$PedidosTableReferences),
    Pedido,
    PrefetchHooks Function(
        {bool clienteId,
        bool productosPedidoRefs,
        bool historialPedidosRefs})> {
  $$PedidosTableTableManager(_$AppDatabase db, $PedidosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PedidosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PedidosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PedidosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> clienteId = const Value.absent(),
            Value<DateTime> fecha = const Value.absent(),
            Value<String> estado = const Value.absent(),
            Value<double> montoSenado = const Value.absent(),
          }) =>
              PedidosCompanion(
            id: id,
            clienteId: clienteId,
            fecha: fecha,
            estado: estado,
            montoSenado: montoSenado,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int clienteId,
            Value<DateTime> fecha = const Value.absent(),
            Value<String> estado = const Value.absent(),
            Value<double> montoSenado = const Value.absent(),
          }) =>
              PedidosCompanion.insert(
            id: id,
            clienteId: clienteId,
            fecha: fecha,
            estado: estado,
            montoSenado: montoSenado,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PedidosTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {clienteId = false,
              productosPedidoRefs = false,
              historialPedidosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (productosPedidoRefs) db.productosPedido,
                if (historialPedidosRefs) db.historialPedidos
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (clienteId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.clienteId,
                    referencedTable:
                        $$PedidosTableReferences._clienteIdTable(db),
                    referencedColumn:
                        $$PedidosTableReferences._clienteIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (productosPedidoRefs)
                    await $_getPrefetchedData<Pedido, $PedidosTable,
                            ProductosPedidoData>(
                        currentTable: table,
                        referencedTable: $$PedidosTableReferences
                            ._productosPedidoRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PedidosTableReferences(db, table, p0)
                                .productosPedidoRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pedidoId == item.id),
                        typedResults: items),
                  if (historialPedidosRefs)
                    await $_getPrefetchedData<Pedido, $PedidosTable,
                            HistorialPedido>(
                        currentTable: table,
                        referencedTable: $$PedidosTableReferences
                            ._historialPedidosRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PedidosTableReferences(db, table, p0)
                                .historialPedidosRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.pedidoId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PedidosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PedidosTable,
    Pedido,
    $$PedidosTableFilterComposer,
    $$PedidosTableOrderingComposer,
    $$PedidosTableAnnotationComposer,
    $$PedidosTableCreateCompanionBuilder,
    $$PedidosTableUpdateCompanionBuilder,
    (Pedido, $$PedidosTableReferences),
    Pedido,
    PrefetchHooks Function(
        {bool clienteId, bool productosPedidoRefs, bool historialPedidosRefs})>;
typedef $$ProductosPedidoTableCreateCompanionBuilder = ProductosPedidoCompanion
    Function({
  Value<int> id,
  required int pedidoId,
  required int productoId,
  required int cantidad,
});
typedef $$ProductosPedidoTableUpdateCompanionBuilder = ProductosPedidoCompanion
    Function({
  Value<int> id,
  Value<int> pedidoId,
  Value<int> productoId,
  Value<int> cantidad,
});

final class $$ProductosPedidoTableReferences extends BaseReferences<
    _$AppDatabase, $ProductosPedidoTable, ProductosPedidoData> {
  $$ProductosPedidoTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PedidosTable _pedidoIdTable(_$AppDatabase db) =>
      db.pedidos.createAlias(
          $_aliasNameGenerator(db.productosPedido.pedidoId, db.pedidos.id));

  $$PedidosTableProcessedTableManager get pedidoId {
    final $_column = $_itemColumn<int>('pedido_id')!;

    final manager = $$PedidosTableTableManager($_db, $_db.pedidos)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pedidoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProductosTable _productoIdTable(_$AppDatabase db) =>
      db.productos.createAlias(
          $_aliasNameGenerator(db.productosPedido.productoId, db.productos.id));

  $$ProductosTableProcessedTableManager get productoId {
    final $_column = $_itemColumn<int>('producto_id')!;

    final manager = $$ProductosTableTableManager($_db, $_db.productos)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ProductosPedidoTableFilterComposer
    extends Composer<_$AppDatabase, $ProductosPedidoTable> {
  $$ProductosPedidoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cantidad => $composableBuilder(
      column: $table.cantidad, builder: (column) => ColumnFilters(column));

  $$PedidosTableFilterComposer get pedidoId {
    final $$PedidosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pedidoId,
        referencedTable: $db.pedidos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PedidosTableFilterComposer(
              $db: $db,
              $table: $db.pedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProductosTableFilterComposer get productoId {
    final $$ProductosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableFilterComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProductosPedidoTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductosPedidoTable> {
  $$ProductosPedidoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cantidad => $composableBuilder(
      column: $table.cantidad, builder: (column) => ColumnOrderings(column));

  $$PedidosTableOrderingComposer get pedidoId {
    final $$PedidosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pedidoId,
        referencedTable: $db.pedidos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PedidosTableOrderingComposer(
              $db: $db,
              $table: $db.pedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProductosTableOrderingComposer get productoId {
    final $$ProductosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableOrderingComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProductosPedidoTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductosPedidoTable> {
  $$ProductosPedidoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cantidad =>
      $composableBuilder(column: $table.cantidad, builder: (column) => column);

  $$PedidosTableAnnotationComposer get pedidoId {
    final $$PedidosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pedidoId,
        referencedTable: $db.pedidos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PedidosTableAnnotationComposer(
              $db: $db,
              $table: $db.pedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProductosTableAnnotationComposer get productoId {
    final $$ProductosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productoId,
        referencedTable: $db.productos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductosTableAnnotationComposer(
              $db: $db,
              $table: $db.productos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProductosPedidoTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProductosPedidoTable,
    ProductosPedidoData,
    $$ProductosPedidoTableFilterComposer,
    $$ProductosPedidoTableOrderingComposer,
    $$ProductosPedidoTableAnnotationComposer,
    $$ProductosPedidoTableCreateCompanionBuilder,
    $$ProductosPedidoTableUpdateCompanionBuilder,
    (ProductosPedidoData, $$ProductosPedidoTableReferences),
    ProductosPedidoData,
    PrefetchHooks Function({bool pedidoId, bool productoId})> {
  $$ProductosPedidoTableTableManager(
      _$AppDatabase db, $ProductosPedidoTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductosPedidoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductosPedidoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductosPedidoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> pedidoId = const Value.absent(),
            Value<int> productoId = const Value.absent(),
            Value<int> cantidad = const Value.absent(),
          }) =>
              ProductosPedidoCompanion(
            id: id,
            pedidoId: pedidoId,
            productoId: productoId,
            cantidad: cantidad,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int pedidoId,
            required int productoId,
            required int cantidad,
          }) =>
              ProductosPedidoCompanion.insert(
            id: id,
            pedidoId: pedidoId,
            productoId: productoId,
            cantidad: cantidad,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ProductosPedidoTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({pedidoId = false, productoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pedidoId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pedidoId,
                    referencedTable:
                        $$ProductosPedidoTableReferences._pedidoIdTable(db),
                    referencedColumn:
                        $$ProductosPedidoTableReferences._pedidoIdTable(db).id,
                  ) as T;
                }
                if (productoId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productoId,
                    referencedTable:
                        $$ProductosPedidoTableReferences._productoIdTable(db),
                    referencedColumn: $$ProductosPedidoTableReferences
                        ._productoIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ProductosPedidoTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProductosPedidoTable,
    ProductosPedidoData,
    $$ProductosPedidoTableFilterComposer,
    $$ProductosPedidoTableOrderingComposer,
    $$ProductosPedidoTableAnnotationComposer,
    $$ProductosPedidoTableCreateCompanionBuilder,
    $$ProductosPedidoTableUpdateCompanionBuilder,
    (ProductosPedidoData, $$ProductosPedidoTableReferences),
    ProductosPedidoData,
    PrefetchHooks Function({bool pedidoId, bool productoId})>;
typedef $$HistorialPedidosTableCreateCompanionBuilder
    = HistorialPedidosCompanion Function({
  Value<int> id,
  required int pedidoId,
  required String estadoAnterior,
  required String estadoNuevo,
  Value<DateTime> fechaCambio,
});
typedef $$HistorialPedidosTableUpdateCompanionBuilder
    = HistorialPedidosCompanion Function({
  Value<int> id,
  Value<int> pedidoId,
  Value<String> estadoAnterior,
  Value<String> estadoNuevo,
  Value<DateTime> fechaCambio,
});

final class $$HistorialPedidosTableReferences extends BaseReferences<
    _$AppDatabase, $HistorialPedidosTable, HistorialPedido> {
  $$HistorialPedidosTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PedidosTable _pedidoIdTable(_$AppDatabase db) =>
      db.pedidos.createAlias(
          $_aliasNameGenerator(db.historialPedidos.pedidoId, db.pedidos.id));

  $$PedidosTableProcessedTableManager get pedidoId {
    final $_column = $_itemColumn<int>('pedido_id')!;

    final manager = $$PedidosTableTableManager($_db, $_db.pedidos)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pedidoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$HistorialPedidosTableFilterComposer
    extends Composer<_$AppDatabase, $HistorialPedidosTable> {
  $$HistorialPedidosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estadoAnterior => $composableBuilder(
      column: $table.estadoAnterior,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estadoNuevo => $composableBuilder(
      column: $table.estadoNuevo, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fechaCambio => $composableBuilder(
      column: $table.fechaCambio, builder: (column) => ColumnFilters(column));

  $$PedidosTableFilterComposer get pedidoId {
    final $$PedidosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pedidoId,
        referencedTable: $db.pedidos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PedidosTableFilterComposer(
              $db: $db,
              $table: $db.pedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HistorialPedidosTableOrderingComposer
    extends Composer<_$AppDatabase, $HistorialPedidosTable> {
  $$HistorialPedidosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estadoAnterior => $composableBuilder(
      column: $table.estadoAnterior,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estadoNuevo => $composableBuilder(
      column: $table.estadoNuevo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fechaCambio => $composableBuilder(
      column: $table.fechaCambio, builder: (column) => ColumnOrderings(column));

  $$PedidosTableOrderingComposer get pedidoId {
    final $$PedidosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pedidoId,
        referencedTable: $db.pedidos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PedidosTableOrderingComposer(
              $db: $db,
              $table: $db.pedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HistorialPedidosTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistorialPedidosTable> {
  $$HistorialPedidosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get estadoAnterior => $composableBuilder(
      column: $table.estadoAnterior, builder: (column) => column);

  GeneratedColumn<String> get estadoNuevo => $composableBuilder(
      column: $table.estadoNuevo, builder: (column) => column);

  GeneratedColumn<DateTime> get fechaCambio => $composableBuilder(
      column: $table.fechaCambio, builder: (column) => column);

  $$PedidosTableAnnotationComposer get pedidoId {
    final $$PedidosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.pedidoId,
        referencedTable: $db.pedidos,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PedidosTableAnnotationComposer(
              $db: $db,
              $table: $db.pedidos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HistorialPedidosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HistorialPedidosTable,
    HistorialPedido,
    $$HistorialPedidosTableFilterComposer,
    $$HistorialPedidosTableOrderingComposer,
    $$HistorialPedidosTableAnnotationComposer,
    $$HistorialPedidosTableCreateCompanionBuilder,
    $$HistorialPedidosTableUpdateCompanionBuilder,
    (HistorialPedido, $$HistorialPedidosTableReferences),
    HistorialPedido,
    PrefetchHooks Function({bool pedidoId})> {
  $$HistorialPedidosTableTableManager(
      _$AppDatabase db, $HistorialPedidosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistorialPedidosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistorialPedidosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistorialPedidosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> pedidoId = const Value.absent(),
            Value<String> estadoAnterior = const Value.absent(),
            Value<String> estadoNuevo = const Value.absent(),
            Value<DateTime> fechaCambio = const Value.absent(),
          }) =>
              HistorialPedidosCompanion(
            id: id,
            pedidoId: pedidoId,
            estadoAnterior: estadoAnterior,
            estadoNuevo: estadoNuevo,
            fechaCambio: fechaCambio,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int pedidoId,
            required String estadoAnterior,
            required String estadoNuevo,
            Value<DateTime> fechaCambio = const Value.absent(),
          }) =>
              HistorialPedidosCompanion.insert(
            id: id,
            pedidoId: pedidoId,
            estadoAnterior: estadoAnterior,
            estadoNuevo: estadoNuevo,
            fechaCambio: fechaCambio,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$HistorialPedidosTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({pedidoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (pedidoId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.pedidoId,
                    referencedTable:
                        $$HistorialPedidosTableReferences._pedidoIdTable(db),
                    referencedColumn:
                        $$HistorialPedidosTableReferences._pedidoIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$HistorialPedidosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HistorialPedidosTable,
    HistorialPedido,
    $$HistorialPedidosTableFilterComposer,
    $$HistorialPedidosTableOrderingComposer,
    $$HistorialPedidosTableAnnotationComposer,
    $$HistorialPedidosTableCreateCompanionBuilder,
    $$HistorialPedidosTableUpdateCompanionBuilder,
    (HistorialPedido, $$HistorialPedidosTableReferences),
    HistorialPedido,
    PrefetchHooks Function({bool pedidoId})>;
typedef $$HistorialClientesTableCreateCompanionBuilder
    = HistorialClientesCompanion Function({
  Value<int> id,
  required int clienteId,
  required String estadoAnterior,
  required String estadoNuevo,
  Value<DateTime> fechaCambio,
});
typedef $$HistorialClientesTableUpdateCompanionBuilder
    = HistorialClientesCompanion Function({
  Value<int> id,
  Value<int> clienteId,
  Value<String> estadoAnterior,
  Value<String> estadoNuevo,
  Value<DateTime> fechaCambio,
});

final class $$HistorialClientesTableReferences extends BaseReferences<
    _$AppDatabase, $HistorialClientesTable, HistorialCliente> {
  $$HistorialClientesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ClientesTable _clienteIdTable(_$AppDatabase db) =>
      db.clientes.createAlias(
          $_aliasNameGenerator(db.historialClientes.clienteId, db.clientes.id));

  $$ClientesTableProcessedTableManager get clienteId {
    final $_column = $_itemColumn<int>('cliente_id')!;

    final manager = $$ClientesTableTableManager($_db, $_db.clientes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clienteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$HistorialClientesTableFilterComposer
    extends Composer<_$AppDatabase, $HistorialClientesTable> {
  $$HistorialClientesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estadoAnterior => $composableBuilder(
      column: $table.estadoAnterior,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estadoNuevo => $composableBuilder(
      column: $table.estadoNuevo, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fechaCambio => $composableBuilder(
      column: $table.fechaCambio, builder: (column) => ColumnFilters(column));

  $$ClientesTableFilterComposer get clienteId {
    final $$ClientesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clienteId,
        referencedTable: $db.clientes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientesTableFilterComposer(
              $db: $db,
              $table: $db.clientes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HistorialClientesTableOrderingComposer
    extends Composer<_$AppDatabase, $HistorialClientesTable> {
  $$HistorialClientesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estadoAnterior => $composableBuilder(
      column: $table.estadoAnterior,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estadoNuevo => $composableBuilder(
      column: $table.estadoNuevo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fechaCambio => $composableBuilder(
      column: $table.fechaCambio, builder: (column) => ColumnOrderings(column));

  $$ClientesTableOrderingComposer get clienteId {
    final $$ClientesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clienteId,
        referencedTable: $db.clientes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientesTableOrderingComposer(
              $db: $db,
              $table: $db.clientes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HistorialClientesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistorialClientesTable> {
  $$HistorialClientesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get estadoAnterior => $composableBuilder(
      column: $table.estadoAnterior, builder: (column) => column);

  GeneratedColumn<String> get estadoNuevo => $composableBuilder(
      column: $table.estadoNuevo, builder: (column) => column);

  GeneratedColumn<DateTime> get fechaCambio => $composableBuilder(
      column: $table.fechaCambio, builder: (column) => column);

  $$ClientesTableAnnotationComposer get clienteId {
    final $$ClientesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clienteId,
        referencedTable: $db.clientes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClientesTableAnnotationComposer(
              $db: $db,
              $table: $db.clientes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HistorialClientesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HistorialClientesTable,
    HistorialCliente,
    $$HistorialClientesTableFilterComposer,
    $$HistorialClientesTableOrderingComposer,
    $$HistorialClientesTableAnnotationComposer,
    $$HistorialClientesTableCreateCompanionBuilder,
    $$HistorialClientesTableUpdateCompanionBuilder,
    (HistorialCliente, $$HistorialClientesTableReferences),
    HistorialCliente,
    PrefetchHooks Function({bool clienteId})> {
  $$HistorialClientesTableTableManager(
      _$AppDatabase db, $HistorialClientesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistorialClientesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistorialClientesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistorialClientesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> clienteId = const Value.absent(),
            Value<String> estadoAnterior = const Value.absent(),
            Value<String> estadoNuevo = const Value.absent(),
            Value<DateTime> fechaCambio = const Value.absent(),
          }) =>
              HistorialClientesCompanion(
            id: id,
            clienteId: clienteId,
            estadoAnterior: estadoAnterior,
            estadoNuevo: estadoNuevo,
            fechaCambio: fechaCambio,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int clienteId,
            required String estadoAnterior,
            required String estadoNuevo,
            Value<DateTime> fechaCambio = const Value.absent(),
          }) =>
              HistorialClientesCompanion.insert(
            id: id,
            clienteId: clienteId,
            estadoAnterior: estadoAnterior,
            estadoNuevo: estadoNuevo,
            fechaCambio: fechaCambio,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$HistorialClientesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({clienteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (clienteId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.clienteId,
                    referencedTable:
                        $$HistorialClientesTableReferences._clienteIdTable(db),
                    referencedColumn: $$HistorialClientesTableReferences
                        ._clienteIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$HistorialClientesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HistorialClientesTable,
    HistorialCliente,
    $$HistorialClientesTableFilterComposer,
    $$HistorialClientesTableOrderingComposer,
    $$HistorialClientesTableAnnotationComposer,
    $$HistorialClientesTableCreateCompanionBuilder,
    $$HistorialClientesTableUpdateCompanionBuilder,
    (HistorialCliente, $$HistorialClientesTableReferences),
    HistorialCliente,
    PrefetchHooks Function({bool clienteId})>;
typedef $$MovimientosCapitalTableCreateCompanionBuilder
    = MovimientosCapitalCompanion Function({
  Value<int> id,
  required String persona,
  required double monto,
  required String tipo,
  Value<String?> descripcion,
  Value<DateTime> fecha,
});
typedef $$MovimientosCapitalTableUpdateCompanionBuilder
    = MovimientosCapitalCompanion Function({
  Value<int> id,
  Value<String> persona,
  Value<double> monto,
  Value<String> tipo,
  Value<String?> descripcion,
  Value<DateTime> fecha,
});

class $$MovimientosCapitalTableFilterComposer
    extends Composer<_$AppDatabase, $MovimientosCapitalTable> {
  $$MovimientosCapitalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get persona => $composableBuilder(
      column: $table.persona, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get monto => $composableBuilder(
      column: $table.monto, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tipo => $composableBuilder(
      column: $table.tipo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get descripcion => $composableBuilder(
      column: $table.descripcion, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fecha => $composableBuilder(
      column: $table.fecha, builder: (column) => ColumnFilters(column));
}

class $$MovimientosCapitalTableOrderingComposer
    extends Composer<_$AppDatabase, $MovimientosCapitalTable> {
  $$MovimientosCapitalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get persona => $composableBuilder(
      column: $table.persona, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get monto => $composableBuilder(
      column: $table.monto, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tipo => $composableBuilder(
      column: $table.tipo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get descripcion => $composableBuilder(
      column: $table.descripcion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fecha => $composableBuilder(
      column: $table.fecha, builder: (column) => ColumnOrderings(column));
}

class $$MovimientosCapitalTableAnnotationComposer
    extends Composer<_$AppDatabase, $MovimientosCapitalTable> {
  $$MovimientosCapitalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get persona =>
      $composableBuilder(column: $table.persona, builder: (column) => column);

  GeneratedColumn<double> get monto =>
      $composableBuilder(column: $table.monto, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get descripcion => $composableBuilder(
      column: $table.descripcion, builder: (column) => column);

  GeneratedColumn<DateTime> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);
}

class $$MovimientosCapitalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MovimientosCapitalTable,
    MovimientosCapitalData,
    $$MovimientosCapitalTableFilterComposer,
    $$MovimientosCapitalTableOrderingComposer,
    $$MovimientosCapitalTableAnnotationComposer,
    $$MovimientosCapitalTableCreateCompanionBuilder,
    $$MovimientosCapitalTableUpdateCompanionBuilder,
    (
      MovimientosCapitalData,
      BaseReferences<_$AppDatabase, $MovimientosCapitalTable,
          MovimientosCapitalData>
    ),
    MovimientosCapitalData,
    PrefetchHooks Function()> {
  $$MovimientosCapitalTableTableManager(
      _$AppDatabase db, $MovimientosCapitalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MovimientosCapitalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MovimientosCapitalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MovimientosCapitalTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> persona = const Value.absent(),
            Value<double> monto = const Value.absent(),
            Value<String> tipo = const Value.absent(),
            Value<String?> descripcion = const Value.absent(),
            Value<DateTime> fecha = const Value.absent(),
          }) =>
              MovimientosCapitalCompanion(
            id: id,
            persona: persona,
            monto: monto,
            tipo: tipo,
            descripcion: descripcion,
            fecha: fecha,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String persona,
            required double monto,
            required String tipo,
            Value<String?> descripcion = const Value.absent(),
            Value<DateTime> fecha = const Value.absent(),
          }) =>
              MovimientosCapitalCompanion.insert(
            id: id,
            persona: persona,
            monto: monto,
            tipo: tipo,
            descripcion: descripcion,
            fecha: fecha,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MovimientosCapitalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MovimientosCapitalTable,
    MovimientosCapitalData,
    $$MovimientosCapitalTableFilterComposer,
    $$MovimientosCapitalTableOrderingComposer,
    $$MovimientosCapitalTableAnnotationComposer,
    $$MovimientosCapitalTableCreateCompanionBuilder,
    $$MovimientosCapitalTableUpdateCompanionBuilder,
    (
      MovimientosCapitalData,
      BaseReferences<_$AppDatabase, $MovimientosCapitalTable,
          MovimientosCapitalData>
    ),
    MovimientosCapitalData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsuariosTableTableManager get usuarios =>
      $$UsuariosTableTableManager(_db, _db.usuarios);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db, _db.clientes);
  $$ProductosTableTableManager get productos =>
      $$ProductosTableTableManager(_db, _db.productos);
  $$StockTableTableManager get stock =>
      $$StockTableTableManager(_db, _db.stock);
  $$MovimientosStockTableTableManager get movimientosStock =>
      $$MovimientosStockTableTableManager(_db, _db.movimientosStock);
  $$PedidosTableTableManager get pedidos =>
      $$PedidosTableTableManager(_db, _db.pedidos);
  $$ProductosPedidoTableTableManager get productosPedido =>
      $$ProductosPedidoTableTableManager(_db, _db.productosPedido);
  $$HistorialPedidosTableTableManager get historialPedidos =>
      $$HistorialPedidosTableTableManager(_db, _db.historialPedidos);
  $$HistorialClientesTableTableManager get historialClientes =>
      $$HistorialClientesTableTableManager(_db, _db.historialClientes);
  $$MovimientosCapitalTableTableManager get movimientosCapital =>
      $$MovimientosCapitalTableTableManager(_db, _db.movimientosCapital);
}
