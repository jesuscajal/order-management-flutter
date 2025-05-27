import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/cliente.dart' as models;
import '../data/app_database.dart';
import '../data/daos/cliente_dao.dart';

enum FiltroClientes { todos, activos, potenciales }

class ClientsScreen extends StatefulWidget {
  final AppDatabase database;

  const ClientsScreen({
    super.key,
    required this.database,
  });

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  FiltroClientes _filtroActual = FiltroClientes.todos;
  late ClienteDao _clienteDao;
  List<models.Cliente> _clientes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _clienteDao = ClienteDao(widget.database);
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoading = true);
    try {
      final clientes = await _clienteDao.getAllClientes();
      setState(() {
        _clientes = clientes
            .map((c) => models.Cliente.fromData({
                  'id': c.id,
                  'nombre': c.nombre,
                  'contacto': c.contacto,
                  'email': c.email,
                  'esPotencial': c.esPotencial,
                  'notas': c.notas,
                  'estadoPago': c.estadoPago,
                  'fechaCreacion': c.fechaCreacion.toIso8601String(),
                }))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    }
  }

  List<models.Cliente> get _clientesFiltrados {
    switch (_filtroActual) {
      case FiltroClientes.activos:
        return _clientes.where((c) => !c.esPotencial).toList();
      case FiltroClientes.potenciales:
        return _clientes.where((c) => c.esPotencial).toList();
      case FiltroClientes.todos:
      default:
        return _clientes;
    }
  }

  Color _getColorEstado(models.EstadoPago estado, BuildContext context) {
    switch (estado) {
      case models.EstadoPago.pagado:
        return Colors.green;
      case models.EstadoPago.senalado:
        return Colors.orange;
      case models.EstadoPago.pendiente:
        return Colors.red;
    }
  }

  Future<void> _seleccionarContacto(
      TextEditingController controllerNombre,
      TextEditingController controllerContacto,
      TextEditingController controllerEmail) async {
    try {
      // Solicitar permisos usando flutter_contacts
      if (!await FlutterContacts.requestPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se necesita permiso para acceder a los contactos'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Mostrar diálogo de búsqueda rápida
      final contactoSeleccionado = await showDialog<Contact>(
        context: context,
        builder: (context) => _ContactSearchDialog(),
      );

      if (contactoSeleccionado != null) {
        controllerNombre.text = contactoSeleccionado.displayName;

        if (contactoSeleccionado.phones.isNotEmpty) {
          controllerContacto.text = contactoSeleccionado.phones.first.number;
        }

        if (contactoSeleccionado.emails.isNotEmpty) {
          controllerEmail.text = contactoSeleccionado.emails.first.address;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contacto "${controllerNombre.text}" seleccionado'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al acceder a contactos: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Entendido',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _mostrarDialogoNuevoCliente() async {
    final controllerNombre = TextEditingController();
    final controllerContacto = TextEditingController();
    final controllerEmail = TextEditingController();
    final controllerNotas = TextEditingController();
    bool esPotencial = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Nuevo Cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controllerNombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controllerContacto,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _seleccionarContacto(
                        controllerNombre,
                        controllerContacto,
                        controllerEmail,
                      ),
                      icon: const Icon(Icons.contacts),
                      tooltip: 'Seleccionar de contactos',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).primaryColor.withOpacity(0.1),
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controllerEmail,
                  decoration: const InputDecoration(
                    labelText: 'Email (opcional)',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controllerNotas,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Cliente Potencial'),
                  value: esPotencial,
                  onChanged: (value) =>
                      setStateDialog(() => esPotencial = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controllerNombre.text.isNotEmpty &&
                    controllerContacto.text.isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final clienteId = await _clienteDao.insertCliente(
          ClientesCompanion.insert(
            nombre: controllerNombre.text,
            contacto: Value(controllerContacto.text),
            email: controllerEmail.text.isEmpty
                ? const Value.absent()
                : Value(controllerEmail.text),
            esPotencial: Value(esPotencial),
            notas: controllerNotas.text.isEmpty
                ? const Value.absent()
                : Value(controllerNotas.text),
            estadoPago: Value('pendiente'),
            fechaCreacion: Value(DateTime.now()),
          ),
        );

        await _cargarClientes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear cliente: $e')),
          );
        }
      }
    }
  }

  Future<void> _mostrarDialogoActualizarEstado(models.Cliente cliente) async {
    models.EstadoPago nuevoEstado = cliente.estadoPago;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Actualizar Estado de Pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: models.EstadoPago.values.map((estado) {
              return RadioListTile<models.EstadoPago>(
                title: Text(estado.toString().split('.').last),
                value: estado,
                groupValue: nuevoEstado,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => nuevoEstado = value);
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await _clienteDao.registrarCambioEstado(
          cliente.id,
          cliente.estadoPago.toString().split('.').last,
          nuevoEstado.toString().split('.').last,
        );

        await _clienteDao.updateCliente(
          ClientesCompanion(
            id: Value(cliente.id),
            nombre: Value(cliente.nombre),
            contacto: Value(cliente.contacto),
            email: Value(cliente.email),
            esPotencial: Value(cliente.esPotencial),
            notas: Value(cliente.notas),
            estadoPago: Value(nuevoEstado.toString().split('.').last),
          ),
        );

        await _cargarClientes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar estado: $e')),
          );
        }
      }
    }
  }

  Future<void> _mostrarDialogoEliminar(models.Cliente cliente) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Eliminar Cliente'),
        content: Text('¿Estás seguro de eliminar a ${cliente.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _clienteDao.deleteCliente(cliente.id);
        await _cargarClientes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar cliente: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Clientes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<FiltroClientes>(
              value: _filtroActual,
              items: FiltroClientes.values.map((filtro) {
                return DropdownMenuItem(
                  value: filtro,
                  child: Text(
                    filtro.toString().split('.').last,
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filtroActual = value);
                }
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clientesFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color:
                            Theme.of(context).iconTheme.color?.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filtroActual == FiltroClientes.potenciales
                            ? 'No hay clientes potenciales aún'
                            : 'No hay clientes',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clientesFiltrados.length,
                  itemBuilder: (context, index) {
                    final cliente = _clientesFiltrados[index];
                    final isPhone =
                        RegExp(r'^\+?[\d\s-]{8,}$').hasMatch(cliente.contacto);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      color: cliente.esPotencial
                          ? Theme.of(context).primaryColor.withOpacity(0.08)
                          : Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              color: Theme.of(context)
                                                  .iconTheme
                                                  .color,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              cliente.nombre,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (isPhone)
                                        GestureDetector(
                                          onTap: () async {
                                            final phone = cliente.contacto
                                                .replaceAll(
                                                    RegExp(r'[^\d]'), '');
                                            final url = Uri.parse(
                                                'https://wa.me/$phone');
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(url,
                                                  mode: LaunchMode
                                                      .externalApplication);
                                            }
                                          },
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF67C3F3)
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: FaIcon(
                                                  FontAwesomeIcons.whatsapp,
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Color(0xFF67C3F3)
                                                      : Color(0xFF25D366),
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                cliente.contacto,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge,
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (!isPhone)
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .iconTheme
                                                    .color
                                                    ?.withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.phone,
                                                color: Theme.of(context)
                                                    .iconTheme
                                                    .color,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              cliente.contacto,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                            ),
                                          ],
                                        ),
                                      if (cliente.email != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .iconTheme
                                                    .color
                                                    ?.withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.email,
                                                color: Theme.of(context)
                                                    .iconTheme
                                                    .color,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                cliente.email!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      alignment: Alignment.topCenter,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getColorEstado(
                                                cliente.estadoPago, context)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getColorEstado(
                                              cliente.estadoPago, context),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        cliente.estadoPago
                                            .toString()
                                            .split('.')
                                            .last,
                                        style: TextStyle(
                                          color: _getColorEstado(
                                              cliente.estadoPago, context),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (cliente.notas != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .iconTheme
                                      .color
                                      ?.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.note,
                                      color: Theme.of(context).iconTheme.color,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cliente.notas!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _mostrarDialogoActualizarEstado(
                                              cliente),
                                      icon: const Icon(Icons.update, size: 16),
                                      label: const Text('Estado'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.1),
                                        foregroundColor:
                                            Theme.of(context).primaryColor,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _mostrarDialogoEliminar(cliente),
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.red.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNuevoCliente,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Widget separado para búsqueda de contactos optimizada
class _ContactSearchDialog extends StatefulWidget {
  @override
  _ContactSearchDialogState createState() => _ContactSearchDialogState();
}

class _ContactSearchDialogState extends State<_ContactSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Contact> _contactos = [];
  List<Contact> _contactosFiltrados = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.length >= 1) {
      if (!_hasSearched) {
        _buscarContactos();
      } else {
        _filtrarContactos(query);
      }
    } else {
      setState(() {
        _contactosFiltrados = [];
      });
    }
  }

  Future<void> _buscarContactos() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Cargar TODOS los contactos con propiedades básicas
      final contactos = await FlutterContacts.getContacts(
        withProperties: true, // Cargar propiedades para búsqueda completa
        withPhoto: false, // Sin fotos para mayor velocidad
      );

      setState(() {
        _contactos = contactos; // No limitar aquí, filtrar después
        _filtrarContactos(_searchController.text.toLowerCase());
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar contactos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filtrarContactos(String query) {
    if (query.isEmpty) {
      setState(() {
        _contactosFiltrados = [];
      });
      return;
    }

    final filtrados = _contactos
        .where((contacto) {
          // Buscar en nombre
          final nombre = contacto.displayName.toLowerCase();
          if (nombre.contains(query)) return true;

          // Buscar en teléfonos
          for (final phone in contacto.phones) {
            if (phone.number.toLowerCase().contains(query)) return true;
          }

          // Buscar en emails
          for (final email in contacto.emails) {
            if (email.address.toLowerCase().contains(query)) return true;
          }

          return false;
        })
        .take(50)
        .toList(); // Mostrar hasta 50 resultados

    setState(() {
      _contactosFiltrados = filtrados;
    });
  }

  Future<void> _cargarPropiedadesContactos() async {
    // Ya no es necesario porque cargamos las propiedades desde el inicio
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.search, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Buscar Contacto'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Escribe para buscar contactos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildContactList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildContactList() {
    if (_searchController.text.length < 1) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Escribe para buscar contactos',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Busca por nombre, teléfono o email',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_isLoading && _contactosFiltrados.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando contactos...'),
            SizedBox(height: 8),
            Text(
              'Esto puede tomar unos segundos',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_contactosFiltrados.isEmpty && _hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No se encontraron contactos para "${_searchController.text}"',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Total de contactos: ${_contactos.length}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Información de resultados
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'Mostrando ${_contactosFiltrados.length} de ${_contactos.length} contactos',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Lista de contactos
        Expanded(
          child: ListView.builder(
            itemCount: _contactosFiltrados.length,
            itemBuilder: (context, index) {
              final contacto = _contactosFiltrados[index];
              final nombre = contacto.displayName.isNotEmpty
                  ? contacto.displayName
                  : 'Sin nombre';
              final telefono = contacto.phones.isNotEmpty
                  ? contacto.phones.first.number
                  : '';
              final email = contacto.emails.isNotEmpty
                  ? contacto.emails.first.address
                  : '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (telefono.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone,
                                size: 12, color: Colors.green[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                telefono,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (email.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.email,
                                size: 12, color: Colors.blue[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  onTap: () => Navigator.pop(context, contacto),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
