import 'package:drift/drift.dart';

import '../data/app_database.dart';
import 'openai_chat_service.dart';
import 'openai_vision_service.dart';

/// Pedido ya clasificado: o es texto del chat, o es una foto de producto.
class SolicitudAsistente {
  final String apiKey;
  final String contextoNegocio;
  final List<MensajeChat> historial;
  final Uint8List? imagen;
  final String mimeImagen;

  const SolicitudAsistente._({
    required this.apiKey,
    this.contextoNegocio = '',
    this.historial = const [],
    this.imagen,
    this.mimeImagen = 'image/jpeg',
  });

  factory SolicitudAsistente.texto({
    required String apiKey,
    required String contextoNegocio,
    required List<MensajeChat> historial,
  }) {
    return SolicitudAsistente._(
      apiKey: apiKey,
      contextoNegocio: contextoNegocio,
      historial: historial,
    );
  }

  factory SolicitudAsistente.imagen({
    required String apiKey,
    required Uint8List bytes,
    required String mimeType,
  }) {
    return SolicitudAsistente._(
      apiKey: apiKey,
      imagen: bytes,
      mimeImagen: mimeType,
    );
  }
}

sealed class ResultadoEnrutado {
  const ResultadoEnrutado();
}

class ResultadoTexto extends ResultadoEnrutado {
  final String texto;
  const ResultadoTexto(this.texto);
}

class ResultadoVision extends ResultadoEnrutado {
  final ProductoDetectado producto;
  const ResultadoVision(this.producto);
}

/// RF-031 a RF-034, versión simple.
/// El texto va al chat actual. La imagen va al modelo con visión.
/// Los dos usan gpt-4o-mini. No hay otros proveedores ni un presupuesto.
class AsistenteEnrutador {
  final OpenAiChatService _chat;
  final OpenAiVisionService _vision;

  AsistenteEnrutador({
    OpenAiChatService? chat,
    OpenAiVisionService? vision,
  })  : _chat = chat ?? OpenAiChatService(),
        _vision = vision ?? OpenAiVisionService();

  Future<ResultadoEnrutado> enrutar(SolicitudAsistente solicitud) async {
    final imagen = solicitud.imagen;
    if (imagen != null) {
      final producto = await _vision.analizarProducto(
        apiKey: solicitud.apiKey,
        bytes: imagen,
        mimeType: solicitud.mimeImagen,
      );
      return ResultadoVision(producto);
    }

    final texto = await _chat.responder(
      apiKey: solicitud.apiKey,
      contextoNegocio: solicitud.contextoNegocio,
      historial: solicitud.historial,
    );
    return ResultadoTexto(texto);
  }

  /// Escribe nombre y precios en Productos. Descripción y categoría no tienen columna.
  Future<int> guardarProducto({
    required AppDatabase database,
    required String nombre,
    required double precioCompra,
    required double precioVenta,
  }) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw ChatIaException('El producto necesita un nombre para guardarse.');
    }
    if (precioCompra.isNaN ||
        precioVenta.isNaN ||
        precioCompra.isInfinite ||
        precioVenta.isInfinite) {
      throw ChatIaException('Los precios no son válidos.');
    }
    if (precioCompra < 0 || precioVenta < 0) {
      throw ChatIaException('Los precios no pueden ser negativos.');
    }

    return database.into(database.productos).insert(
          ProductosCompanion.insert(
            nombre: limpio,
            precioCompra: Value(precioCompra),
            precioVenta: Value(precioVenta),
          ),
        );
  }
}
