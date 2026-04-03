import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PawPartyColors {
  /// Deep energetic blue (CTAs, key accents).
  static const Color primary = Color(0xFF0B5CB3);
  static const Color primaryLight = Color(0xFF3D8FED);
  static const Color primaryDark = Color(0xFF074A92);
  /// Electric cyan for secondary highlights.
  static const Color secondary = Color(0xFF00ACC1);
  static const Color secondaryLight = Color(0xFF4DD0E1);
  static const Color accent = Color(0xFF64B5F6);
  /// Peony / bloom accent from lifestyle reference — friendly CTAs & highlights.
  static const Color bloomPink = Color(0xFFFF5C8D);
  static const Color bloomPinkSoft = Color(0xFFFFE4EC);
  /// Deep teal (rug tones) for subtle overlays and depth.
  static const Color rugTeal = Color(0xFF0D5C63);
  /// Light oak / wood warmth for chips and dividers (not dull beige).
  static const Color warmOak = Color(0xFFE8DCC8);
  /// Airy cool white — bright like the reference room.
  static const Color background = Color(0xFFF7FAFD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE8F1FA);
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF00C853);
  static const Color textPrimary = Color(0xFF0D2137);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color textHint = Color(0xFF90A4AE);
  static const Color divider = Color(0xFFD4E3F0);
  /// Stars / rewards — bright amber on blue UI.
  static const Color pizzaGold = Color(0xFFFFCA28);
  static const Color pawBrown = Color(0xFF37474F);
}

class PawPartyTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PawPartyColors.primary,
        primary: PawPartyColors.primary,
        onPrimary: Colors.white,
        secondary: PawPartyColors.secondary,
        onSecondary: Colors.white,
        tertiary: PawPartyColors.bloomPink,
        onTertiary: Colors.white,
        surface: PawPartyColors.surface,
        error: PawPartyColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: PawPartyColors.background,
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        displayLarge: GoogleFonts.fredoka(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: PawPartyColors.textPrimary,
        ),
        displayMedium: GoogleFonts.fredoka(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: PawPartyColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.fredoka(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: PawPartyColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: PawPartyColors.textPrimary,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: PawPartyColors.textPrimary,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: PawPartyColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: PawPartyColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: PawPartyColors.textSecondary,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: PawPartyColors.surface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PawPartyColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PawPartyColors.primary,
          side: const BorderSide(color: PawPartyColors.primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PawPartyColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: PawPartyColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: PawPartyColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PawPartyColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PawPartyColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.nunito(
          color: PawPartyColors.textHint,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: PawPartyColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: PawPartyColors.divider.withValues(alpha: 0.5)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PawPartyColors.warmOak.withValues(alpha: 0.35),
        selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PawPartyColors.surface,
        selectedItemColor: PawPartyColors.primary,
        unselectedItemColor: PawPartyColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: PawPartyColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: PawPartyColors.textPrimary),
      ),
    );
  }
}
