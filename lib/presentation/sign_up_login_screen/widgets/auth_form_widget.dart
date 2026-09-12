import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import './phone_auth_widget.dart';

// V5 — Glassmorphism auth options
// LOCKED: existing Google + phone OTP UI retained; email/password signup/login removed.

class AuthFormWidget extends StatelessWidget {
  final VoidCallback onGoogleSignIn;
  final VoidCallback onPhoneVerified;

  const AuthFormWidget({
    super.key,
    required this.onGoogleSignIn,
    required this.onPhoneVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Google button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: onGoogleSignIn,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.outline, width: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Divider
        Row(
          children: [
            Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or use your phone',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            Expanded(child: Container(height: 0.5, color: AppTheme.outline)),
          ],
        ),

        const SizedBox(height: 16),

        // Phone OTP sign-in — self-contained, isolated from Supabase
        PhoneAuthWidget(onVerified: onPhoneVerified),
      ],
    );
  }
}
