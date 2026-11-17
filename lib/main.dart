import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data/database_connection.dart';
import 'screens/clients_screen.dart';
import 'screens/capital_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/pedidos_screen.dart';
import 'screens/deudores_screen.dart';
import 'screens/chat_ia_screen.dart';
import 'screens/tienda_screen.dart';
import 'screens/resumen_ventas_screen.dart';
import 'screens/login_screen.dart';
import 'screens/asistente_bienvenida_screen.dart';
import 'screens/negocio_inicial_screen.dart';
import 'screens/configuracion_web_screen.dart';
import 'screens/equipo_screen.dart';
import 'screens/actividad_screen.dart';
import 'screens/categorias_screen.dart';
import 'screens/cierre_caja_screen.dart';
import 'screens/pais_moneda_screen.dart';
import 'screens/promocion_pagina_screen.dart';
import 'screens/tienda_publica_screen.dart';
import 'services/avisos/avisos_pedido_tienda.dart';
import 'services/acceso_app.dart';
import 'services/negocio_local.dart';
import 'services/ruta_navegador_stub.dart'
    if (dart.library.js_interop) 'services/ruta_navegador_web.dart';
import 'services/subdominio_tienda.dart';
import 'backend/catalogo_remoto.dart';
import 'backend/negocio_remoto.dart';
import 'backend/remoto_comun.dart';
import 'backend/sesion_remota.dart';
import 'backend/sincronizar_negocio.dart';
import 'backend/supabase_cliente.dart';
import 'data/app_database.dart';
import 'services/sesion_google.dart';
import 'data/resumen_ventas.dart';
import 'backend/tienda_publica_remota.dart';
import 'theme/app_theme.dart';
import 'utils/moneda.dart';
import 'widgets/fondo_gexi.dart';
import 'widgets/dialogo_borrar_cuenta.dart';
import 'widgets/logo_gexi.dart';
import 'widgets/soporte_whatsapp.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseListo.iniciar();
  final database = AppDatabase(openDatabaseConnection());
  AvisosPedidoTienda.usarBase(database);
  await AvisosPedidoTienda.iniciar();
  NegocioStore.alPublicar = (negocio) => const NegocioRemoto().publicar(negocio);
  NegocioStore.alGuardarCatalogo = CatalogoRemoto.publicarCategorias;
  CatalogoRemoto.leerProducto = (id) async {
    final filas = await database.select(database.productos).get();
    for (final fila in filas) {
      if (fila.id != id) continue;
      return (
        nombre: fila.nombre,
        compra: fila.precioCompra,
        venta: fila.precioVenta,
      );
    }
    return null;
  };

  runApp(
    DevicePreview(
      enabled: !kReleaseMode && !kIsWeb,
      builder: (context) => MyApp(database: database),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppDatabase database;

  const MyApp({
    super.key,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    final slugPublico = kIsWeb
        ? (SubdominioTienda.slugDesdeHost(Uri.base.host) ??
            SubdominioTienda.slugDesdeRuta(rutaDelNavegador()))
        : null;
    return MaterialApp(
      title: 'Gexi',
      locale: DevicePreview.locale(context),
      builder: (context, child) {
        final contenido = child ?? const SizedBox.shrink();
        return DevicePreview.appBuilder(
          context,
          slugPublico == null ? _MarcoPc(child: contenido) : contenido,
        );
      },
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.light,
      home: slugPublico == null
          ? _PuertaAcceso(database: database)
          : TiendaPublicaScreen(slug: slugPublico),
    );
  }
}

/// En una computadora el negocio se usa en una columna. En el celular ocupa toda la pantalla.
class _MarcoPc extends StatelessWidget {
  const _MarcoPc({required this.child});

  final Widget child;

  static const _ancho = 440.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final ancho = limites.maxWidth;
        if (ancho < 760 || !ancho.isFinite) return child;
        final alto = limites.maxHeight;
        return ColoredBox(
          color: const Color(0xFFE7EEF2),
          child: Center(
            child: SizedBox(
              width: _ancho,
              height: alto,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(_ancho, alto),
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A0E3154),
                        blurRadius: 28,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PuertaAcceso extends StatefulWidget {
  const _PuertaAcceso({required this.database});

  final AppDatabase database;

  @override
  State<_PuertaAcceso> createState() => _PuertaAccesoState();
}

class _PuertaAccesoState extends State<_PuertaAcceso> {
  SesionGoogle? _sesion;
  NegocioLocal? _negocio;
  bool _lista = false;
  bool _creando = false;
  String _whatsappDueno = '';

  @override
  void initState() {
    super.initState();
    _recuperar();
  }

  Future<void> _recuperar() async {
    var sesion = await AuthGoogle.instancia.leer();
    if (sesion == null) {
      final usuario = SupabaseListo.cliente?.auth.currentUser;
      final email = usuario?.email?.trim() ?? '';
      if (email.isNotEmpty && usuario?.emailConfirmedAt != null) {
        sesion = await AuthGoogle.instancia.entrarConCorreo(email);
      }
    }
    if (sesion != null) {
      await AuthGoogle.instancia.asegurarSupabase();
    }
    final negocio = await _negocioDeEstaCuenta();
    unawaited(const AccesoApp().anotarSiCorresponde());
    if (!mounted) return;
    setState(() {
      _sesion = sesion;
      _negocio = negocio;
      _lista = true;
    });
  }

  Future<void> _entrarConGoogle(SesionGoogle sesion) async {
    final negocio = await _negocioDeEstaCuenta();
    unawaited(const AccesoApp().anotarSiCorresponde());
    if (!mounted) return;
    setState(() {
      _sesion = sesion;
      _negocio = negocio;
    });
  }

  Future<void> _entrarConCorreo(String correo) async {
    final sesion = await AuthGoogle.instancia.entrarConCorreo(correo);
    final negocio = await _negocioDeEstaCuenta();
    unawaited(const AccesoApp().anotarSiCorresponde());
    if (!mounted) return;
    setState(() {
      _sesion = sesion;
      _negocio = negocio;
    });
  }

  /// El negocio de esta sesión. Si el teléfono tiene el de otra cuenta, busca el de la nube.
  Future<NegocioLocal?> _negocioDeEstaCuenta() async {
    final sesion = await AuthGoogle.instancia.leer();
    final email = sesion?.email ?? '';
    final actual = await NegocioStore().leer();
    if (actual != null && _cuentaDelNegocio(actual, email)) return actual;
    try {
      final remoto = await const NegocioRemoto().delDueno() ??
          await const NegocioRemoto().delEquipo();
      if (remoto != null) {
        await NegocioStore().guardarLocal(remoto);
        return remoto;
      }
    } catch (_) {}
    if (actual != null && email.isEmpty) return actual;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_lista) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final sesion = _sesion;
    if (sesion == null) {
      return LoginScreen(
        alEntrar: (nueva) {
          unawaited(_entrarConGoogle(nueva));
        },
        alContinuar: _entrarConCorreo,
      );
    }
    final negocio = _negocio;
    final miembro = negocio?.miembroConEmail(sesion.email);
    if (negocio != null &&
        !_mismoDueno(negocio.duenoEmail, sesion.email) &&
        miembro != null &&
        !miembro.activo) {
      return _AccesoInactivo(
        alSalir: () async {
          await AuthGoogle.instancia.salir();
          await const SesionRemota().salir();
          if (!mounted) return;
          setState(() => _sesion = null);
        },
      );
    }
    final esDueno =
        negocio != null && _mismoDueno(negocio.duenoEmail, sesion.email);
    final entraComoEmpleado = negocio != null &&
        negocio.configurado &&
        miembro != null &&
        miembro.activo;
    if (_creando ||
        (negocio != null && esDueno && negocio.necesitaAsistente)) {
      return AsistenteBienvenidaScreen(
        key: const ValueKey('asistente-bienvenida'),
        negocio: esDueno ? negocio : null,
        duenoEmail: sesion.email,
        whatsappInicial: _whatsappDueno,
        alActualizar: (actualizado) => setState(() {
          _negocio = actualizado;
          _creando = false;
        }),
        alVolverAlInicio: () => setState(() => _creando = false),
      );
    }
    if (negocio == null || (!esDueno && !entraComoEmpleado)) {
      return CrearNegocioScreen(
        duenoEmail: sesion.email,
        alEmpezar: (whatsapp) => setState(() {
          _creando = true;
          _whatsappDueno = whatsapp;
        }),
        alUnirse: (unido) => setState(() => _negocio = unido),
      );
    }
    return MyHomePage(
      database: widget.database,
      sesion: sesion,
      negocio: negocio,
      alCerrarSesion: () async {
        await AuthGoogle.instancia.salir();
        await const SesionRemota().salir();
        if (!mounted) return;
        setState(() => _sesion = null);
      },
    );
  }
}

class _AccesoInactivo extends StatelessWidget {
  const _AccesoInactivo({required this.alSalir});

  final Future<void> Function() alSalir;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: FondoGexi(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  'Tu acceso está inactivo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Un administrador tiene que activarte de nuevo para entrar con tu código de empleado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                ),
                const Spacer(),
                TextButton(
                  onPressed: alSalir,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _administra(NegocioLocal negocio, String email) {
  if (_mismoDueno(negocio.duenoEmail, email)) return true;
  final miembro = negocio.miembroConEmail(email);
  return miembro != null && miembro.activo && miembro.rol == 'administrador';
}

String _textoCodigo(NegocioLocal negocio, String email) {
  if (_mismoDueno(negocio.duenoEmail, email)) {
    return 'Código del negocio ${negocio.codigo}';
  }
  final miembro = negocio.miembroConEmail(email);
  if (miembro == null) return 'Código del negocio ${negocio.codigo}';
  return '${miembro.etiquetaRol} · ${miembro.codigo}';
}

bool _cuentaDelNegocio(NegocioLocal negocio, String email) {
  final clave = email.trim().toLowerCase();
  if (clave.isEmpty) return false;
  if (_mismoDueno(negocio.duenoEmail, clave)) return true;
  final miembro = negocio.miembroConEmail(clave);
  return miembro != null && miembro.activo;
}

bool _mismoDueno(String duenoEmail, String emailSesion) {
  final dueno = duenoEmail.trim().toLowerCase();
  if (dueno.isEmpty) return false;
  return dueno == emailSesion.trim().toLowerCase();
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.database,
    required this.sesion,
    required this.negocio,
    required this.alCerrarSesion,
  });

  final AppDatabase database;
  final SesionGoogle sesion;
  final NegocioLocal negocio;
  final Future<void> Function() alCerrarSesion;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_prepararDatos());
  }

  Future<void> _prepararDatos() async {
    try {
      await RemotoComun.enSerie(
        () => SincronizarNegocio.traer(widget.database),
      );
    } catch (error) {
      debugPrint('Gexi: no se pudo preparar la muestra: $error');
    }
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return _Inicio(
          sesion: widget.sesion,
          negocio: widget.negocio,
          database: widget.database,
          alAbrirPedidos: () => setState(() => _selectedIndex = 1),
          alAbrirStock: () => setState(() => _selectedIndex = 2),
          alAbrirClientes: () => _abrir(ClientsScreen(database: widget.database)),
          alAbrirAsistente: _abrirAsistente,
          alAbrirCapital: () => _abrir(CapitalScreen(database: widget.database)),
          alAbrirTienda: () => _abrir(TiendaScreen(database: widget.database)),
          alAbrirVentas: () => _abrir(ResumenVentasScreen(database: widget.database)),
          alAbrirPagina: () => _abrir(
            ConfiguracionWebScreen(database: widget.database),
          ),
          alAbrirCategorias: () => _abrir(const CategoriasScreen()),
          alAbrirCierre: () => _abrir(CierreCajaScreen(database: widget.database)),
        );
      case 1:
        return PedidosScreen(database: widget.database);
      case 2:
        return StockScreen(database: widget.database);
      case 3:
        return _Mas(
          sesion: widget.sesion,
          negocio: widget.negocio,
          alAbrirClientes: () => _abrir(ClientsScreen(database: widget.database)),
          alAbrirCapital: () => _abrir(CapitalScreen(database: widget.database)),
          alAbrirDeudores: () => _abrir(DeudoresScreen(database: widget.database)),
          alAbrirAsistente: _abrirAsistente,
          alAbrirTienda: () => _abrir(TiendaScreen(database: widget.database)),
          alAbrirVentas: () => _abrir(ResumenVentasScreen(database: widget.database)),
          alAbrirPagina: () => _abrir(
            ConfiguracionWebScreen(database: widget.database),
          ),
          alAbrirPromocion: () => _abrir(const PromocionPaginaScreen()),
          alAbrirEquipo: () => _abrir(const EquipoScreen()),
          alAbrirActividad: () =>
              _abrir(ActividadScreen(database: widget.database)),
          alAbrirCategorias: () => _abrir(const CategoriasScreen()),
          alAbrirCierre: () => _abrir(CierreCajaScreen(database: widget.database)),
          alAbrirPais: () => _abrir(
            PaisMonedaScreen(database: widget.database),
          ),
          alCerrarSesion: widget.alCerrarSesion,
          alBorrarCuenta: _borrarCuenta,
        );
      default:
        return const Center(child: Text('Pantalla no encontrada'));
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _abrir(Widget pantalla) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => pantalla),
    );
  }

  void _abrirAsistente() {
    _abrir(ChatIaScreen(database: widget.database));
  }

  Future<void> _borrarCuenta() async {
    final confirmo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DialogoBorrarCuenta(),
    );
    if (confirmo != true || !mounted) return;
    await widget.database.vaciar();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await widget.alCerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final conFondo = _selectedIndex == 0 || _selectedIndex == 3;
    final contenido = _buildScreen(_selectedIndex);
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: conFondo ? FondoGexi(child: SafeArea(child: contenido)) : contenido,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}

class _ResumenVentasInicio extends StatefulWidget {
  const _ResumenVentasInicio({
    required this.database,
    required this.slug,
    required this.onTap,
  });

  final AppDatabase database;
  final String slug;
  final VoidCallback onTap;

  @override
  State<_ResumenVentasInicio> createState() => _ResumenVentasInicioState();
}

class _ResumenVentasInicioState extends State<_ResumenVentasInicio> {
  late final Future<_CifrasInicio> _carga;

  @override
  void initState() {
    super.initState();
    _carga = _cargar();
  }

  Future<_CifrasInicio> _cargar() async {
    final codigo = await monedaDelNegocio();
    final ventas = await ResumenVentasConsulta(widget.database).cargar(
      limiteUltimas: 1,
    );
    final visitas = await const TiendaPublicaRemota().visitasDeMiPagina(
      widget.slug,
    );
    return _CifrasInicio(moneda: codigo, ventas: ventas, visitas: visitas);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CifrasInicio>(
      future: _carga,
      builder: (context, snapshot) {
        final cifras = snapshot.data;
        final moneda = cifras?.moneda ?? monedaPorDefecto;
        final ventas = cifras?.ventas ?? ResumenVentasDatos.vacio;
        final visitas = cifras?.visitas ?? (hoy: 0, mes: 0);
        return DecoratedBox(
          decoration: AppColors.tarjeta,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              child: Column(
                children: [
                  _filaInicio(
                    icono: Icons.today_rounded,
                    color: AppColors.primario,
                    titulo: 'Hoy',
                    detalle: _pedidos(ventas.hoy.cantidadPedidos),
                    valor: formatearMoneda(ventas.hoy.monto, moneda),
                  ),
                  const Divider(height: 1, indent: 36, color: AppColors.linea),
                  _filaInicio(
                    icono: Icons.calendar_month_rounded,
                    color: AppColors.lima,
                    titulo: 'Este mes',
                    detalle: _pedidos(ventas.mesActual.cantidadPedidos),
                    valor: formatearMoneda(ventas.mesActual.monto, moneda),
                  ),
                  const Divider(height: 1, indent: 36, color: AppColors.linea),
                  _filaInicio(
                    icono: Icons.visibility_outlined,
                    color: AppColors.teal,
                    titulo: 'Visitantes web',
                    detalle: 'este mes',
                    valor: '${visitas.mes}',
                  ),
                  const Divider(height: 1, indent: 36, color: AppColors.linea),
                  _filaInicio(
                    icono: Icons.shopping_bag_outlined,
                    color: AppColors.azulProfundo,
                    titulo: 'Pedidos',
                    detalle: _pedidos(ventas.pedidosPaginaHoy, prefijo: 'hoy'),
                    valor: '${ventas.pedidosPaginaMes}',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _pedidos(int cantidad, {String prefijo = ''}) {
    final texto = cantidad == 1 ? '1 pedido' : '$cantidad pedidos';
    return prefijo.isEmpty ? texto : '$texto $prefijo';
  }

  Widget _filaInicio({
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
    required String valor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Icon(icono, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  valor,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CifrasInicio {
  const _CifrasInicio({
    required this.moneda,
    required this.ventas,
    required this.visitas,
  });

  final String moneda;
  final ResumenVentasDatos ventas;
  final ({int hoy, int mes}) visitas;
}

class _Inicio extends StatelessWidget {
  const _Inicio({
    required this.sesion,
    required this.negocio,
    required this.database,
    required this.alAbrirPedidos,
    required this.alAbrirStock,
    required this.alAbrirClientes,
    required this.alAbrirAsistente,
    required this.alAbrirCapital,
    required this.alAbrirTienda,
    required this.alAbrirVentas,
    required this.alAbrirPagina,
    required this.alAbrirCategorias,
    required this.alAbrirCierre,
  });

  final SesionGoogle sesion;
  final NegocioLocal negocio;
  final AppDatabase database;
  final VoidCallback alAbrirPedidos;
  final VoidCallback alAbrirStock;
  final VoidCallback alAbrirClientes;
  final VoidCallback alAbrirAsistente;
  final VoidCallback alAbrirCapital;
  final VoidCallback alAbrirTienda;
  final VoidCallback alAbrirVentas;
  final VoidCallback alAbrirPagina;
  final VoidCallback alAbrirCategorias;
  final VoidCallback alAbrirCierre;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const LogoGexi(ancho: 108),
            if (_administra(negocio, sesion.email)) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _ResumenVentasInicio(
                  database: database,
                  slug: negocio.slug,
                  onTap: alAbrirVentas,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Hola, ${sesion.saludo}',
          style: tema.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          negocio.nombre,
          style: tema.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _Acceso(
              icono: Icons.receipt_long_rounded,
              titulo: 'Pedidos',
              detalle: 'Estados y señas',
              color: const Color(0xFF2563EB),
              fondo: const Color(0xFFE8F0FF),
              onTap: alAbrirPedidos,
            ),
            _Acceso(
              icono: Icons.inventory_2_rounded,
              titulo: 'Stock',
              detalle: 'Productos y cantidades',
              color: const Color(0xFFD97706),
              fondo: const Color(0xFFFFF4E5),
              onTap: alAbrirStock,
            ),
            _Acceso(
              icono: Icons.people_alt_rounded,
              titulo: 'Clientes',
              detalle: 'Contactos y pagos',
              color: const Color(0xFF14B8A6),
              fondo: const Color(0xFFE7FBF6),
              onTap: alAbrirClientes,
            ),
            _Acceso(
              icono: Icons.auto_awesome_rounded,
              titulo: 'Asistente',
              detalle: 'Preguntas del negocio',
              color: AppColors.verde,
              fondo: const Color(0xFFE8F9EE),
              onTap: alAbrirAsistente,
            ),
            _Acceso(
              icono: Icons.storefront_rounded,
              titulo: 'Tienda',
              detalle: 'Catálogo y WhatsApp',
              color: const Color(0xFF14B8A6),
              fondo: const Color(0xFFE7FBF6),
              onTap: alAbrirTienda,
            ),
            _Acceso(
              icono: Icons.insights_rounded,
              titulo: 'Ventas',
              detalle: 'Hoy, semana y mes',
              color: AppColors.primario,
              fondo: const Color(0xFFE8F0FF),
              onTap: alAbrirVentas,
            ),
            if (_administra(negocio, sesion.email))
              _Acceso(
                icono: Icons.point_of_sale_rounded,
                titulo: 'Cierre de caja',
                detalle: 'Efectivo del día',
                color: AppColors.primario,
                fondo: const Color(0xFFE8F0FF),
                onTap: alAbrirCierre,
              ),
            if (_administra(negocio, sesion.email))
              _Acceso(
                icono: Icons.category_rounded,
                titulo: 'Categorías',
                detalle: 'Orden del catálogo',
                color: AppColors.primario,
                fondo: const Color(0xFFE8F0FF),
                onTap: alAbrirCategorias,
              ),
            if (_administra(negocio, sesion.email))
              _Acceso(
                icono: Icons.language_rounded,
                titulo: 'Tu página web',
                detalle: 'Publicación y dirección',
                color: AppColors.primario,
                fondo: AppColors.limaBrillo,
                onTap: alAbrirPagina,
              ),
          ],
        ),
      ],
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.fondo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final Color fondo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppColors.tarjeta,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: fondo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icono, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mas extends StatelessWidget {
  const _Mas({
    required this.sesion,
    required this.negocio,
    required this.alAbrirClientes,
    required this.alAbrirCapital,
    required this.alAbrirDeudores,
    required this.alAbrirAsistente,
    required this.alAbrirTienda,
    required this.alAbrirVentas,
    required this.alAbrirPagina,
    required this.alAbrirPromocion,
    required this.alAbrirEquipo,
    required this.alAbrirActividad,
    required this.alAbrirCategorias,
    required this.alAbrirCierre,
    required this.alAbrirPais,
    required this.alCerrarSesion,
    required this.alBorrarCuenta,
  });

  final SesionGoogle sesion;
  final NegocioLocal negocio;
  final VoidCallback alAbrirClientes;
  final VoidCallback alAbrirCapital;
  final VoidCallback alAbrirDeudores;
  final VoidCallback alAbrirAsistente;
  final VoidCallback alAbrirTienda;
  final VoidCallback alAbrirVentas;
  final VoidCallback alAbrirPagina;
  final VoidCallback alAbrirPromocion;
  final VoidCallback alAbrirEquipo;
  final VoidCallback alAbrirActividad;
  final VoidCallback alAbrirCategorias;
  final VoidCallback alAbrirCierre;
  final VoidCallback alAbrirPais;
  final Future<void> Function() alCerrarSesion;
  final Future<void> Function() alBorrarCuenta;

  @override
  Widget build(BuildContext context) {
    final foto = sesion.fotoUrl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Text('Más', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.tarjeta,
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.limaBrillo,
                foregroundImage: foto == null ? null : NetworkImage(foto),
                child: Text(
                  sesion.saludo.isEmpty ? 'G' : sesion.saludo[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primario,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sesion.nombre,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(sesion.email, style: const TextStyle(color: AppColors.textoSuave)),
                    Text(
                      _textoCodigo(negocio, sesion.email),
                      style: const TextStyle(
                        color: AppColors.lima,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SoporteWhatsapp(),
        const SizedBox(height: 16),
        Container(
          decoration: AppColors.tarjeta,
          child: Column(
            children: [
              _Opcion(icono: Icons.people_alt_rounded, titulo: 'Clientes', color: const Color(0xFF14B8A6), fondo: const Color(0xFFE7FBF6), onTap: alAbrirClientes),
              const Divider(height: 1, indent: 68),
              _Opcion(icono: Icons.insights_rounded, titulo: 'Ventas', color: AppColors.primario, fondo: const Color(0xFFE8F0FF), onTap: alAbrirVentas),
              if (_administra(negocio, sesion.email)) ...[
                const Divider(height: 1, indent: 68),
                _Opcion(icono: Icons.category_rounded, titulo: 'Categorías', color: AppColors.primario, fondo: const Color(0xFFE8F0FF), onTap: alAbrirCategorias),
                const Divider(height: 1, indent: 68),
                _Opcion(icono: Icons.currency_exchange_rounded, titulo: 'Cambiar de moneda', color: AppColors.verde, fondo: const Color(0xFFE8F9EE), onTap: alAbrirPais),
                const Divider(height: 1, indent: 68),
                _Opcion(icono: Icons.payments_rounded, titulo: 'Capital', color: AppColors.primario, fondo: const Color(0xFFE8F0FF), onTap: alAbrirCapital),
                const Divider(height: 1, indent: 68),
                _Opcion(icono: Icons.point_of_sale_rounded, titulo: 'Cierre de caja', color: AppColors.primario, fondo: const Color(0xFFE8F0FF), onTap: alAbrirCierre),
              ],
              const Divider(height: 1, indent: 68),
              _Opcion(icono: Icons.account_balance_wallet_rounded, titulo: 'Deudores', color: const Color(0xFFD97706), fondo: const Color(0xFFFFF4E5), onTap: alAbrirDeudores),
              const Divider(height: 1, indent: 68),
              _Opcion(icono: Icons.storefront_rounded, titulo: 'Tienda', color: const Color(0xFF14B8A6), fondo: const Color(0xFFE7FBF6), onTap: alAbrirTienda),
              if (_administra(negocio, sesion.email)) ...[
                const Divider(height: 1, indent: 68),
                _Opcion(icono: Icons.language_rounded, titulo: 'Tu página web', color: AppColors.primario, fondo: AppColors.limaBrillo, onTap: alAbrirPagina),
              ],
              const Divider(height: 1, indent: 68),
              _Opcion(icono: Icons.qr_code_2_rounded, titulo: 'Promocioná tu página', color: AppColors.primario, fondo: AppColors.limaBrillo, onTap: alAbrirPromocion),
              const Divider(height: 1, indent: 68),
              _Opcion(icono: Icons.auto_awesome_rounded, titulo: 'Asistente', color: AppColors.verde, fondo: const Color(0xFFE8F9EE), onTap: alAbrirAsistente),
              if (_administra(negocio, sesion.email)) ...[
                const Divider(height: 1, indent: 68),
                _Opcion(icono: Icons.groups_rounded, titulo: 'Equipo', color: AppColors.primario, fondo: const Color(0xFFE8F0FF), onTap: alAbrirEquipo),
              ],
              const Divider(height: 1, indent: 68),
              _Opcion(icono: Icons.history_rounded, titulo: 'Actividad', color: const Color(0xFFD97706), fondo: const Color(0xFFFFF4E5), onTap: alAbrirActividad),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: alCerrarSesion,
          icon: const Icon(Icons.logout, color: AppColors.alerta),
          label: const Text('Cerrar sesión', style: TextStyle(color: AppColors.alerta)),
        ),
        TextButton.icon(
          onPressed: alBorrarCuenta,
          icon: const Icon(Icons.delete_forever_outlined, color: AppColors.alerta),
          label: const Text('Borrar cuenta', style: TextStyle(color: AppColors.alerta)),
        ),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.color,
    required this.fondo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final Color color;
  final Color fondo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: color, size: 20),
      ),
      title: Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.texto),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textoSuave),
      onTap: onTap,
    );
  }
}
