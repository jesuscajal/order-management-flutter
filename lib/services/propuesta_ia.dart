import 'dart:convert';

import '../data/apariencia_tienda.dart';
import 'asistente/memoria_asistente.dart';
import 'fuente_ia.dart';
import 'negocio_local.dart';
import 'openai_chat_service.dart';

/// Lo que la IA puede proponer al leer la descripción del negocio.
class PropuestaDesdeTexto {
  const PropuestaDesdeTexto({
    required this.rubros,
    required this.atributos,
    required this.apariencia,
  });

  final List<String> rubros;
  final List<String> atributos;
  final AparienciaTienda apariencia;
}

/// La IA solo elige valores de las listas del producto. Lo demás se descarta.
class PropuestaIa {
  const PropuestaIa();

  static final atributosPermitidos = {
    for (final rubro in CatalogoRubros.todos) ...rubro.atributos,
    'Peso',
    'Sabor',
    'Presentación',
    'Medida',
    'Vencimiento',
  };

  Future<PropuestaDesdeTexto?> desdeDescripcion(String texto) async {
    final relato = texto.trim();
    if (relato.isEmpty) return null;
    final json = await _pedir(
      sistema: '''
Devolvé solo un objeto JSON con estas claves:
- rubros: lista de ids. Ids válidos: ${CatalogoRubros.todos.map((rubro) => rubro.id).join(', ')}.
- atributos: datos que hay que pedir al cargar un producto. Solo estos: ${atributosPermitidos.join(', ')}.
- paleta: uno de ${AparienciaTienda.paletas.join(', ')}.
- forma: uno de ${AparienciaTienda.formas.join(', ')}.
- boton: uno de ${AparienciaTienda.botones.join(', ')}.
- portada: uno de ${AparienciaTienda.portadas.join(', ')}.
No inventes claves ni valores. Si el relato no alcanza, usá rubros ["general"].
''',
      pedido: relato,
    );
    if (json == null) return null;
    final rubros = _rubros(json['rubros']);
    if (rubros.isEmpty) return null;
    final atributos = _atributos(json['atributos']);
    final base = PropuestaRubro.desdeIds(rubros);
    return PropuestaDesdeTexto(
      rubros: rubros,
      atributos: atributos.isEmpty ? base.atributos : atributos,
      apariencia: _baseDe(rubros).copiar(
        paleta: json['paleta']?.toString(),
        forma: json['forma']?.toString(),
        boton: json['boton']?.toString(),
        portada: json['portada']?.toString(),
      ),
    );
  }

  /// Cambia el diseño solo con funciones conocidas. Si ninguna aplica, devuelve null.
  Future<AparienciaTienda?> ajustarDiseno({
    required AparienciaTienda actual,
    required String pedido,
  }) async {
    final texto = pedido.trim();
    if (texto.isEmpty) return null;
    final json = await _pedir(
      sistema: '''
Devolvé solo un objeto JSON: {"funciones":[{"nombre":"...","valor":"..."}]}.
Funciones permitidas y valores:
- poner_paleta: ${AparienciaTienda.paletas.join(', ')}
- poner_forma: ${AparienciaTienda.formas.join(', ')}
- poner_boton: ${AparienciaTienda.botones.join(', ')}
- poner_portada: ${AparienciaTienda.portadas.join(', ')}
No uses otra función. Si el pedido no entra en esas opciones, devolvé {"funciones":[]}.
Diseño actual: ${jsonEncode(actual.toJson())}.
''',
      pedido: texto,
    );
    if (json == null) return null;
    final crudas = json['funciones'];
    if (crudas is! List || crudas.isEmpty) return null;
    var siguiente = actual;
    for (final item in crudas) {
      if (item is! Map) continue;
      final nombre = item['nombre']?.toString() ?? '';
      final valor = item['valor']?.toString() ?? '';
      siguiente = siguiente.aplicarFuncion(nombre, valor);
    }
    if (siguiente == actual) return null;
    return siguiente;
  }

  Future<Map<String, dynamic>?> _pedir({
    required String sistema,
    required String pedido,
  }) async {
    final local = await const FuenteIa().leerModeloLocal();
    if (local == null ||
        local.baseUrl.trim().isEmpty ||
        local.modelo.trim().isEmpty) {
      return null;
    }
    final modelo = local.modelo.trim();
    final chat = OpenAiChatService();
    try {
      final contenido = await chat.responderJson(
        apiKey: local.clave,
        systemPrompt: sistema,
        contextoNegocio: '',
        historial: [MensajeChat(role: 'user', content: pedido)],
        baseUrl: local.baseUrl,
        modeloPedido: modelo,
      );
      await const MemoriaAsistente().anotarUso(
        chat.ultimoUso,
        origen: 'pagina',
        modelo: modelo,
      );
      final decoded = jsonDecode(contenido);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  AparienciaTienda _baseDe(List<String> rubros) {
    final ids = rubros.toSet();
    return AparienciaTienda.paraRubros(
      gastronomiaSola:
          ids.length == 1 && ids.contains(CatalogoRubros.gastronomia.id),
      indumentaria: ids.contains(CatalogoRubros.indumentaria.id),
      tecnologia: ids.contains(CatalogoRubros.tecnologia.id),
    );
  }

  List<String> _rubros(Object? crudo) {
    if (crudo is! List) return const [];
    final ids = <String>[];
    for (final item in crudo) {
      final id = _idRubro(item.toString());
      if (id != null && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  String? _idRubro(String crudo) {
    final limpio = crudo.trim().toLowerCase();
    for (final rubro in CatalogoRubros.todos) {
      if (rubro.id == limpio || rubro.nombre.toLowerCase() == limpio) {
        return rubro.id;
      }
    }
    return null;
  }

  List<String> _atributos(Object? crudo) {
    if (crudo is! List) return const [];
    final lista = <String>[];
    for (final item in crudo) {
      final canonico = _atributo(item.toString());
      if (canonico != null && !lista.contains(canonico)) lista.add(canonico);
    }
    return lista;
  }

  String? _atributo(String crudo) {
    final limpio = crudo.trim().toLowerCase();
    for (final atributo in atributosPermitidos) {
      if (atributo.toLowerCase() == limpio) return atributo;
    }
    return null;
  }
}
