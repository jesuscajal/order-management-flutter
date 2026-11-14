import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/remoto_comun.dart';
import '../../backend/sincronizar_negocio.dart';
import '../../backend/supabase_cliente.dart';
import '../../data/app_database.dart';
import '../../utils/moneda.dart';
import '../negocio_local.dart';

/// Aviso local cuando entra un pedido de la página (`origen` tienda / `categoria` web).
///
/// Canal Realtime `pedidos-tienda-{negocioId}`: INSERT de `public.pedidos` filtrado
/// por el `negocio_id` de la sesión. El mismo canal baja ese pedido a Drift y
/// avisa a la pantalla de Pedidos. No abre un segundo websocket.
/// En segundo plano el aviso sale mientras el proceso sigue vivo. Si la cierran del
/// todo, o Android mata el proceso, el websocket no llega: no hay Firebase ni un
/// isolate en segundo plano. El sondeo de abajo cubre ese hueco: solo pide los
/// pedidos nuevos de la página, no el catálogo entero.
class AvisosPedidoTienda {
  const AvisosPedidoTienda._();

  static const _canalId = 'pedidos_tienda';
  static const _canalNombre = 'Pedidos de la página';
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _observador = _Observador();
  static final _pantalla = StreamController<void>.broadcast();

  static RealtimeChannel? _canal;
  static Timer? _sondeo;
  static Timer? _esperaNegocio;
  static Future<void> _serie = Future<void>.value();
  static AppDatabase? _base;

  static var _arranco = false;
  static var _escuchando = false;
  static var _pluginListo = false;
  static var _unido = false;
  static var _sondeando = false;
  static var _intentosNegocio = 0;
  static String? _negocioActivo;
  static String? _marcaDelNegocio;
  static String? _baseId;
  static DateTime? _desde;
  static final _vistos = <String>{};
  static final _enLista = <String>{};
  static final _bajando = <String>{};

  /// La pantalla de Pedidos se vuelve a leer cuando entra uno de la página.
  static Stream<void> get alLlegar => _pantalla.stream;

  static void usarBase(AppDatabase base) {
    _base = base;
  }

