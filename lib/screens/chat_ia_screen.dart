import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_database.dart';
import '../services/api_key_store.dart';
import '../services/asistente_enrutador.dart';
import '../services/negocio_contexto.dart';
import '../services/openai_chat_service.dart';
import '../services/openai_vision_service.dart';

class _EntradaChat {
  final MensajeChat mensaje;
  final Uint8List? imagen;

  const _EntradaChat(this.mensaje, {this.imagen});
}

class _AltaProducto {
  final String nombre;
  final String descripcion;
  final String categoria;
  final double precioCompra;
  final double precioVenta;

  const _AltaProducto({
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.precioCompra,
    required this.precioVenta,
  });
}

class _PreciosDialog extends StatefulWidget {
  final Uint8List imagen;
  final String nombreInicial;
  final String descripcionInicial;
  final String categoriaInicial;
  final String costoInicial;
  final String ventaInicial;

  const _PreciosDialog({
    required this.imagen,
    required this.nombreInicial,
    required this.descripcionInicial,
    required this.categoriaInicial,
    required this.costoInicial,
    required this.ventaInicial,
  });

  @override
  State<_PreciosDialog> createState() => _PreciosDialogState();
}

class _PreciosDialogState extends State<_PreciosDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _categoria;
  late final TextEditingController _costo;
  late final TextEditingController _venta;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.nombreInicial);
    _descripcion = TextEditingController(text: widget.descripcionInicial);
    _categoria = TextEditingController(text: widget.categoriaInicial);
    _costo = TextEditingController(text: widget.costoInicial);
    _venta = TextEditingController(text: widget.ventaInicial);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _categoria.dispose();
    _costo.dispose();
    _venta.dispose();
    super.dispose();
  }

  void _revisar() {
    if (_formKey.currentState?.validate() != true) return;
    final compra = _parsePrecio(_costo.text);
    final ventaValor = _parsePrecio(_venta.text);
    if (compra == null || ventaValor == null) return;
    Navigator.pop(
      context,
      _AltaProducto(
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim().isEmpty
            ? 'Sin descripción'
            : _descripcion.text.trim(),
        categoria: _categoria.text.trim().isEmpty
            ? 'Sin categoría'
            : _categoria.text.trim(),
        precioCompra: compra,
        precioVenta: ventaValor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Precios del producto'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _miniatura(widget.imagen),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'Indicá un nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descripcion,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _costo,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio de costo',
                hintText: '0,00',
                helperText: 'Lo cargás vos',
              ),
              validator: _validarPrecio,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _venta,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio de venta',
                hintText: '0,00',
                helperText: 'Lo cargás vos',
              ),
              validator: _validarPrecio,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _revisar,
          child: const Text('Revisar'),
        ),
      ],
    );
  }
}

class ChatIaScreen extends StatefulWidget {
  final AppDatabase database;

  const ChatIaScreen({super.key, required this.database});

  @override
  State<ChatIaScreen> createState() => _ChatIaScreenState();
}

class _ChatIaScreenState extends State<ChatIaScreen> {
  final _store = ApiKeyStore();
  final _enrutador = AsistenteEnrutador();
  final _picker = ImagePicker();
  final _controlador = TextEditingController();
  final _scroll = ScrollController();
  final List<_EntradaChat> _entradas = [];

  bool _enviando = false;
  bool _tieneClave = false;

  @override
  void initState() {
    super.initState();
    _entradas.add(
      const _EntradaChat(
        MensajeChat(
          role: 'assistant',
          content:
              'Preguntame por clientes, productos, stock, pedidos o capital que estén guardados en la base local. '
              'Para dar de alta un producto, subí una foto con el botón de imagen. '
              'Necesitás una clave de la API de OpenAI, que queda solo en este dispositivo.',
        ),
      ),
    );
    _cargarClave();
  }

