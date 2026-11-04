/// Estados visuales del gecko de GEXI.
enum GeckoMood { idle, thinking, analyzing, success, error }

extension GeckoMoodInfo on GeckoMood {
  String get title => switch (this) {
        GeckoMood.idle => 'Estoy listo para ayudarte',
        GeckoMood.thinking => 'Pensando tu respuesta...',
        GeckoMood.analyzing => 'Analizando tu negocio...',
        GeckoMood.success => '¡Listo! Encontré la respuesta',
        GeckoMood.error => 'No pude completar la consulta',
      };

  String get subtitle => switch (this) {
        GeckoMood.idle => 'Preguntame sobre tus ventas, pedidos o stock.',
        GeckoMood.thinking => 'Estoy interpretando tu consulta.',
        GeckoMood.analyzing => 'Revisando la información necesaria.',
        GeckoMood.success => 'Ya podés consultar el resultado.',
        GeckoMood.error => 'Podés volver a intentarlo.',
      };

  String get label => switch (this) {
        GeckoMood.idle => 'Disponible',
        GeckoMood.thinking => 'Pensando',
        GeckoMood.analyzing => 'Analizando',
        GeckoMood.success => 'Completado',
        GeckoMood.error => 'Error',
      };
}