  static Future<void> iniciar() async {
    if (_arranco) return;
    _arranco = true;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    WidgetsBinding.instance.addObserver(_observador);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_enganchar());
    });
  }

  static Future<void> _alVolver() async {
    _intentosNegocio = 0;
    await _enSerie(_asegurarCanal);
    await _sondear();
  }

  static Future<void> _enganchar() async {
    if (_escuchando) return;
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return;
    _escuchando = true;
    cliente.auth.onAuthStateChange.listen((dato) {
      if (dato.event == AuthChangeEvent.signedOut) {
        unawaited(_enSerie(_cerrar));
        return;
      }
      if (dato.session != null) {
        unawaited(_enSerie(_asegurarCanal));
      }
    });
    if (cliente.auth.currentSession != null) {
      await _enSerie(_asegurarCanal);
    }
  }

  static Future<void> _enSerie(Future<void> Function() accion) {
    final siguiente = _serie.then((_) => accion());
    _serie = siguiente.then<void>((_) {}, onError: (_, __) {});
    return siguiente;
  }

  static Future<void> _asegurarCanal() async {
    final cliente = RemotoComun.cliente;
    if (cliente == null) {
      await _cerrar();
      return;
    }
    final negocioId = await RemotoComun.negocioId();
    if (negocioId == null || negocioId.isEmpty) {
      _reintentarNegocio();
      return;
    }
    _intentosNegocio = 0;
    _esperaNegocio?.cancel();
    _esperaNegocio = null;
    if (_negocioActivo != negocioId || !_unido || _canal == null) {
      await _suscribir(cliente, negocioId);
      return;
    }
    _arrancarSondeo();
  }

  static void _reintentarNegocio() {
    if (_esperaNegocio != null || _intentosNegocio >= 12) return;
    _intentosNegocio++;
    _esperaNegocio = Timer(const Duration(seconds: 5), () {
      _esperaNegocio = null;
      unawaited(_enSerie(_asegurarCanal));
    });
  }

  static Future<void> _suscribir(SupabaseClient cliente, String negocioId) async {
    await _prepararPlugin();
    final anterior = _canal;
    _canal = null;
    _unido = false;
    if (anterior != null) {
      try {
        await cliente.removeChannel(anterior);
      } catch (_) {}
    }
    _negocioActivo = negocioId;
    if (_marcaDelNegocio != negocioId) {
      await _tomarLineaBase(cliente, negocioId);
      _marcaDelNegocio = negocioId;
    }
    final canal = cliente.channel('pedidos-tienda-$negocioId');
    canal.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'pedidos',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'negocio_id',
        value: negocioId,
      ),
      callback: (payload) {
        unawaited(_alInsert(payload));
      },
    );
    canal.subscribe((status, _) {
      _unido = status == RealtimeSubscribeStatus.subscribed;
    });
    _canal = canal;
    _arrancarSondeo();
  }

  /// No avisa pedidos que ya estaban. La marca sale del reloj del servidor.
  static Future<void> _tomarLineaBase(
    SupabaseClient cliente,
    String negocioId,
  ) async {
    _desde = null;
    final filas = await cliente
        .from('pedidos')
        .select('id, creado_en')
        .eq('negocio_id', negocioId)
        .or('origen.eq.tienda,categoria.eq.web')
        .order('creado_en', ascending: false)
        .limit(1);
    if (filas.isEmpty) return;
    final fila = _mapa(filas.first);
    final id = textoRemoto(fila['id']);
    if (id.isNotEmpty) _vistos.add(id);
    _baseId = id.isEmpty ? null : id;
    _desde = DateTime.tryParse(textoRemoto(fila['creado_en']))?.toUtc();
    if (_baseId != null) unawaited(_meterEnLista(fila));
  }

  static void _arrancarSondeo() {
    if (_sondeo != null) return;
    _sondeo = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_sondear());
    });
    unawaited(_sondear());
  }

  static Future<void> _sondear() async {
    if (_sondeando) return;
    final cliente = RemotoComun.cliente;
    final negocioId = _negocioActivo;
    if (cliente == null || negocioId == null || negocioId.isEmpty) return;
    _sondeando = true;
    try {
      final baseId = _baseId;
      if (baseId != null && !_enLista.contains(baseId)) {
        final entro = await _meterEnLista({
          'id': baseId,
          'origen': 'tienda',
          'categoria': 'web',
        });
        if (entro) _baseId = null;
      }
      var consulta = cliente
          .from('pedidos')
          .select('id, cliente_nombre, total, origen, categoria, creado_en')
          .eq('negocio_id', negocioId)
          .or('origen.eq.tienda,categoria.eq.web');
      final desde = _desde;
      if (desde != null) {
        consulta = consulta.gt('creado_en', desde.toIso8601String());
      }
      final filas = await consulta.order('creado_en').limit(20);
      for (final cruda in filas) {
        final fila = _mapa(cruda);
        try {
          await _avisar(fila, refrescar: false);
        } catch (error) {
          debugPrint('Gexi: no se pudo leer un pedido de la página: $error');
        }
        final entro = await _meterEnLista(fila);
        if (!entro) break;
        _marcarDesde(fila);
      }
    } catch (error) {
      debugPrint('Gexi: no se pudo sondear pedidos de la página: $error');
    } finally {
      _sondeando = false;
    }
  }

  static Future<void> _alInsert(PostgresChangePayload payload) async {
    final fila = _mapa(payload.newRecord);
    try {
      await _avisar(fila, refrescar: true);
    } catch (error) {
      debugPrint('Gexi: no se pudo avisar el pedido de la página: $error');
    }
    final entro = await _meterEnLista(fila);
    if (entro) _marcarDesde(fila);
  }

  /// Copia el pedido a la base local y pide a la pantalla que se vuelva a leer.
  /// Si la nube ya descontó el stock, [SincronizarNegocio.traerPedido] lo baja una sola vez.
  static Future<bool> _meterEnLista(Map<String, dynamic> fila) async {
    final id = textoRemoto(fila['id']);
    if (id.isEmpty) return false;
    if (_enLista.contains(id)) return true;
    if (_bajando.contains(id)) return false;
    if (!_pareceDeTienda(fila)) return true;
    final base = _base;
    if (base == null) return false;
    _bajando.add(id);
    try {
      final resultado = await RemotoComun.enSerie(
        () => SincronizarNegocio.traerPedido(base, id),
      );
      if (!resultado.listo) return false;
      _enLista.add(id);
      if (_enLista.length > 400) {
        _enLista.remove(_enLista.first);
      }
      if (resultado.entro && !_pantalla.isClosed) {
        _pantalla.add(null);
      }
      return true;
    } catch (error) {
      debugPrint('Gexi: no se pudo bajar el pedido de la página: $error');
      return false;
    } finally {
      _bajando.remove(id);
    }
  }

  static bool _pareceDeTienda(Map<String, dynamic> fila) {
    final origen = textoRemoto(fila['origen']).toLowerCase();
    final categoria = textoRemoto(fila['categoria']).toLowerCase();
    if (origen.isEmpty && categoria.isEmpty) return true;
    return origen == 'tienda' || categoria == 'web';
  }

  static void _marcarDesde(Map<String, dynamic> fila) {
    final creado = DateTime.tryParse(textoRemoto(fila['creado_en']));
    if (creado != null && (_desde == null || creado.toUtc().isAfter(_desde!))) {
      _desde = creado.toUtc();
    }
  }

  /// El INSERT de la tienda guarda el total en 0 y lo actualiza en el mismo
  /// commit. Por eso el evento se relee: el payload trae el total viejo.
  static Future<void> _avisar(
    Map<String, dynamic> fila, {
    required bool refrescar,
  }) async {
    final id = textoRemoto(fila['id']);
    if (id.isEmpty || !_vistos.add(id)) return;
    if (_vistos.length > 400) {
      _vistos.remove(_vistos.first);
    }
    var datos = fila;
    try {
      if (refrescar) {
        final fresco = await _leerPedido(id);
        if (fresco != null) datos = fresco;
      }
      if (!_esDeTienda(datos)) return;
      await _mostrar(datos);
    } catch (error) {
      _vistos.remove(id);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> _leerPedido(String id) async {
    final cliente = RemotoComun.cliente;
    if (cliente == null) return null;
    final filas = await cliente
        .from('pedidos')
        .select('id, cliente_nombre, total, origen, categoria, creado_en')
        .eq('id', id)
        .limit(1);
    if (filas.isEmpty) return null;
    return _mapa(filas.first);
  }

  static bool _esDeTienda(Map<String, dynamic> fila) {
    final origen = textoRemoto(fila['origen']).toLowerCase();
    final categoria = textoRemoto(fila['categoria']).toLowerCase();
    return origen == 'tienda' || categoria == 'web';
  }

  static Future<void> _prepararPlugin() async {
    if (_pluginListo) return;
    const ajustes = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_aviso_pedido'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(ajustes);
    _pluginListo = true;
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static Future<void> _mostrar(Map<String, dynamic> fila) async {
    final nombreCrudo = textoRemoto(fila['cliente_nombre']);
    final nombre = nombreCrudo.isEmpty ? 'Un cliente' : nombreCrudo;
    final total = numeroRemoto(fila['total']) ?? 0;
    final moneda = await monedaDelNegocio();
    final frase =
        'Nuevo pedido de la página: $nombre · ${formatearMoneda(total, moneda)}';
    final avisoId = textoRemoto(fila['id']).hashCode & 0x7fffffff;
    final detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        _canalId,
        _canalNombre,
        channelDescription:
            'Avisa cuando llega un pedido hecho en la página web.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_aviso_pedido',
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(frase),
        ticker: frase,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      avisoId,
      'Nuevo pedido',
      frase,
      detalles,
    );
  }

  static Future<void> _cerrar() async {
    _esperaNegocio?.cancel();
    _esperaNegocio = null;
    _sondeo?.cancel();
    _sondeo = null;
    _unido = false;
    _negocioActivo = null;
    _marcaDelNegocio = null;
    _baseId = null;
    _desde = null;
    _intentosNegocio = 0;
    _vistos.clear();
    _enLista.clear();
    _bajando.clear();
    final canal = _canal;
    _canal = null;
    if (canal == null) return;
    final cliente = SupabaseListo.cliente;
    if (cliente == null) return;
    try {
      await cliente.removeChannel(canal);
    } catch (_) {}
  }
}

Map<String, dynamic> _mapa(Object? fila) {
  if (fila is Map<String, dynamic>) return fila;
  if (fila is Map) return Map<String, dynamic>.from(fila);
  return const {};
}

class _Observador with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AvisosPedidoTienda._alVolver());
    }
  }
}
