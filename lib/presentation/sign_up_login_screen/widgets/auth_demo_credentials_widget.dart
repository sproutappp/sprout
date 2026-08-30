import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';

class AuthDemoCredentialsWidget extends StatelessWidget {
  final void Function(String email, String password) onUse;

  const AuthDemoCredentialsWidget({super.key, required this.onUse});

  static const _email = 'maya@sprout.app';
  static const _password = 'Sprout2026!';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreenGlow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withAlpha(51),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 6),
              const Text(
                'Demo Account',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CredentialRow(
            label: 'Email',
            value: _email,
            onCopy: () => Clipboard.setData(const ClipboardData(text: _email)),
          ),
          const SizedBox(height: 6),
          _CredentialRow(
            label: 'Password',
            value: _password,
            onCopy: () =>
                Clipboard.setData(const ClipboardData(text: _password)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => onUse(_email, _password),
            child: Container(
              width: double.infinity,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Use Demo Account',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CredentialRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: onCopy,
          child: const Icon(
            Icons.copy_rounded,
            size: 14,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
