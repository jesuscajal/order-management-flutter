import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../gecko/gecko_assistant_card.dart';
import '../gecko/gecko_controller.dart';
import '../services/api_key_store.dart';
import '../services/asistente_enrutador.dart';
import '../services/openai_chat_service.dart';
import '../services/orquestador_ia.dart';
import '../theme/app_theme.dart';
import '../widgets/fondo_gexi.dart';

/// La consulta ya mostró su mensaje. Sirve para que el gecko pase a error
/// sin publicar el mismo aviso dos veces.
class _ConsultaIncompleta implements Exception {}

class _EntradaChat {
  const _EntradaChat(this.mensaje, {this.tarjeta});

  final MensajeChat mensaje;
  final _TarjetaPendiente? tarjeta;
}

class _TarjetaPendiente {
  _TarjetaPendiente(this.borrador);

  final BorradorConfirmable borrador;
  bool procesando = false;
  bool cerrada = false;
  bool? guardo;
  String? resultado;
}

class ChatIaScreen extends StatefulWidget {
  final AppDatabase database;

  const ChatIaScreen({super.key, required this.database});

  @override
  State<ChatIaScreen> createState() => _ChatIaScreenState();
}

class _ChatIaScreenState extends State<ChatIaScreen> {
  final _store = ApiKeyStore();
  final _orquestador = OrquestadorIa();
  final _gecko = GeckoAssistantController();
  final _controlador = TextEditingController();
  final _scroll = ScrollController();
  final List<_EntradaChat> _entradas = [];

  bool _enviando = false;
  bool _tieneClave = false;
  int _usados = 0;
  IntencionAsistente? _esperando;

  @override
  void initState() {
    super.initState();
    _entradas.add(
      const _EntradaChat(
        MensajeChat(
          role: 'assistant',
          content: '$alcanceAsistente '
              'Tenés ${ApiKeyStore.limiteMensajesAsistente} mensajes de prueba en este dispositivo. '
              'La clave de OpenAI queda solo acá. '
              'La carga por foto queda fuera de este prototipo.',
        ),
      ),
    );
    _cargarInicio();
  }

