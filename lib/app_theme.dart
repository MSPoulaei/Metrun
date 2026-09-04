import 'package:flutter/material.dart';

/// Centralized color palette and design tokens for Metrun
class AppColors {
  AppColors._();

  // Primary brand palette (Tehran Metro Orange)
  static const Color primary = Color(0xFFE65100);
  static const Color primaryLight = Color(0xFFFF6D00);
  static const Color primaryDark = Color(0xFFBF360C);
  static const Color primaryContainer = Color(0xFFFFF7ED);
  static const Color primaryBorder = Color(0xFFFFEDD5);
  static const Color primaryText = Color(0xFF9A3412);

  // Surface & Neutral palette (Slate)
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  // Typography colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status & Wayfinding
  static const Color originStation = Color(0xFF10B981);
  static const Color destStation = Color(0xFFEF4444);
  static const Color transferBadgeBg = Color(0xFFFFF7ED);
  static const Color transferBadgeText = Color(0xFFC2410C);

  // Favorites / Star
  static const Color favoriteContainer = Color(0xFFFEF3C7);
  static const Color favoriteBorder = Color(0xFFFDE68A);
  static const Color favoriteText = Color(0xFF92400E);
  static const Color favoriteStar = Color(0xFFF59E0B);

  // Primary Gradient for AppBar & Prominent CTAs
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // Metro line colors
  static Color getMetroLineColor(int khat) {
    switch (khat) {
      case 1:
        return const Color(0xffef2e25); // Red
      case 2:
        return const Color(0xff04509f); // Dark Blue
      case 3:
        return const Color(0xff18C0F5); // Light Blue
      case 4:
        return const Color(0xffFAD103); // Yellow
      case 5:
        return const Color(0xff06885c); // Green
      case 6:
        return const Color(0xfff670ab); // Pink
      case 7:
        return const Color(0xff85317a); // Violet
      default:
        return const Color(0xff9E9E9E);
    }
  }
}

/// Centralized Material 3 Theme configuration for Metrun
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.primaryText,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.destStation,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // AppBar Theme (RTL friendly, high-contrast white foreground)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Card Theme (clean outlines, soft rounded 16dp corners, zero harsh shadows)
      cardTheme: CardTheme(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x35E65100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }
}
