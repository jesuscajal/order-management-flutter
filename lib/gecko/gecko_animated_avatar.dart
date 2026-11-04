import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gecko_mood.dart';

/// Animación sin paquetes externos. Se aplica al logo original (imagen plana).
/// Para parpadeo/patas/cola independientes hará falta un sprite por capas o Rive.
class GeckoAnimatedAvatar extends StatefulWidget {
  const GeckoAnimatedAvatar({
    super.key,
    required this.mood,
    this.size = 220,
  });

  final GeckoMood mood;
  final double size;

  @override
  State<GeckoAnimatedAvatar> createState() => _GeckoAnimatedAvatarState();
}

class _GeckoAnimatedAvatarState extends State<GeckoAnimatedAvatar>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _loop;
  late final AnimationController _reaction;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _reaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronizeAccessibility();
  }

  @override
  void didChangeAccessibilityFeatures() => _synchronizeAccessibility();

  void _synchronizeAccessibility() {
    final features = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    final reduce = (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        features.disableAnimations || features.reduceMotion;
    if (_reduceMotion != reduce || (!_reduceMotion && !_loop.isAnimating)) {
      _reduceMotion = reduce;
      if (reduce) {
        _loop.stop();
        _reaction.stop();
      } else {
        _loop.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant GeckoAnimatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood && !_reduceMotion) {
      if (widget.mood == GeckoMood.success || widget.mood == GeckoMood.error) {
        _reaction.forward(from: 0);
      } else {
        _reaction.reset();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loop.dispose();
    _reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gecko de GEXI: ${widget.mood.label}',
      image: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_loop, _reaction]),
            builder: (context, _) {
              final phase = _reduceMotion ? 0.0 : _loop.value * 2 * math.pi;
              final reaction = _reduceMotion ? 0.0 : _reaction.value;
              final mood = widget.mood;

              var vertical = math.sin(phase) * 3.8;
              var angle = math.sin(phase) * 0.018;
              var scale = 1 + math.sin(phase) * 0.012;
              var horizontal = 0.0;

              switch (mood) {
                case GeckoMood.idle:
                  break;
                case GeckoMood.thinking:
                  angle = math.sin(phase) * 0.055;
                  vertical = math.sin(phase * 1.5) * 4;
                  break;
                case GeckoMood.analyzing:
                  vertical = math.sin(phase * 1.2) * 5;
                  angle = math.sin(phase * 0.7) * 0.03;
                  break;
                case GeckoMood.success:
                  vertical -= math.sin(reaction * math.pi) * 24;
                  scale += math.sin(reaction * math.pi) * 0.10;
                  break;
                case GeckoMood.error:
                  horizontal = math.sin(reaction * 10 * math.pi) *
                      (1 - reaction) * 11;
                  angle = math.sin(reaction * 8 * math.pi) *
                      (1 - reaction) * 0.075;
                  break;
              }

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Aureola de fondo (no depende del recorte de la imagen).
                  Container(
                    width: widget.size * 0.75,
                    height: widget.size * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0x335CFCC0), Color(0x001BD1C5)],
                      ),
                    ),
                  ),
                  if (mood == GeckoMood.analyzing)
                    Transform.rotate(
                      angle: phase,
                      child: CustomPaint(
                        size: Size.square(widget.size * 0.93),
                        painter: _ScannerPainter(),
                      ),
                    ),
                  if (mood == GeckoMood.analyzing)
                    ..._orbitingIcons(phase),
                  Transform.translate(
                    offset: Offset(horizontal, vertical),
                    child: Transform.rotate(
                      angle: angle,
                      child: Transform.scale(
                        scale: scale,
                        child: Image.asset(
                          'assets/images/gecko_logo.png',
                          width: widget.size * 0.79,
                          height: widget.size * 0.79,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  if (mood == GeckoMood.thinking)
                    Positioned(
                      top: widget.size * 0.06,
                      right: widget.size * 0.05,
                      child: _ThinkingDots(phase: phase, size: widget.size),
                    ),
                  if (mood == GeckoMood.success)
                    ..._sparkles(reaction),
                  if (mood == GeckoMood.success)
                    Positioned(
                      right: 4,
                      bottom: widget.size * 0.13,
                      child: _StatusBubble(
                        icon: Icons.check_rounded,
                        color: const Color(0xFF21A84B),
                      ),
                    ),
                  if (mood == GeckoMood.error)
                    Positioned(
                      right: 5,
                      top: widget.size * 0.12,
                      child: _StatusBubble(
                        icon: Icons.error_outline_rounded,
                        color: const Color(0xFFE24B52),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _orbitingIcons(double phase) {
    const items = [Icons.bar_chart_rounded, Icons.inventory_2_outlined,
      Icons.shopping_bag_outlined];
    return List.generate(items.length, (i) {
      final theta = phase + (i * 2 * math.pi / items.length);
      final r = widget.size * 0.41;
      return Transform.translate(
        offset: Offset(math.cos(theta) * r, math.sin(theta) * r),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFB7EDEB)),
            boxShadow: const [BoxShadow(color: Color(0x1E03A5CC), blurRadius: 10)],
          ),
          child: Icon(items[i], size: widget.size * 0.084,
            color: const Color(0xFF087DC3)),
        ),
      );
    });
  }

  List<Widget> _sparkles(double t) {
    return List.generate(6, (i) {
      final theta = (i * 2 * math.pi / 6) - math.pi / 2;
      final distance = widget.size * (0.23 + 0.22 * t);
      return Transform.translate(
        offset: Offset(math.cos(theta) * distance,
            math.sin(theta) * distance),
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Icon(Icons.auto_awesome,
            size: widget.size * 0.085,
            color: i.isEven ? const Color(0xFF6ADD16) : const Color(0xFF05A8E9)),
        ),
      );
    });
  }
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots({required this.phase, required this.size});
  final double phase;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x180D416F), blurRadius: 16)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final pulse = (math.sin(phase * 2 - i * 0.8) + 1) / 2;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: CircleAvatar(
              radius: size * (0.012 + 0.005 * pulse),
              backgroundColor: Color.lerp(const Color(0xFF04B4DF),
                  const Color(0xFF6FD812), pulse),
            ),
          );
        }),
      ),
    );
  }
}

class _StatusBubble extends StatelessWidget {
  const _StatusBubble({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: const [BoxShadow(color: Color(0x24001026), blurRadius: 13)],
    ),
    child: Icon(icon, color: color, size: 28),
  );
}

class _ScannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero),
        radius: size.shortestSide * .45);
    final paint = Paint()
      ..color = const Color(0xFF10B4D7)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(rect, 0.2, 1.5, false, paint);
    paint.color = const Color(0xFF8DE71D);
    canvas.drawArc(rect, 3.1, 1.1, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
