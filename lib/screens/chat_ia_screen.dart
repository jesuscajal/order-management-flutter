import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../gecko/gecko_assistant_card.dart';
import '../gecko/gecko_controller.dart';
import '../services/negocio_local.dart';
import '../services/asistente/foto_catalogo_asistente.dart';
import '../services/asistente/memoria_asistente.dart';
import '../services/asistente/orquestador_asistente.dart';
import '../services/asistente/plan_asistente.dart';
import '../services/asistente_enrutador.dart';
import '../services/openai_chat_service.dart';
import '../services/orquestador_ia.dart';
import '../utils/elegir_foto.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

/// La consulta ya mostró su mensaje. Sirve para que el gecko pase a error
/// sin publicar el mismo aviso dos veces.
class _ConsultaIncompleta implements Exception {}

class _EntradaChat {
  const _EntradaChat(this.mensaje, {this.plan});

  final MensajeChat mensaje;
  final _TarjetaPlan? plan;
}

class _TarjetaPlan {
  _TarjetaPlan(this.plan);

  PlanAsistente plan;
  bool procesando = false;
  bool cerrada = false;
  bool? guardo;
  String? resultado;
  final Map<int, Uint8List> fotos = {};
  final Set<int> fotosDespues = {};
  String? errorFoto;
}

class ChatIaScreen extends StatefulWidget {
  final AppDatabase database;

  const ChatIaScreen({super.key, required this.database});

  @override
  State<ChatIaScreen> createState() => _ChatIaScreenState();
}

class _ChatIaScreenState extends State<ChatIaScreen> {
  final _memoria = const MemoriaAsistente();
  final _orquestador = OrquestadorIa();
  late final OrquestadorAsistente _operaciones;
  final _gecko = GeckoAssistantController();
  final _controlador = TextEditingController();
  final _scroll = ScrollController();
  final List<_EntradaChat> _entradas = [];

  bool _enviando = false;
  IntencionAsistente? _esperando;

  @override
  void initState() {
    super.initState();
    _operaciones = OrquestadorAsistente(database: widget.database);
    _entradas.add(
      const _EntradaChat(
        MensajeChat(
          role: 'assistant',
          content: '$alcanceAsistente '
              'Uso el asistente del negocio. '
              'Si un producto va a la página y no tiene foto, te la pido o la genero con fondo blanco.',
        ),
      ),
    );
    _cargarInicio();
  }

  Future<void> _cargarInicio() async {
    final previos = await _memoria.mensajesRecientes();
    final funciones = await NegocioStore().leerFuncionesAsistente();
    if (!mounted) return;
    setState(() {
      if (previos.isNotEmpty) {
        _entradas
          ..clear()
          ..addAll([
            for (final mensaje in previos)
              _EntradaChat(
                MensajeChat(role: mensaje.rol, content: mensaje.contenido),
              ),
          ]);
      } else if (_entradas.isNotEmpty) {
        _entradas[0] = _EntradaChat(
          MensajeChat(
            role: 'assistant',
            content: '${alcanceConFunciones(funciones)} '
                'Uso el asistente del negocio. '
                'Si un producto va a la página y no tiene foto, te la pido o la genero con fondo blanco.',
          ),
        );
      }
    });
    _irAlFinal();
  }

