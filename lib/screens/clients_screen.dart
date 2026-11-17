import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:drift/drift.dart' hide Column;
import '../utils/contactos.dart';
import '../models/cliente.dart' as models;
import '../data/app_database.dart';
import '../data/capital_repository.dart';
import '../data/pedido_repository.dart';
import '../data/daos/cliente_dao.dart';
import '../models/pedido_estado.dart';
import '../data/paises_latam.dart';
import '../services/negocio_local.dart';
import '../theme/app_theme.dart';
import '../utils/moneda.dart';

enum FiltroClientes { todos, activos, potenciales, deuda }

InputDecoration _decoracionTelefono(
  PaisLatam? pais, {
  String etiqueta = 'Teléfono',
}) {
  if (pais == null) {
    return InputDecoration(
      labelText: etiqueta,
      prefixIcon: const Icon(Icons.phone),
      helperText:
          'Elegí la nacionalidad en Cambiar de moneda para ver la característica.',
    );
  }
  return InputDecoration(
    labelText: etiqueta,
    prefixIcon: const Icon(Icons.phone),
    prefixText: '${pais.prefijo} ',
    hintText: pais.ejemplo,
    helperText: '${pais.nombre}: ${pais.prefijo} ${pais.ejemplo}',
  );
}

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
  Map<String, double>? _saldosPorNombre;
  Map<String, String> _comprasPorNombre = {};
  bool _saldoNoDisponible = false;
  String _codigoMoneda = monedaPorDefecto;
  PaisLatam? _pais;
  final _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _leerMoneda();
    _clienteDao = ClienteDao(widget.database);
    _cargarClientes();
  }

  Future<void> _leerMoneda() async {
    final negocio = await NegocioStore().leer();
    final codigo = NegocioLocal.normalizarMoneda(negocio?.moneda);
    final pais = paisPorCodigo(negocio?.pais);
    if (!mounted) return;
    if (codigo == _codigoMoneda && pais?.codigo == _pais?.codigo) return;
    setState(() {
      _codigoMoneda = codigo;
      _pais = pais;
    });
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoading = true);
    try {
      final clientes = await _clienteDao.getAllClientes();
      final mapeados = clientes
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
      Map<String, double> saldos = {};
      var compras = <String, String>{};
      var saldoFallo = false;
      try {
        saldos = await _leerSaldos();
        compras = await _leerCompras();
      } catch (_) {
        saldoFallo = true;
      }
      if (!mounted) return;
      setState(() {
        _clientes = mapeados;
        _saldosPorNombre = saldos;
        _comprasPorNombre = compras;
        _saldoNoDisponible = saldoFallo;
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

  Future<Map<String, double>> _leerSaldos() async {
    final filas = await CapitalRepository(widget.database).listar();
    final resumen = CapitalRepository.resumir([
      for (final fila in filas)
        MovimientoParaResumen(
          persona: fila.persona,
          monto: fila.monto,
          tipo: fila.tipo,
        ),
    ]);
    return {
      for (final fila in resumen)
        fila.persona.trim().toLowerCase(): fila.saldoDeuda,
    };
  }

  Future<Map<String, String>> _leerCompras() async {
    final pedidos = await PedidoRepository(widget.database).listarPedidos();
    final grupos = <String, List<String>>{};
    for (final pedido in pedidos) {
      if (PedidoEstados.leer(pedido.estado) == PedidoEstado.cancelado) continue;
      final clave = pedido.clienteNombre.trim().toLowerCase();
      if (clave.isEmpty) continue;
      grupos.putIfAbsent(clave, () => []).add(
        [
          for (final item in pedido.items) '${item.nombre} x${item.cantidad}',
        ].join(', '),
      );
    }
    return {
      for (final entrada in grupos.entries)
        entrada.key: entrada.value.take(3).join(' · '),
    };
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<models.Cliente> get _clientesFiltrados {
    Iterable<models.Cliente> base = _clientes;
    switch (_filtroActual) {
      case FiltroClientes.activos:
        base = base.where((c) => !c.esPotencial);
        break;
      case FiltroClientes.potenciales:
        base = base.where((c) => c.esPotencial);
        break;
      case FiltroClientes.deuda:
        base = base.where((c) => _saldoDe(c.nombre) > 0);
        break;
      case FiltroClientes.todos:
        break;
    }
    final consulta = _plano(_busqueda.text);
    if (consulta.isEmpty) return base.toList();
    return [
      for (final cliente in base)
        if (_plano(
          '${cliente.nombre} ${cliente.contacto} ${cliente.email ?? ''} ${cliente.notas ?? ''}',
        ).contains(consulta))
          cliente,
    ];
  }

  double _saldoDe(String nombre) {
    if (_saldoNoDisponible) return 0;
    return _saldosPorNombre?[nombre.trim().toLowerCase()] ?? 0;
  }

  String _plano(String texto) {
    const origen = 'áéíóúüñ';
    const destino = 'aeiouun';
    var salida = texto.trim().toLowerCase();
    for (var i = 0; i < origen.length; i++) {
      salida = salida.replaceAll(origen[i], destino[i]);
    }
    return salida;
  }

  String _etiquetaFiltro(FiltroClientes filtro) {
    return switch (filtro) {
      FiltroClientes.todos => 'Todos',
      FiltroClientes.activos => 'Activos',
      FiltroClientes.potenciales => 'Potenciales',
      FiltroClientes.deuda => 'Deben',
    };
  }

  String _etiquetaEstado(models.EstadoPago estado) {
    return switch (estado) {
      models.EstadoPago.pagado => 'Pagado',
      models.EstadoPago.senalado => 'Señado',
      models.EstadoPago.pendiente => 'Pendiente',
    };
  }

  Color _colorEstado(models.EstadoPago estado) {
    return switch (estado) {
      models.EstadoPago.pagado => AppColors.verde,
      models.EstadoPago.senalado => AppColors.pendiente,
      models.EstadoPago.pendiente => AppColors.alerta,
    };
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
          controllerContacto.text = telefonoLocal(
            contactoSeleccionado.phones.first.number,
            _pais,
          );
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
                        decoration: _decoracionTelefono(_pais),
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
        await _clienteDao.insertCliente(
          ClientesCompanion.insert(
            nombre: controllerNombre.text,
            contacto: Value(telefonoConPrefijo(controllerContacto.text, _pais)),
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

  Future<void> _mostrarDialogoEditar(models.Cliente cliente) async {
    final nombreCtrl = TextEditingController(text: cliente.nombre);
    final contactoCtrl = TextEditingController(
      text: telefonoLocal(cliente.contacto, _pais),
    );
    final emailCtrl = TextEditingController(text: cliente.email ?? '');
    final notasCtrl = TextEditingController(text: cliente.notas ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: contactoCtrl,
                decoration: _decoracionTelefono(_pais, etiqueta: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final nombre = nombreCtrl.text.trim();
    final contacto = telefonoConPrefijo(contactoCtrl.text, _pais);
    final email = emailCtrl.text.trim();
    final notas = notasCtrl.text.trim();
    nombreCtrl.dispose();
    contactoCtrl.dispose();
    emailCtrl.dispose();
    notasCtrl.dispose();
    if (result != true || nombre.isEmpty || contacto.isEmpty) return;
    try {
      await _clienteDao.updateCliente(
        ClientesCompanion(
          id: Value(cliente.id),
          nombre: Value(nombre),
          contacto: Value(contacto),
          email: Value(email.isEmpty ? null : email),
          esPotencial: Value(cliente.esPotencial),
          notas: Value(notas.isEmpty ? null : notas),
          estadoPago: Value(cliente.estadoPago.toString().split('.').last),
        ),
      );
      await _cargarClientes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al editar cliente: $e')),
        );
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
                title: Text(_etiquetaEstado(estado)),
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
        final pedidos = await (widget.database.select(widget.database.pedidos)
              ..where((p) => p.clienteId.equals(cliente.id)))
            .get();
        if (pedidos.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se puede eliminar: este cliente tiene pedidos.',
                ),
              ),
            );
          }
          return;
        }
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
    final visibles = _clientesFiltrados;
    final buscando = _busqueda.text.trim().isNotEmpty;
    final deben = _clientes.where((c) => _saldoDe(c.nombre) > 0).length;
    final potenciales = _clientes.where((c) => c.esPotencial).length;
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Clientes',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'anadir-cliente',
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: _mostrarDialogoNuevoCliente,
        icon: const Icon(Icons.add),
        label: const Text(
          'Añadir cliente',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_clientes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: TextField(
                      controller: _busqueda,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: buscando
                            ? IconButton(
                                tooltip: 'Borrar',
                                onPressed: () {
                                  _busqueda.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (_clientes.isNotEmpty)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      children: [
                        for (final filtro in FiltroClientes.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_etiquetaFiltro(filtro)),
                              selected: _filtroActual == filtro,
                              onSelected: (_) =>
                                  setState(() => _filtroActual = filtro),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarClientes,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        if (_clientes.isNotEmpty && !buscando) ...[
                          DecoratedBox(
                            decoration: AppColors.tarjeta,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  _datoResumen('Clientes', '${_clientes.length}'),
                                  _datoResumen('Deben', '$deben'),
                                  _datoResumen('Potenciales', '$potenciales'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        DecoratedBox(
                          decoration: AppColors.tarjeta,
                          child: _clientes.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'Todavía no hay clientes. Tocá Añadir cliente para cargar el primero.',
                                    style: TextStyle(
                                      color: AppColors.textoSuave,
                                      height: 1.35,
                                    ),
                                  ),
                                )
                              : visibles.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        buscando
                                            ? 'Ningún cliente coincide con la búsqueda.'
                                            : 'No hay clientes en este filtro.',
                                        style: const TextStyle(
                                          color: AppColors.textoSuave,
                                          height: 1.35,
                                        ),
                                      ),
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Column(
                                        children: [
                                          for (var i = 0; i < visibles.length; i++) ...[
                                            if (i > 0)
                                              const Divider(
                                                height: 1,
                                                indent: 66,
                                                color: AppColors.linea,
                                              ),
                                            _filaCliente(visibles[i]),
                                          ],
                                        ],
                                      ),
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _datoResumen(String titulo, String valor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _filaCliente(models.Cliente cliente) {
    final saldo = _saldoDe(cliente.nombre);
    final inicial = cliente.nombre.trim().isEmpty
        ? '?'
        : cliente.nombre.trim()[0].toUpperCase();
    final detalle = cliente.contacto.isEmpty ? 'Sin teléfono' : cliente.contacto;
    return InkWell(
      onTap: () => _abrirCliente(cliente),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cliente.esPotencial
                  ? AppColors.limaBrillo
                  : const Color(0xFFE8EEFF),
              child: Text(
                inicial,
                style: TextStyle(
                  color: cliente.esPotencial ? AppColors.verde : AppColors.primario,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cliente.esPotencial ? 'Potencial · $detalle' : detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (saldo > 0)
              Text(
                formatearMoneda(saldo, _codigoMoneda),
                style: const TextStyle(
                  color: AppColors.alerta,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              )
            else
              Text(
                _etiquetaEstado(cliente.estadoPago),
                style: TextStyle(
                  color: _colorEstado(cliente.estadoPago),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirCliente(models.Cliente cliente) async {
    final saldo = _saldoDe(cliente.nombre);
    final compras =
        _comprasPorNombre[cliente.nombre.trim().toLowerCase()] ?? '';
    final esTelefono = cliente.contacto.isNotEmpty &&
        RegExp(r'^\+?[\d\s-]{8,}$').hasMatch(cliente.contacto);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.linea,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                  child: Text(
                    cliente.nombre,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                if (cliente.contacto.isNotEmpty)
                  _lineaFicha(Icons.phone_outlined, cliente.contacto),
                if ((cliente.email ?? '').isNotEmpty)
                  _lineaFicha(Icons.mail_outline, cliente.email!),
                if ((cliente.notas ?? '').isNotEmpty)
                  _lineaFicha(Icons.notes_rounded, cliente.notas!),
                _lineaFicha(
                  Icons.payments_outlined,
                  _saldoNoDisponible
                      ? 'Saldo a cobrar: no se pudo calcular'
                      : 'Saldo a cobrar: ${formatearMoneda(saldo, _codigoMoneda)}',
                ),
                if (compras.isNotEmpty) _lineaFicha(Icons.shopping_bag_outlined, compras),
                const Divider(height: 16, color: AppColors.linea),
                if (esTelefono)
                  ListTile(
                    leading: const FaIcon(FontAwesomeIcons.whatsapp, color: AppColors.verde),
                    title: const Text('WhatsApp'),
                    onTap: () async {
                      Navigator.pop(sheet);
                      final phone = cliente.contacto.replaceAll(RegExp(r'[^\d]'), '');
                      final url = Uri.parse('https://wa.me/$phone');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                if (esTelefono)
                  ListTile(
                    leading: const Icon(Icons.call_outlined, color: AppColors.primario),
                    title: const Text('Llamar'),
                    onTap: () async {
                      Navigator.pop(sheet);
                      final phone = cliente.contacto.replaceAll(RegExp(r'[^\d+]'), '');
                      final url = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.primario),
                  title: const Text('Editar'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _mostrarDialogoEditar(cliente);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.flag_outlined, color: _colorEstado(cliente.estadoPago)),
                  title: Text('Estado: ${_etiquetaEstado(cliente.estadoPago)}'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _mostrarDialogoActualizarEstado(cliente);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.alerta),
                  title: const Text('Eliminar'),
                  onTap: () {
                    Navigator.pop(sheet);
                    _mostrarDialogoEliminar(cliente);
                  },
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _lineaFicha(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: AppColors.textoSuave),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: AppColors.texto, height: 1.3),
            ),
          ),
        ],
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
                            Icon(Icons.email, size: 12, color: AppColors.azul),
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
