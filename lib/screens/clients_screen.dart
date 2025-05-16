import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/cliente.dart';

enum FiltroClientes { todos, activos, potenciales }

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  FiltroClientes _filtroActual = FiltroClientes.todos;

  // Lista de clientes de ejemplo
  final List<Cliente> _clientes = [
    Cliente.crear(
      nombre: 'Juan Pérez',
      contacto: '+1234567890',
      email: 'juan@email.com',
      esPotencial: false,
      notas: 'Cliente frecuente',
      estadoPago: EstadoPago.pagado,
    ),
    Cliente.crear(
      nombre: 'María García',
      contacto: '+0987654321',
      esPotencial: true,
      notas: 'Interesada en productos premium',
      estadoPago: EstadoPago.senalado,
    ),
    Cliente.crear(
      nombre: 'Carlos López',
      contacto: '+1122334455',
      email: 'carlos@email.com',
      esPotencial: true,
      estadoPago: EstadoPago.pendiente,
    ),
  ];

  List<Cliente> get _clientesFiltrados {
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

  void _mostrarDialogoNuevoCliente() {
    final controllerNombre = TextEditingController();
    final controllerContacto = TextEditingController();
    final controllerEmail = TextEditingController();
    final controllerNotas = TextEditingController();
    bool esPotencial = false;

    showDialog(
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
                TextField(
                  controller: controllerContacto,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controllerNombre.text.isNotEmpty &&
                    controllerContacto.text.isNotEmpty) {
                  setState(() {
                    _clientes.add(
                      Cliente.crear(
                        nombre: controllerNombre.text,
                        contacto: controllerContacto.text,
                        email: controllerEmail.text.isEmpty
                            ? null
                            : controllerEmail.text,
                        esPotencial: esPotencial,
                        notas: controllerNotas.text.isEmpty
                            ? null
                            : controllerNotas.text,
                        estadoPago: EstadoPago.pendiente,
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoActualizarEstado(Cliente cliente) {
    EstadoPago nuevoEstado = cliente.estadoPago;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Actualizar Estado de Pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: EstadoPago.values.map((estado) {
              return RadioListTile<EstadoPago>(
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final index = _clientes.indexWhere((c) => c.id == cliente.id);
                  if (index != -1) {
                    _clientes[index] =
                        cliente.copyWith(estadoPago: nuevoEstado);
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEliminar(Cliente cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Eliminar Cliente'),
        content: Text('¿Estás seguro de eliminar a ${cliente.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _clientes.removeWhere((c) => c.id == cliente.id);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
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
      body: _clientesFiltrados.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _filtroActual == FiltroClientes.potenciales
                        ? 'No hay clientes potenciales aún'
                        : 'No hay clientes',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                          color:
                                              Theme.of(context).iconTheme.color,
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
                                            .replaceAll(RegExp(r'[^\d]'), '');
                                        final url =
                                            Uri.parse('https://wa.me/$phone');
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
                                            padding: const EdgeInsets.all(8),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .iconTheme
                                  .color
                                  ?.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.note,
                                  color: Theme.of(context).iconTheme.color,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cliente.notas!,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _mostrarDialogoActualizarEstado(cliente),
                              icon: Icon(Icons.update,
                                  color: Theme.of(context).iconTheme.color),
                              label: const Text('Actualizar Estado'),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _mostrarDialogoEliminar(cliente),
                              icon: Icon(Icons.delete_outline,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Color(0xFFE53935)
                                      : Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevoCliente,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Cliente'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Color _getColorEstado(EstadoPago estado, BuildContext context) {
    switch (estado) {
      case EstadoPago.pendiente:
        return Theme.of(context).brightness == Brightness.dark
            ? Color(0xFFFBC02D)
            : Colors.orange;
      case EstadoPago.senalado:
        return Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2196F3)
            : Colors.blue;
      case EstadoPago.pagado:
        return Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2E7D32)
            : Colors.green;
    }
  }
}