  Future<void> _cargarClave() async {
    final clave = await _store.leer();
    if (!mounted) return;
    setState(() => _tieneClave = clave != null);
    if (clave == null) {
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

  Future<String?> _claveLista() async {
    var clave = await _store.leer();
    if (!mounted) return null;
    if (clave != null) return clave;
    await _pedirClave();
    if (!mounted) return null;
    clave = await _store.leer();
    return clave;
  }

  Future<void> _enviar() async {
    final texto = _controlador.text.trim();
    if (texto.isEmpty || _enviando) return;

    final clave = await _store.leer();
    if (clave == null) {
      await _pedirClave();
      return;
    }

    setState(() {
      _entradas.add(_EntradaChat(MensajeChat(role: 'user', content: texto)));
      _enviando = true;
    });
    _controlador.clear();
    _irAlFinal();

    try {
      final contexto = await NegocioContexto(widget.database).resumir();
      final resultado = await _enrutador.enrutar(
        SolicitudAsistente.texto(
          apiKey: clave,
          contextoNegocio: contexto,
          historial: _entradas.skip(1).map((e) => e.mensaje).toList(),
        ),
      );
      if (resultado is! ResultadoTexto) {
        throw ChatIaException('No llegó una respuesta de texto.');
      }
      if (!mounted) return;
      setState(() {
        _entradas.add(
          _EntradaChat(MensajeChat(role: 'assistant', content: resultado.texto)),
        );
      });
    } on ChatIaException catch (e) {
      if (!mounted) return;
      setState(() {
        _entradas.add(_EntradaChat(MensajeChat(role: 'assistant', content: e.mensaje)));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entradas.add(
          const _EntradaChat(
            MensajeChat(
              role: 'assistant',
              content: 'Ocurrió un error al consultar el asistente.',
            ),
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
      _irAlFinal();
    }
  }

  Future<void> _elegirFoto() async {
    if (_enviando) return;
    final clave = await _claveLista();
    if (!mounted) return;
    if (clave == null) return;

    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galería'),
                subtitle: const Text('Elegir una foto ya guardada'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Cámara'),
                subtitle: const Text('Si este equipo no tiene cámara, usá la galería'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || origen == null) return;
    await _cargarFoto(origen);
  }

  Future<void> _cargarFoto(ImageSource origen) async {
    if (origen == ImageSource.camera &&
        !_picker.supportsImageSource(ImageSource.camera)) {
      if (!mounted) return;
      final usarGaleria = await _ofrecerGaleria();
      if (usarGaleria == true && mounted) {
        await _cargarFoto(ImageSource.gallery);
      }
      return;
    }

    final XFile? archivo;
    try {
      archivo = await _picker.pickImage(
        source: origen,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
        requestFullMetadata: false,
      );
    } catch (error) {
      if (!mounted) return;
      if (_esPluginAusente(error)) {
        _publicarAsistente(
          'El selector de fotos no está disponible en esta compilación. '
          'Hay que volver a compilar la app para usar la galería.',
        );
        return;
      }
      if (origen == ImageSource.camera) {
        final usarGaleria = await _ofrecerGaleria();
        if (usarGaleria == true && mounted) {
          await _cargarFoto(ImageSource.gallery);
        }
        return;
      }
      _publicarAsistente('No pude abrir la galería. Intentá de nuevo.');
      return;
    }

    if (archivo == null || !mounted) return;

    Uint8List bytes;
    try {
      bytes = await archivo.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      _publicarAsistente('No pude leer la foto elegida. Intentá con otra.');
      return;
    }
    if (!mounted) return;
    if (bytes.isEmpty) {
      _publicarAsistente('La foto está vacía. Elegí otra imagen.');
      return;
    }

    var clave = await _store.leer();
    if (!mounted) return;
    if (clave == null) {
      await _pedirClave();
      if (!mounted) return;
      clave = await _store.leer();
      if (clave == null) return;
    }

    final mime = OpenAiVisionService.mimeDeArchivo(
      path: archivo.path,
      mimeType: archivo.mimeType,
    );

    setState(() {
      _entradas.add(
        _EntradaChat(
          const MensajeChat(
            role: 'user',
            content: 'Foto para dar de alta un producto.',
          ),
          imagen: bytes,
        ),
      );
      _enviando = true;
    });
    _irAlFinal();

    String? fallo;
    ProductoDetectado? detectado;
    try {
      final resultado = await _enrutador.enrutar(
        SolicitudAsistente.imagen(
          apiKey: clave,
          bytes: bytes,
          mimeType: mime,
        ),
      );
      if (resultado is ResultadoVision) {
        detectado = resultado.producto;
      } else {
        fallo = 'La foto no se envió al modelo de visión.';
      }
    } on ChatIaException catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'Ocurrió un error al analizar la foto.';
    } finally {
      if (mounted) setState(() => _enviando = false);
      _irAlFinal();
    }

    if (!mounted) return;
    if (fallo != null || detectado == null) {
      _publicarAsistente(fallo ?? 'Ocurrió un error al analizar la foto.');
      return;
    }
    await _completarAlta(detectado, bytes);
  }

  Future<bool?> _ofrecerGaleria() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cámara no disponible'),
          content: const Text(
            'No pude usar la cámara en este equipo. Podés elegir la foto desde la galería.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abrir galería'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completarAlta(ProductoDetectado detectado, Uint8List imagen) async {
    _publicarAsistente(
      'Leí estos datos de la foto:\n'
      'Nombre: ${detectado.nombre}\n'
      'Descripción: ${detectado.descripcion}\n'
      'Categoría: ${detectado.categoria}\n\n'
      'Indicá el precio de costo y el de venta. Todavía no guardé nada.',
    );

    var nombre = detectado.nombre;
    var descripcion = detectado.descripcion;
    var categoria = detectado.categoria;
    var costoInicial = '';
    var ventaInicial = '';

    while (mounted) {
      final alta = await _pedirPrecios(
        imagen: imagen,
        nombreInicial: nombre,
        descripcionInicial: descripcion,
        categoriaInicial: categoria,
        costoInicial: costoInicial,
        ventaInicial: ventaInicial,
      );
      if (!mounted) return;
      if (alta == null) {
        _publicarAsistente('No guardé el producto.');
        return;
      }

      nombre = alta.nombre;
      descripcion = alta.descripcion;
      categoria = alta.categoria;
      costoInicial = _precioCampo(alta.precioCompra);
      ventaInicial = _precioCampo(alta.precioVenta);

      final confirma = await _confirmarAlta(alta, imagen);
      if (!mounted) return;
      if (confirma != true) continue;

      try {
        final id = await _enrutador.guardarProducto(
          database: widget.database,
          nombre: alta.nombre,
          precioCompra: alta.precioCompra,
          precioVenta: alta.precioVenta,
        );
        if (!mounted) return;
        _publicarAsistente(
          'Guardé "${alta.nombre}" en productos (id $id).\n'
          'Precio de costo: ${_precioVisible(alta.precioCompra)}\n'
          'Precio de venta: ${_precioVisible(alta.precioVenta)}\n'
          'La descripción y la categoría se usaron para confirmar. '
          'No quedaron guardadas porque la tabla no tiene esas columnas.',
        );
      } on ChatIaException catch (e) {
        if (!mounted) return;
        _publicarAsistente(e.mensaje);
      } catch (_) {
        if (!mounted) return;
        _publicarAsistente('No pude guardar el producto en la base local.');
      }
      return;
    }
  }

  Future<_AltaProducto?> _pedirPrecios({
    required Uint8List imagen,
    required String nombreInicial,
    required String descripcionInicial,
    required String categoriaInicial,
    required String costoInicial,
    required String ventaInicial,
  }) {
    return showDialog<_AltaProducto>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _PreciosDialog(
          imagen: imagen,
          nombreInicial: nombreInicial,
          descripcionInicial: descripcionInicial,
          categoriaInicial: categoriaInicial,
          costoInicial: costoInicial,
          ventaInicial: ventaInicial,
        );
      },
    );
  }

  Future<bool?> _confirmarAlta(_AltaProducto alta, Uint8List imagen) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          title: const Text('Confirmar producto'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniatura(imagen),
              _dato('Nombre', alta.nombre),
              _dato('Descripción', alta.descripcion),
              _dato('Categoría', alta.categoria),
              _dato('Precio de costo', _precioVisible(alta.precioCompra)),
              _dato('Precio de venta', _precioVisible(alta.precioVenta)),
              const SizedBox(height: 4),
              const Text(
                'Si confirmás, se guardan el nombre y los dos precios. '
                'La descripción y la categoría se muestran acá y no se escriben en la base.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _publicarAsistente(String texto) {
    if (!mounted) return;
    setState(() {
      _entradas.add(_EntradaChat(MensajeChat(role: 'assistant', content: texto)));
    });
    _irAlFinal();
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
    _controlador.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            tooltip: _tieneClave ? 'Cambiar clave de OpenAI' : 'Cargar clave de OpenAI',
            onPressed: _pedirClave,
            icon: Icon(_tieneClave ? Icons.key : Icons.key_off),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _entradas.length,
              itemBuilder: (context, index) {
                final entrada = _entradas[index];
                final mensaje = entrada.mensaje;
                final esUsuario = mensaje.role == 'user';
                final colorTexto = esUsuario
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color;
                return Align(
                  alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: esUsuario
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entrada.imagen != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              entrada.imagen!,
                              height: 180,
                              width: MediaQuery.sizeOf(context).width * 0.62,
                              fit: BoxFit.cover,
                              cacheWidth: 800,
                              errorBuilder: (_, __, ___) => Text(
                                'No pude mostrar la foto.',
                                style: TextStyle(color: colorTexto),
                              ),
                            ),
                          ),
                          if (mensaje.content.isNotEmpty) const SizedBox(height: 8),
                        ],
                        if (mensaje.content.isNotEmpty)
                          Text(
                            mensaje.content,
                            style: TextStyle(color: colorTexto),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_enviando) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Subir foto del producto',
                    onPressed: _enviando ? null : _elegirFoto,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controlador,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(
                        hintText: 'Preguntá por el negocio o subí una foto',
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
            ),
          ),
        ],
      ),
    );
  }
}

bool _esPluginAusente(Object error) {
  return error.toString().contains('MissingPluginException');
}

String? _validarPrecio(String? raw) {
  final valor = _parsePrecio(raw ?? '');
  if (valor == null) return 'Ingresá un número';
  if (valor < 0) return 'No puede ser negativo';
  return null;
}

double? _parsePrecio(String raw) {
  var texto = raw.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (texto.isEmpty || texto == '-' || texto == ',' || texto == '.') {
    return null;
  }
  final negativo = texto.startsWith('-');
  texto = texto.replaceAll('-', '');
  if (texto.contains(',') && texto.contains('.')) {
    if (texto.lastIndexOf(',') > texto.lastIndexOf('.')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    } else {
      texto = texto.replaceAll(',', '');
    }
  } else if (texto.contains(',')) {
    texto = texto.replaceAll(',', '.');
  }
  final valor = double.tryParse(texto);
  if (valor == null) return null;
  return negativo ? -valor : valor;
}

String _precioCampo(double valor) {
  return valor.toStringAsFixed(2).replaceAll('.', ',');
}

String _precioVisible(double valor) => '\$ ${_precioCampo(valor)}';

Widget _miniatura(Uint8List bytes) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 140),
        child: Image.memory(
          bytes,
          height: 140,
          fit: BoxFit.cover,
          cacheWidth: 640,
          errorBuilder: (_, __, ___) => const Text('No pude mostrar la foto.'),
        ),
      ),
    ),
  );
}

Widget _dato(String etiqueta, String valor) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$etiqueta: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: valor),
        ],
      ),
    ),
  );
}
