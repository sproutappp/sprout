import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class OnboardingCtaWidget extends StatefulWidget {
  final VoidCallback onGetStarted;

  const OnboardingCtaWidget({
    super.key,
    required this.onGetStarted,
  });

  @override
  State<OnboardingCtaWidget> createState() => _OnboardingCtaWidgetState();
}

class _OnboardingCtaWidgetState extends State<OnboardingCtaWidget> {
  bool _getStartedPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}
