import 'package:flutter/material.dart';

abstract final class MUPhoneColors {
  static const Color primary = Color(0xFF68C1D5);
  static const Color background = Color(0xFF0F1418);
  static const Color card = Color(0xFF1A2228);
  static const Color hover = Color(0xFF24313A);
  static const Color border = Color(0xFF2B3A44);
  static const Color topBar = Color(0xFF242830);

  static const Color textPrimary = Color(0xFFE8EAED);
  static const Color textSecondary = Color(0xFF9AA0A6);
  static const Color textDisabled = Color(0xFF5F6368);

  static const Color statusOnline = Color(0xFF22C55E);
  static const Color statusFailed = Color(0xFFEF4444);
  static const Color statusLockedMine = Color(0xFF68C1D5);
  static const Color statusLockedOther = Color(0xFFF59E0B);
  static const Color statusOffline = Color(0xFF6B7280);
}

const _fontFamily = 'Segoe UI Variable';
const _fontFamilyFallback = ['Segoe UI', 'sans-serif'];

ThemeData buildMUPhoneTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MUPhoneColors.background,
    cardColor: MUPhoneColors.card,
    primaryColor: MUPhoneColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: MUPhoneColors.primary,
      secondary: MUPhoneColors.primary,
      surface: MUPhoneColors.card,
      error: MUPhoneColors.statusFailed,
      onPrimary: MUPhoneColors.background,
      onSecondary: MUPhoneColors.background,
      onSurface: MUPhoneColors.textPrimary,
      onError: MUPhoneColors.textPrimary,
    ),
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: MUPhoneColors.textPrimary,
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: MUPhoneColors.textPrimary,
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: MUPhoneColors.textPrimary,
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      bodySmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: MUPhoneColors.textSecondary,
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: MUPhoneColors.textSecondary,
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
      ),
    ),
    iconTheme: const IconThemeData(
      color: MUPhoneColors.textSecondary,
      size: 18,
    ),
    dividerColor: MUPhoneColors.border,
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: MUPhoneColors.hover,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MUPhoneColors.border),
      ),
      textStyle: const TextStyle(
        fontSize: 11,
        color: MUPhoneColors.textPrimary,
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFamilyFallback,
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MUPhoneColors.hover,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: MUPhoneColors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        isDense: true,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: MUPhoneColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: MUPhoneColors.border),
      ),
    ),
  );
}
