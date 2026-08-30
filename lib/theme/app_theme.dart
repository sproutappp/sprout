// THEME LOCK: dark — source: user prompt ("dark-first interface"), Gen-Z social domain signal
// Scaffold.backgroundColor = AppTheme.backgroundDark — ALL screens

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF39FF8C);
  static const Color primaryGreenDim = Color(0xFF1FCC6A);
  static const Color primaryGreenGlow = Color(0x3339FF8C);
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color cyanGlow = Color(0x2200E5FF);

  // ── Dark Surfaces ──────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0A0F0D);
  static const Color surfaceDark = Color(0xFF111A14);
  static const Color surfaceVariantDark = Color(0xFF1A2B1E);
  static const Color surfaceElevatedDark = Color(0xFF1E2F22);
  static const Color cardDark = Color(0xFF152019);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE8F5EC);
  static const Color textSecondary = Color(0xFFB0CDB8);
  static const Color textMuted = Color(0xFF7A9A82);
  static const Color textDisabled = Color(0xFF4A6050);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF39FF8C);
  static const Color warning = Color(0xFFFFB84D);
  static const Color error = Color(0xFFFF5C5C);
  static const Color outline = Color(0xFF2A3D2E);
  static const Color outlineVariant = Color(0xFF1E2F22);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, cyanAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0F0D), Color(0xFF0D1610)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xCC0A0F0D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Light Theme (required — domain is dark-first) ─────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      onPrimary: Colors.black,
      secondary: cyanAccent,
      onSecondary: Colors.black,
      surface: const Color(0xFFF5FFF8),
      onSurface: const Color(0xFF0A1A0E),
      error: error,
      onError: Colors.white,
      outline: const Color(0xFFCCDDD0),
      outlineVariant: const Color(0xFFEEF5EF),
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F9F3),
    textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme),
    appBarTheme: AppBarThemeData(
      backgroundColor: const Color(0xFFF0F9F3),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: GoogleFonts.manrope(
        color: const Color(0xFF0A1A0E),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // ── Dark Theme (primary) ──────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryGreen,
      onPrimary: Colors.black,
      primaryContainer: primaryGreenGlow,
      onPrimaryContainer: primaryGreen,
      secondary: cyanAccent,
      onSecondary: Colors.black,
      secondaryContainer: cyanGlow,
      onSecondaryContainer: cyanAccent,
      surface: surfaceDark,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariantDark,
      error: error,
      onError: Colors.white,
      outline: outline,
      outlineVariant: outlineVariant,
    ),
    scaffoldBackgroundColor: backgroundDark,
    textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme)
        .copyWith(
          displayLarge: GoogleFonts.manrope(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -1.5,
          ),
          displayMedium: GoogleFonts.manrope(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -1.0,
          ),
          headlineLarge: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          headlineMedium: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          headlineSmall: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleLarge: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleMedium: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.1,
          ),
          titleSmall: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
          bodyLarge: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: textPrimary,
          ),
          bodyMedium: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          bodySmall: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textMuted,
          ),
          labelLarge: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.2,
          ),
          labelSmall: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: GoogleFonts.manrope(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: outline, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surfaceVariantDark.withAlpha(153),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: outline, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      labelStyle: GoogleFonts.manrope(color: textMuted, fontSize: 14),
      hintStyle: GoogleFonts.manrope(color: textDisabled, fontSize: 14),
      errorStyle: GoogleFonts.manrope(color: error, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: outline, width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreen,
        textStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.black,
      elevation: 8,
      extendedPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
    ),
    dividerTheme: const DividerThemeData(
      color: outline,
      thickness: 0.5,
      space: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: textSecondary),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariantDark,
      labelStyle: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      side: const BorderSide(color: outline, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
  );
}
