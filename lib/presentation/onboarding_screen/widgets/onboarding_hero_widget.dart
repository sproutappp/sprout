import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class OnboardingHeroWidget extends StatefulWidget {
  const OnboardingHeroWidget({super.key});

  @override
  State<OnboardingHeroWidget> createState() => _OnboardingHeroWidgetState();
}

class _OnboardingHeroWidgetState extends State<OnboardingHeroWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo with glow pulse
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(
                      0.18 * _pulseAnim.value,
                    ),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                  BoxShadow(
                    color: AppTheme.cyanAccent.withOpacity(
                      0.08 * _pulseAnim.value,
                    ),
                    blurRadius: 60,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/images/logosprout-1787939643364.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              semanticLabel:
                  'Sprout — continuous S loop with central dot representing the person at the heart of every memory',
            ),
          ),
        ),

        const SizedBox(height: 28),

        // App name
        const Text(
          'Sprout',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -1.5,
            height: 1.0,
          ),
        ),

        const SizedBox(height: 10),

        // Tagline with gradient
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Memories. Together.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
