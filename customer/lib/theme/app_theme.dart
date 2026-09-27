import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Which app is currently being themed / authenticated.
enum AppRole { customer, provider }

class AppTheme {
  /// Returns the ThemeData for the given role (Customer = Icon Navy,
  /// Provider = Fleet Blue), built from the Seer color reference table.
  static ThemeData of(AppRole role) {
    final bg = role == AppRole.customer
        ? CustomerColors.background
        : ProviderColors.background;
    final panel = role == AppRole.customer
        ? CustomerColors.darkPanel
        : ProviderColors.darkPanel;
    final accent = role == AppRole.customer
        ? CustomerColors.accent
        : ProviderColors.accent;
    final border = role == AppRole.customer
        ? CustomerColors.cardBorder
        : ProviderColors.cardBorder;
    final primaryText = role == AppRole.customer
        ? CustomerColors.primaryText
        : ProviderColors.primaryText;
    final secondaryText = role == AppRole.customer
        ? CustomerColors.secondaryText
        : ProviderColors.secondaryText;

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        surface: bg,
        error: AppStatusColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: panel,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: primaryText, fontSize: 16),
        bodyMedium: TextStyle(color: primaryText, fontSize: 14),
        bodySmall: TextStyle(color: secondaryText, fontSize: 12),
        titleLarge: TextStyle(
          color: primaryText,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppStatusColors.error),
        ),
        labelStyle: TextStyle(color: secondaryText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
    );
  }
}
