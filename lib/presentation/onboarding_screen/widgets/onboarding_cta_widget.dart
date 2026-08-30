import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class OnboardingCtaWidget extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const OnboardingCtaWidget({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  State<OnboardingCtaWidget> createState() => _OnboardingCtaWidgetState();
}

class _OnboardingCtaWidgetState extends State<OnboardingCtaWidget> {
  bool _getStartedPressed = false;
  bool _googlePressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary CTA — Get Started
        GestureDetector(
          onTapDown: (_) => setState(() => _getStartedPressed = true),
          onTapUp: (_) {
            setState(() => _getStartedPressed = false);
            widget.onGetStarted();
          },
          onTapCancel: () => setState(() => _getStartedPressed = false),
          child: AnimatedScale(
            scale: _getStartedPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withAlpha(77),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Divider
        Row(
          children: [
            Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
          ],
        ),

        const SizedBox(height: 14),

        // Google CTA
        GestureDetector(
          onTapDown: (_) => setState(() => _googlePressed = true),
          onTapUp: (_) {
            setState(() => _googlePressed = false);
            widget.onSignIn();
          },
          onTapCancel: () => setState(() => _googlePressed = false),
          child: AnimatedScale(
            scale: _googlePressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outline, width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google G icon (drawn)
                  _GoogleIcon(),
                  const SizedBox(width: 10),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Simplified Google G
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
