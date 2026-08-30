import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class OnboardingBackgroundWidget extends StatefulWidget {
  const OnboardingBackgroundWidget({super.key});

  @override
  State<OnboardingBackgroundWidget> createState() =>
      _OnboardingBackgroundWidgetState();
}

class _OnboardingBackgroundWidgetState extends State<OnboardingBackgroundWidget>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _glowController;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    final rng = math.Random(42);
    _particles = List.generate(28, (i) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 1.5 + rng.nextDouble() * 2.5,
        speed: 0.015 + rng.nextDouble() * 0.025,
        phase: rng.nextDouble() * math.pi * 2,
        opacity: 0.15 + rng.nextDouble() * 0.35,
        isGreen: rng.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_particleController, _glowController]),
      builder: (context, _) {
        return CustomPaint(
          painter: _BackgroundPainter(
            particles: _particles,
            time: _particleController.value,
            glowPulse: _glowController.value,
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [Color(0xFF0F1F13), Color(0xFF0A0F0D)],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Particle {
  final double x, y, size, speed, phase, opacity;
  final bool isGreen;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
    required this.isGreen,
  });
}

class _BackgroundPainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  final double glowPulse;

  const _BackgroundPainter({
    required this.particles,
    required this.time,
    required this.glowPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ambient glow at top-center
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppTheme.primaryGreen.withOpacity(0.06 + glowPulse * 0.04),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.25),
              radius: size.width * 0.7,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // Cyan glow bottom-right
    final cyanGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppTheme.cyanAccent.withOpacity(0.04 + glowPulse * 0.02),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.85, size.height * 0.75),
              radius: size.width * 0.5,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), cyanGlow);

    // Floating particles
    for (final p in particles) {
      final drift = math.sin(time * math.pi * 2 * p.speed + p.phase) * 0.02;
      final px = (p.x + drift) * size.width;
      final py = ((p.y - time * p.speed * 0.3) % 1.0) * size.height;

      final paint = Paint()
        ..color = (p.isGreen ? AppTheme.primaryGreen : AppTheme.cyanAccent)
            .withOpacity(p.opacity * (0.7 + glowPulse * 0.3))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => true;
}
