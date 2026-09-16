import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class AboutSproutScreen extends StatelessWidget {
  const AboutSproutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppTheme.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'About Sprout',
          style: GoogleFonts.manrope(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.outline, width: 0.8),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryGreen.withAlpha(25),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withAlpha(90),
                    ),
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
                    color: AppTheme.primaryGreen,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Sprout',
                  style: GoogleFonts.manrope(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share and relive memories with your circles.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'About Sprout',
            body:
                'Sprout is a private space for creating, sharing, and reliving memories with the people and circles that matter to you. Capture moments, stay connected, and keep your memories together in one place.',
          ),
          const SizedBox(height: 22),
          _Section(
            title: 'Version',
            body: '2.0.0 (build 13)',
          ),
          const SizedBox(height: 22),
          _Section(
            title: 'Contact',
            body: 'For privacy or app-related enquiries: mahesh@akshatmedia.in',
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Made with care for meaningful memories.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          body,
          style: GoogleFonts.manrope(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
