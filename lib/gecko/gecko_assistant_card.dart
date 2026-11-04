import 'package:flutter/material.dart';
import 'gecko_animated_avatar.dart';
import 'gecko_controller.dart';
import 'gecko_mood.dart';

/// Componente reutilizable para pantalla de chat, dashboard u onboarding.
class GeckoAssistantCard extends StatelessWidget {
  const GeckoAssistantCard({
    super.key,
    required this.controller,
    this.compact = false,
    this.avatarSize,
  });

  final GeckoAssistantController controller;
  final bool compact;
  final double? avatarSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final mood = controller.mood;
        final success = mood == GeckoMood.success;
        final error = mood == GeckoMood.error;
        final stateColor = error
            ? const Color(0xFFD84E59)
            : success
                ? const Color(0xFF15994D)
                : const Color(0xFF0879BF);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 18 : 22,
            vertical: compact ? 18 : 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFDCECF5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x130C376A),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Color(0xFF06B385), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Asistente Gexi',
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF102649))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: stateColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      mood.label,
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 12, color: stateColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GeckoAnimatedAvatar(
                mood: mood,
                size: avatarSize ?? (compact ? 158 : 238),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08), end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Semantics(
                  key: ValueKey(mood),
                  liveRegion: true,
                  child: Column(
                    children: [
                      Text(mood.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: compact ? 17 : 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF12284D))),
                      const SizedBox(height: 8),
                      Text(mood.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5,
                              height: 1.4, color: Color(0xFF657690))),
                    ],
                  ),
                ),
              ),
              if (mood == GeckoMood.thinking || mood == GeckoMood.analyzing)
                Padding(
                  padding: const EdgeInsets.only(top: 17),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
                            WidgetsBinding.instance.platformDispatcher
                                .accessibilityFeatures.reduceMotion
                        ? const SizedBox(height: 4,
                            child: ColoredBox(color: Color(0xFF06B9CF)))
                        : const LinearProgressIndicator(
                            minHeight: 4,
                            backgroundColor: Color(0xFFE8F5F9),
                            color: Color(0xFF06B9CF),
                            // Sin porcentaje falso: duración de la IA es desconocida.
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