  Future<void> _cargarInicio() async {
    final clave = await _store.leer();
    final usados = await _store.leerMensajesUsados();
    if (!mounted) return;
    setState(() {
      _tieneClave = clave != null;
      _usados = usados;
    });
    if (clave == null && usados < ApiKeyStore.limiteMensajesAsistente) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pedirClave();
      });
    }
  }

  Future<void> _pedirClave() async {
    final campo = TextEditingController();
    final guardada = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clave de OpenAI'),
          content: TextField(
            controller: campo,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API key',
              hintText: 'sk-...',
              helperText: 'Queda guardada solo en este dispositivo.',
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
        );
      },
    );

    if (guardada == true && campo.text.trim().isNotEmpty) {
      await _store.guardar(campo.text);
      if (!mounted) return;
      setState(() => _tieneClave = true);
    }
    campo.dispose();
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
    if (_hayTarjetaAbierta() && esAfirmacion(texto)) {
      _volcar(texto);
      _publicar('Tocá Confirmar en la tarjeta. Todavía no guardé nada.');
      return;
    }

    if (esCancelacion(texto) && (_esperando != null || _hayTarjetaAbierta())) {
      _volcar(texto);
      _cancelarPendiente();
      return;
    }

    _volcar(texto);
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
          if (mounted) _publicar('No pude leer la base local.');
          throw _ConsultaIncompleta();
        }
        if (!mounted) return;
        if (decision is! RequiereModelo) {
          _aplicarDecision(decision);
          return;
        }

        final usados = await _store.leerMensajesUsados();
        if (!mounted) return;
        if (usados >= ApiKeyStore.limiteMensajesAsistente) {
          _publicar(mensajeSinCupo);
          throw _ConsultaIncompleta();
        }
        var clave = await _store.leer();
        if (!mounted) return;
        if (clave == null) {
          await _pedirClave();
          if (!mounted) return;
          clave = await _store.leer();
          if (clave == null) {
            _publicar(
              'Guardá la clave de OpenAI para interpretar ese pedido. '
              'Los informes y las órdenes claras de stock no la necesitan.',
            );
            throw _ConsultaIncompleta();
          }
        }
        analizar();
        await _consultarModelo(clave);
      });
    } on _ConsultaIncompleta {
      // El mensaje ya está en el chat y el gecko quedó en error.
    } catch (_) {
      if (mounted) {
        _publicar('Ocurrió un error al consultar el asistente.');
      }
    }
  }

  Future<void> _consultarModelo(String clave) async {
    try {
      final usados = await _store.consumirMensajeAsistente();
      if (!mounted) return;
      setState(() => _usados = usados);
      final decision = await _orquestador.consultarModelo(
        database: widget.database,
        apiKey: clave,
        historial: _historial(),
      );
      if (!mounted) return;
      _aplicarDecision(decision);
    } on ChatIaException catch (error) {
      if (mounted) _publicar(error.mensaje);
      throw _ConsultaIncompleta();
    } catch (_) {
      if (mounted) _publicar('Ocurrió un error al consultar el asistente.');
      throw _ConsultaIncompleta();
    }
  }

  void _aplicarDecision(DecisionAsistente decision) {
    switch (decision) {
      case RespuestaAsistente():
        _publicar(decision.mensaje);
      case InterpretacionAsistente():
        switch (decision.interpretacion) {
          case InterpretacionPregunta():
            final pregunta = decision.interpretacion as InterpretacionPregunta;
            if (pregunta.intencion == IntencionAsistente.venta ||
                pregunta.intencion == IntencionAsistente.producto ||
                pregunta.intencion == IntencionAsistente.ajusteStock) {
              _esperando = pregunta.intencion;
            }
            _publicar(pregunta.pregunta);
          case InterpretacionLista():
            final lista = decision.interpretacion as InterpretacionLista;
            _esperando = null;
            _publicarTarjeta(lista.borrador);
        }
      case RequiereModelo():
        break;
    }
  }

  Future<void> _confirmar(_TarjetaPendiente tarjeta) async {
    if (tarjeta.cerrada || tarjeta.procesando) return;
    setState(() => tarjeta.procesando = true);
    try {
      await _gecko.runTask((analizar) async {
        analizar();
        try {
          final resultado = await _orquestador.confirmar(
            database: widget.database,
            borrador: tarjeta.borrador,
          );
          if (!mounted) return;
          setState(() {
            tarjeta.procesando = false;
            tarjeta.resultado = resultado.mensaje;
            tarjeta.guardo = resultado.guardo;
            tarjeta.cerrada = resultado.guardo;
          });
          if (!resultado.guardo) throw _ConsultaIncompleta();
        } catch (error) {
          if (error is! _ConsultaIncompleta && mounted) {
            setState(() {
              tarjeta.procesando = false;
              tarjeta.resultado = 'No lo guardé. $error';
              tarjeta.guardo = false;
            });
          }
          rethrow;
        }
      });
    } on _ConsultaIncompleta {
      // El gecko muestra el error y la tarjeta ya tiene el resultado.
    } catch (_) {
      // La tarjeta ya explica el fallo y el gecko quedó en error.
    }
    _irAlFinal();
  }

  void _cancelarTarjeta(_TarjetaPendiente tarjeta) {
    if (tarjeta.cerrada || tarjeta.procesando) return;
    setState(() {
      tarjeta.cerrada = true;
      tarjeta.guardo = false;
      tarjeta.resultado = 'No guardé nada.';
    });
    _irAlFinal();
  }

  void _cancelarPendiente() {
    final tarjeta = _ultimaTarjetaAbierta();
    _esperando = null;
    _gecko.reset();
    if (tarjeta != null) {
      _cancelarTarjeta(tarjeta);
      return;
    }
    _publicar('No guardé nada.');
  }

  void _volcar(String texto) {
    _controlador.clear();
    setState(() {
      _entradas.add(_EntradaChat(MensajeChat(role: 'user', content: texto)));
    });
    _irAlFinal();
  }

  void _publicar(String texto) {
    if (!mounted) return;
    setState(() {
      _entradas
          .add(_EntradaChat(MensajeChat(role: 'assistant', content: texto)));
    });
    _irAlFinal();
  }

  void _publicarTarjeta(BorradorConfirmable borrador) {
    if (!mounted) return;
    setState(() {
      _entradas.add(
        _EntradaChat(
          MensajeChat(role: 'assistant', content: borrador.resumen),
          tarjeta: _TarjetaPendiente(borrador),
        ),
      );
    });
    _irAlFinal();
  }

  List<MensajeChat> _historial() {
    if (_entradas.length <= 1) return const [];
    return _entradas.skip(1).map((entrada) => entrada.mensaje).toList();
  }

  bool _hayTarjetaAbierta() => _ultimaTarjetaAbierta() != null;

  _TarjetaPendiente? _ultimaTarjetaAbierta() {
    for (var i = _entradas.length - 1; i >= 0; i--) {
      final tarjeta = _entradas[i].tarjeta;
      if (tarjeta != null && !tarjeta.cerrada) return tarjeta;
    }
    return null;
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
    final sinCupo = _usados >= ApiKeyStore.limiteMensajesAsistente;
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
        actions: [
          IconButton(
            tooltip: _tieneClave
                ? 'Cambiar clave de OpenAI'
                : 'Cargar clave de OpenAI',
            onPressed: _pedirClave,
            icon: Icon(_tieneClave ? Icons.key : Icons.key_off),
          ),
        ],
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Mensajes de prueba: $_usados de ${ApiKeyStore.limiteMensajesAsistente}',
                          style: TextStyle(
                            fontSize: 12,
                            color: sinCupo
                                ? AppColors.alerta
                                : AppColors.textoSuave,
                          ),
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
                                hintText:
                                    'Pedí informes, stock, productos o ventas',
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
    final tarjeta = entrada.tarjeta;
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
            if (tarjeta?.resultado != null) ...[
              const SizedBox(height: 8),
              Text(
                tarjeta!.resultado!,
                style: TextStyle(
                  color: tarjeta.guardo == true
                      ? AppColors.verde
                      : AppColors.alerta,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (tarjeta != null && !tarjeta.cerrada) ...[
              if (tarjeta.procesando) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.azul,
                  backgroundColor: AppColors.limaBrillo,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: tarjeta.procesando
                        ? null
                        : () => _cancelarTarjeta(tarjeta),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed:
                        tarjeta.procesando ? null : () => _confirmar(tarjeta),
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
