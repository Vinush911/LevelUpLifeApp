import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

Future<void> showLevelUpOverlay(BuildContext context, int newLevel) {
  final completer = Completer<void>();
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => LevelUpOverlay(
      newLevel: newLevel,
      onComplete: () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    ),
  );

  overlay.insert(overlayEntry);
  return completer.future;
}

class LevelUpOverlay extends StatefulWidget {
  final int newLevel;
  final VoidCallback onComplete;

  const LevelUpOverlay({super.key, required this.newLevel, required this.onComplete});

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500));

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut.flipped));

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);

    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: IgnorePointer(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(300, 300),
                    painter: ParticlePainter(progress: _controller.value),
                  );
                },
              ),
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "LEVEL UP!",
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                          color: Colors.yellowAccent,
                          shadows: [
                            Shadow(
                                blurRadius: 15.0,
                                color: Colors.orange.shade800,
                                offset: const Offset(0, 0))
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "You are now Level ${widget.newLevel}!",
                        style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w600),
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
}

class ParticlePainter extends CustomPainter {
  final double progress;
  final List<Particle> particles = [];
  final Random random = Random();

  ParticlePainter({required this.progress}) {
    for (int i = 0; i < 50; i++) {
      particles.add(Particle(random));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity((1 - progress) * 0.8)
        ..style = PaintingStyle.fill;

      final currentRadius = particle.radius * (1 - progress);
      final path = particle.path * progress * 150;

      canvas.drawCircle(center + path, currentRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  final Color color;
  final double radius;
  final Offset path;

  Particle(Random random)
      : color = [Colors.yellow, Colors.orange, Colors.amber, Colors.white]
  [random.nextInt(4)],
        radius = random.nextDouble() * 4 + 2,
        path = Offset.fromDirection(random.nextDouble() * 2 * pi, 1);
}