  Future<void> _enviar() async {
    final texto = _controlador.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      await _procesar(texto);
    } finally {
      if (mounted) setState(() => _enviando = false);
      _irAlFinal();
    }
  }

  Future<void> _procesar(String texto) async {
    final plan = _planAbierto();
    if (esAfirmacion(texto) && _hayConfirmacionAbierta()) {
      await _volcar(texto);
      await _publicar('Tocá Confirmar en la tarjeta. Todavía no guardé nada.');
      return;
    }

    if (esCancelacion(texto) && (_esperando != null || plan != null)) {
      await _volcar(texto);
      await _cancelarPendiente();
      return;
    }

    if (plan != null && !plan.plan.listo) {
      await _volcar(texto);
      if (parecePlanJson(texto)) {
        await _cerrarPlan(plan, 'Reemplacé el plan. No guardé nada.');
        await _correrPlan(() => _operaciones.aplicarJson(texto));
        return;
      }
      await _correrPlan(
        () => _operaciones.completar(plan.plan, texto),
        cerrar: plan,
      );
      return;
    }

    if (plan != null && plan.plan.listo) {
      await _volcar(texto);
      if (parecePlanJson(texto)) {
        await _cerrarPlan(plan, 'Reemplacé el plan. No guardé nada.');
        await _correrPlan(() => _operaciones.aplicarJson(texto));
        return;
      }
      await _publicar('Hay un plan sin confirmar. Tocá Confirmar o Cancelar.');
      return;
    }

    await _volcar(texto);
    if (parecePlanJson(texto)) {
      await _correrPlan(() => _operaciones.aplicarJson(texto));
      return;
    }

    try {
      await _gecko.runTask((analizar) async {
        final DecisionAsistente decision;
        try {
          decision = await _orquestador.evaluarLocal(
            database: widget.database,
            texto: texto,
            esperando: _esperando,
          );
        } catch (_) {
          if (mounted) await _publicar('No pude leer la base local.');
          throw _ConsultaIncompleta();
        }
        if (!mounted) return;
        if (decision is RespuestaAsistente) {
          await _publicar(decision.mensaje);
          return;
        }
        if (decision is InterpretacionAsistente) {
          final interpretacion = decision.interpretacion;
          if (interpretacion is InterpretacionPregunta) {
            _esperando = interpretacion.intencion;
            await _publicar(interpretacion.pregunta);
            return;
          }
          if (interpretacion is InterpretacionLista &&
              interpretacion.borrador is BorradorProducto) {
            final borrador = interpretacion.borrador as BorradorProducto;
            analizar();
            final resultado = await _operaciones.desdeAltaLocal(
              nombre: borrador.nombre,
              precioCompra: borrador.precioCompra,
              precioVenta: borrador.precioVenta,
              cantidad: borrador.cantidadInicial,
            );
            if (!mounted) return;
            await _publicarResultado(resultado);
            if (resultado.error) throw _ConsultaIncompleta();
            return;
          }
        }
        await _operacionConModelo(texto, analizar);
      });
    } on _ConsultaIncompleta {
      // El mensaje ya está en el chat y el gecko quedó en error.
    } catch (_) {
      if (mounted) {
        await _publicar('Ocurrió un error al consultar el asistente.');
      }
    }
  }

  Future<void> _operacionConModelo(
    String texto,
    void Function() analizar,
  ) async {
    analizar();
    final resultado = await _operaciones.interpretar(
      fraseConAntecedente(texto, _fraseUsuarioAnterior()),
      historial: _historialReciente(),
    );
    if (!mounted) return;
    await _publicarResultado(resultado);
    if (resultado.error) throw _ConsultaIncompleta();
  }

  Future<void> _correrPlan(
    Future<ResultadoInterpretacion> Function() accion, {
    _TarjetaPlan? cerrar,
  }) async {
    try {
      await _gecko.runTask((analizar) async {
        analizar();
        if (cerrar != null && mounted) {
          setState(() => cerrar.procesando = true);
        }
        final resultado = await accion();
        if (!mounted) return;
        if (cerrar != null) await _cerrarPlan(cerrar, null);
        await _publicarResultado(resultado);
        if (resultado.error) throw _ConsultaIncompleta();
      });
    } on _ConsultaIncompleta {
      // El mensaje ya está en el chat.
    } catch (_) {
      if (cerrar != null && mounted) {
        setState(() => cerrar.procesando = false);
      }
      if (mounted) await _publicar('No pude armar el plan. No guardé nada.');
    }
  }

  Future<void> _confirmarPlan(_TarjetaPlan tarjeta) async {
    if (tarjeta.cerrada || tarjeta.procesando || !tarjeta.plan.listo) return;
    setState(() => tarjeta.procesando = true);
    try {
      await _gecko.runTask((analizar) async {
        analizar();
        final resultado = await _operaciones.confirmar(
          tarjeta.plan,
          fotosBase64: {
            for (final entrada in tarjeta.fotos.entries)
              entrada.key: base64Encode(entrada.value),
          },
        );
        if (!mounted) return;
        setState(() {
          tarjeta.procesando = false;
          tarjeta.resultado = resultado.mensaje;
          tarjeta.guardo = resultado.guardo;
          tarjeta.cerrada = resultado.guardo || resultado.parcial;
        });
        await _memoria.guardarMensaje(
          rol: 'assistant',
          contenido: resultado.mensaje,
        );
        if (!resultado.guardo) throw _ConsultaIncompleta();
      });
    } on _ConsultaIncompleta {
      // La tarjeta ya muestra qué pasó y el gecko quedó en error.
    } catch (error) {
      if (mounted) {
        final texto = 'No lo guardé. $error';
        setState(() {
          tarjeta.procesando = false;
          tarjeta.resultado = texto;
          tarjeta.guardo = false;
        });
        await _memoria.guardarMensaje(rol: 'assistant', contenido: texto);
      }
    }
    _irAlFinal();
  }

  Future<void> _elegirOpcion(_TarjetaPlan tarjeta, OpcionPlan opcion) async {
    if (tarjeta.cerrada || tarjeta.procesando) return;
    setState(() {
      tarjeta.procesando = true;
      _entradas.add(
        _EntradaChat(MensajeChat(role: 'user', content: opcion.etiqueta)),
      );
    });
    await _memoria.guardarMensaje(rol: 'user', contenido: opcion.etiqueta);
    await _correrPlan(
      () => _operaciones.elegir(tarjeta.plan, opcion.id),
      cerrar: tarjeta,
    );
    _irAlFinal();
  }

  void _dejarFotoParaDespues(_TarjetaPlan tarjeta, int indice) {
    if (tarjeta.cerrada || tarjeta.procesando) return;
    setState(() {
      tarjeta.fotos.remove(indice);
      tarjeta.fotosDespues.add(indice);
      tarjeta.errorFoto = null;
    });
  }

  Future<void> _cargarFotoUsuario(_TarjetaPlan tarjeta, int indice) async {
    if (tarjeta.cerrada || tarjeta.procesando) return;
    final origen = await preguntarOrigenFoto(context);
    if (origen == null || !mounted) return;
    setState(() {
      tarjeta.procesando = true;
      tarjeta.errorFoto = null;
    });
    try {
      final archivos = await elegirFotos(
        origen: origen,
        variasEnGaleria: false,
        maxWidth: 800,
        imageQuality: 55,
      );
      if (!mounted) return;
      if (archivos.isEmpty) return;
      final jpeg = FotoCatalogoAsistente().preparar(
        await archivos.first.readAsBytes(),
      );
      if (!mounted) return;
      setState(() {
        tarjeta.fotosDespues.remove(indice);
        tarjeta.fotos[indice] = jpeg;
      });
    } on ChatIaException catch (error) {
      if (mounted) setState(() => tarjeta.errorFoto = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => tarjeta.errorFoto = 'No pude usar esa foto.');
      }
    } finally {
      if (mounted) setState(() => tarjeta.procesando = false);
    }
  }

  Future<void> _generarFoto(_TarjetaPlan tarjeta, int indice) async {
    if (tarjeta.cerrada || tarjeta.procesando) return;
    if (indice < 0 || indice >= tarjeta.plan.acciones.length) return;
    final accion = tarjeta.plan.acciones[indice];
    setState(() {
      tarjeta.procesando = true;
      tarjeta.errorFoto = null;
    });
    try {
      final jpeg = await FotoCatalogoAsistente().generar(
        nombre: _nombreAccion(accion),
        categoria: accion.categoria,
      );
      if (!mounted) return;
      setState(() {
        tarjeta.fotosDespues.remove(indice);
        tarjeta.fotos[indice] = jpeg;
      });
    } on ChatIaException catch (error) {
      if (mounted) setState(() => tarjeta.errorFoto = error.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => tarjeta.errorFoto = 'No pude generar la foto. Podés subir una.',
        );
      }
    } finally {
      if (mounted) setState(() => tarjeta.procesando = false);
    }
  }

  Future<void> _cancelarPlan(_TarjetaPlan tarjeta) async {
    if (tarjeta.cerrada || tarjeta.procesando) return;
    await _cerrarPlan(tarjeta, 'No guardé nada.');
    _irAlFinal();
  }

  Future<void> _cerrarPlan(_TarjetaPlan tarjeta, String? nota) async {
    if (!mounted) return;
    setState(() {
      tarjeta.cerrada = true;
      tarjeta.procesando = false;
      tarjeta.resultado = nota;
      if (nota != null) tarjeta.guardo = false;
    });
    if (nota != null) {
      await _memoria.guardarMensaje(rol: 'assistant', contenido: nota);
    }
  }

  Future<void> _cancelarPendiente() async {
    _esperando = null;
    _gecko.reset();
    final plan = _planAbierto();
    if (plan != null) {
      await _cancelarPlan(plan);
      return;
    }
    await _publicar('No guardé nada.');
  }

  Future<void> _volcar(String texto) async {
    _controlador.clear();
    setState(() {
      _entradas.add(_EntradaChat(MensajeChat(role: 'user', content: texto)));
    });
    _irAlFinal();
    await _memoria.guardarMensaje(rol: 'user', contenido: texto);
  }

  Future<void> _publicar(
    String texto, {
    List<String> productos = const [],
  }) async {
    if (!mounted) return;
    setState(() {
      _entradas
          .add(_EntradaChat(MensajeChat(role: 'assistant', content: texto)));
    });
    _irAlFinal();
    await _memoria.guardarMensaje(rol: 'assistant', contenido: texto);
    await _memoria.actualizarResumen(
      frase: _ultimaFraseUsuario(),
      productos: productos,
    );
  }

  Future<void> _publicarResultado(ResultadoInterpretacion resultado) async {
    final productos =
        resultado.plan?.acciones.map((accion) => accion.nombre).toList() ??
            const <String>[];
    final plan = resultado.plan;
    if (plan == null || !plan.tieneEscritura) {
      await _publicar(resultado.mensaje, productos: productos);
      return;
    }
    if (!mounted) return;
    setState(() {
      _entradas.add(
        _EntradaChat(
          MensajeChat(role: 'assistant', content: resultado.mensaje),
          plan: _TarjetaPlan(plan),
        ),
      );
    });
    _irAlFinal();
    await _memoria.guardarMensaje(
        rol: 'assistant', contenido: resultado.mensaje);
    await _memoria.actualizarResumen(
      frase: _ultimaFraseUsuario(),
      productos: productos,
    );
  }

  bool _hayConfirmacionAbierta() {
    final plan = _planAbierto();
    return plan != null && plan.plan.listo;
  }

  _TarjetaPlan? _planAbierto() {
    for (var i = _entradas.length - 1; i >= 0; i--) {
      final plan = _entradas[i].plan;
      if (plan != null && !plan.cerrada) return plan;
    }
    return null;
  }

  String _ultimaFraseUsuario() {
    for (var i = _entradas.length - 1; i >= 0; i--) {
      final mensaje = _entradas[i].mensaje;
      if (mensaje.role == 'user') return mensaje.content;
    }
    return '';
  }

  /// La frase que se acaba de enviar no cuenta: es la última del chat.
  String? _fraseUsuarioAnterior() {
    var vistas = 0;
    for (var i = _entradas.length - 1; i >= 0; i--) {
      final mensaje = _entradas[i].mensaje;
      if (mensaje.role != 'user') continue;
      vistas++;
      if (vistas == 1) continue;
      return mensaje.content;
    }
    return null;
  }

  List<MensajeChat> _historialReciente() {
    final mensajes = [
      for (final entrada in _entradas)
        if (entrada.mensaje.role == 'user' ||
            entrada.mensaje.role == 'assistant')
          entrada.mensaje,
    ];
    if (mensajes.isNotEmpty && mensajes.last.role == 'user') {
      mensajes.removeLast();
    }
    if (mensajes.length <= topeTurnosAsistente) return mensajes;
    return mensajes.sublist(mensajes.length - topeTurnosAsistente);
  }

  /// Los informes no gastan cupo. "Agregar stock" deja la frase para completar.
  List<String> _sugerencias() {
    const todas = [
      '¿Cuánto vendí hoy?',
      '¿Qué me queda poco?',
      'Pedidos pendientes',
      'Agregar stock de ',
      '¿Quién me debe?',
    ];
    String ultima = '';
    for (var i = _entradas.length - 1; i >= 0; i--) {
      final mensaje = _entradas[i].mensaje;
      if (mensaje.role == 'user') {
        ultima = normalizarTexto(mensaje.content);
        break;
      }
    }
    return [
      for (final sugerencia in todas)
        if (normalizarTexto(sugerencia).trim() != ultima) sugerencia,
    ].take(4).toList();
  }

  void _usarSugerencia(String sugerencia) {
    if (sugerencia.endsWith(' ')) {
      _controlador
        ..text = sugerencia
        ..selection = TextSelection.collapsed(offset: sugerencia.length);
      return;
    }
    _controlador.text = sugerencia;
    _enviar();
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _gecko.dispose();
    _controlador.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asistente'),
            Text(
              OpenAiChatService.modelo,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: FondoGexi(
        child: SizedBox.expand(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GeckoAssistantCard(
                  controller: _gecko,
                  compact: true,
                  avatarSize: 132,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _entradas.length,
                  itemBuilder: (context, index) => _burbuja(_entradas[index]),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    children: [
                      if (_planAbierto() == null && !_enviando)
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final sugerencia in _sugerencias())
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    label: Text(sugerencia),
                                    onPressed: () =>
                                        _usarSugerencia(sugerencia),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controlador,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _enviar(),
                              decoration: const InputDecoration(
                                hintText: 'Informes, o una entrada y una venta',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _enviando ? null : _enviar,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _burbuja(_EntradaChat entrada) {
    final mensaje = entrada.mensaje;
    final esUsuario = mensaje.role == 'user';
    final plan = entrada.plan;
    final colorTexto = esUsuario ? Colors.white : AppColors.texto;
    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        decoration: BoxDecoration(
          gradient: esUsuario ? AppColors.degradadoBarra : null,
          color: esUsuario ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: esUsuario ? null : Border.all(color: AppColors.linea),
          boxShadow: esUsuario ? null : AppColors.sombraTarjeta,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje.content, style: TextStyle(color: colorTexto)),
            if (plan != null && plan.resultado != null) ...[
              const SizedBox(height: 8),
              Text(
                plan.resultado!,
                style: TextStyle(
                  color:
                      plan.guardo == true ? AppColors.verde : AppColors.alerta,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (plan != null && !plan.cerrada) ...[
              if (plan.procesando) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.azul,
                  backgroundColor: AppColors.limaBrillo,
                ),
              ],
              if (plan.plan.opciones.isNotEmpty && !plan.plan.listo) ...[
                const SizedBox(height: 8),
                for (final opcion in plan.plan.opciones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: opcion.productoId == null
                          ? OutlinedButton(
                              onPressed: plan.procesando
                                  ? null
                                  : () => _elegirOpcion(plan, opcion),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                foregroundColor: AppColors.texto,
                                side: const BorderSide(color: AppColors.azul),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(opcion.etiqueta),
                                  if (opcion.detalle.isNotEmpty)
                                    Text(
                                      opcion.detalle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textoSuave,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : _FilaProductoAmbiguo(
                              habilitada: !plan.procesando,
                              onTap: () => _elegirOpcion(plan, opcion),
                              opcion: opcion,
                            ),
                    ),
                  ),
              ],
              if (plan.plan.listo) ...[
                for (final indice in _indicesConFoto(plan.plan))
                  _PedidoFoto(
                    nombre: _nombreAccion(plan.plan.acciones[indice]),
                    bytes: plan.fotos[indice],
                    despues: plan.fotosDespues.contains(indice),
                    habilitada: !plan.procesando,
                    onSubir: () => _cargarFotoUsuario(plan, indice),
                    onGenerar: () => _generarFoto(plan, indice),
                    onDespues: () => _dejarFotoParaDespues(plan, indice),
                  ),
                if (plan.errorFoto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      plan.errorFoto!,
                      style: const TextStyle(color: AppColors.alerta),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: plan.procesando
                        ? null
                        : () {
                            _cancelarPlan(plan);
                          },
                    child: const Text('Cancelar'),
                  ),
                  if (plan.plan.listo)
                    FilledButton(
                      onPressed:
                          plan.procesando ? null : () => _confirmarPlan(plan),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.azul,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirmar'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<int> _indicesConFoto(PlanAsistente plan) {
  final indices = <int>[];
  for (var i = 0; i < plan.acciones.length; i++) {
    if (plan.acciones[i].pideFoto) indices.add(i);
  }
  return indices;
}

String _nombreAccion(AccionPlan accion) {
  final nombre = accion.nombreConfirmado?.trim() ?? '';
  if (nombre.isNotEmpty) return nombre;
  return accion.nombre.trim();
}

/// Pide una foto propia o una generada con fondo blanco para la página.
class _PedidoFoto extends StatelessWidget {
  const _PedidoFoto({
    required this.nombre,
    required this.habilitada,
    required this.onSubir,
    required this.onGenerar,
    required this.onDespues,
    this.bytes,
    this.despues = false,
  });

  final String nombre;
  final Uint8List? bytes;
  final bool despues;
  final bool habilitada;
  final VoidCallback onSubir;
  final VoidCallback onGenerar;
  final VoidCallback onDespues;

  @override
  Widget build(BuildContext context) {
    final foto = bytes;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            despues
                ? 'La foto de $nombre queda para después. El producto se guarda igual.'
                : '$nombre se muestra en la página. Si tenés una foto, subila. '
                    'Si no, la genero sobre fondo blanco, o la agregás después.',
          ),
          if (!despues && foto != null && foto.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: Colors.white,
                child: Image.memory(
                  foto,
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ],
          if (!despues) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: habilitada ? onSubir : null,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Tengo una foto'),
                ),
                OutlinedButton.icon(
                  onPressed: habilitada ? onGenerar : null,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Generar con fondo blanco'),
                ),
                TextButton(
                  onPressed: habilitada ? onDespues : null,
                  child: const Text('Agregar después'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila tocable: foto, nombre y el dato corto. El toque confirma ese id.
class _FilaProductoAmbiguo extends StatelessWidget {
  const _FilaProductoAmbiguo({
    required this.habilitada,
    required this.onTap,
    required this.opcion,
  });

  final bool habilitada;
  final VoidCallback onTap;
  final OpcionPlan opcion;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: habilitada ? 1 : 0.5,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.azul),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: habilitada ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _MiniaturaCoincidencia(
                  nombre: opcion.etiqueta,
                  fotoUrl: opcion.fotoUrl,
                  fotoBytes: opcion.fotoBytes,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opcion.etiqueta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (opcion.detalle.isNotEmpty)
                        Text(
                          opcion.detalle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textoSuave,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura de un producto ambiguo. Si la URL no carga, queda la inicial.
class _MiniaturaCoincidencia extends StatelessWidget {
  const _MiniaturaCoincidencia({
    required this.nombre,
    this.fotoUrl,
    this.fotoBytes,
  });

  final String nombre;
  final String? fotoUrl;
  final Uint8List? fotoBytes;

  static const _lado = 48.0;

  @override
  Widget build(BuildContext context) {
    final url = _urlPublica(fotoUrl);
    final bytes = fotoBytes;
    final Widget imagen;
    if (url != null) {
      imagen = Image.network(
        url,
        width: _lado,
        height: _lado,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _inicial(nombre),
        loadingBuilder: (context, child, progreso) {
          if (progreso == null) return child;
          return const ColoredBox(color: AppColors.fondoClaro);
        },
      );
    } else if (bytes != null && bytes.isNotEmpty) {
      imagen = Image.memory(
        bytes,
        width: _lado,
        height: _lado,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _inicial(nombre),
      );
    } else {
      imagen = _inicial(nombre);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: _lado, height: _lado, child: imagen),
    );
  }
}

String? _urlPublica(String? texto) {
  final limpio = texto?.trim() ?? '';
  if (limpio.isEmpty) return null;
  final uri = Uri.tryParse(limpio);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return limpio;
}

Widget _inicial(String nombre) {
  final limpio = nombre.trim();
  final letra = limpio.isEmpty
      ? '?'
      : String.fromCharCode(limpio.runes.first).toUpperCase();
  return ColoredBox(
    color: AppColors.limaBrillo,
    child: SizedBox(
      width: _MiniaturaCoincidencia._lado,
      height: _MiniaturaCoincidencia._lado,
      child: Center(
        child: Text(
          letra,
          style: const TextStyle(
            color: AppColors.azulProfundo,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    ),
  );
}
