import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class AuthHeaderWidget extends StatelessWidget {
  const AuthHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withAlpha(51),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/logosprout-1787939643364.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              semanticLabel: 'Sprout logo',
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Welcome to Sprout',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your memories, your circles, your world.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            color: AppTheme.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
