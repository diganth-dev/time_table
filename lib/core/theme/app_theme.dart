import 'package:flutter/material.dart';

class AppTheme {
  // Stitch Design Palette
  static const primaryColor = Color(0xFF0B1C30); // Deep Obsidian / Slate
  static const primaryContainer = Color(0xFF131B2E);
  static const secondaryColor = Color(0xFF0051D5); // Stitch Royal Academic Blue
  static const secondaryContainer = Color(0xFF316BF3);
  static const secondaryFixed = Color(0xFFDBE1FF);
  static const accentColor = Color(0xFFF59E0B); // Amber Accent
  static const errorColor = Color(0xFFBA1A1A); // Crimson Red
  static const errorContainer = Color(0xFFFFDAD6);
  static const successColor = Color(0xFF009668); // Stitch Emerald Mint
  static const successContainer = Color(0xFF6FFBBE);
  static const surfaceColor = Color(0xFFF8F9FF); // Stitch Tinted Surface
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE5EEFF);
  static const surfaceContainerHigh = Color(0xFFDCE9FF);
  static const onSurface = Color(0xFF0B1C30);
  static const onSurfaceVariant = Color(0xFF45464D);
  static const outline = Color(0xFF76777D);
  static const outlineVariant = Color(0xFFC6C6CD);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: secondaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: surfaceColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: surfaceColor,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: surfaceContainer),
      ),
      color: surfaceContainerLowest,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceContainerLowest,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: Color(0x0A000000),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: surfaceContainerHigh),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: secondaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      labelStyle: const TextStyle(fontSize: 12, color: onSurfaceVariant, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(fontSize: 12.5, color: outline),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        backgroundColor: surfaceContainerLowest,
        side: const BorderSide(color: surfaceContainerHigh),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: surfaceContainerLowest,
      selectedIconTheme: IconThemeData(color: secondaryColor),
      unselectedIconTheme: IconThemeData(color: onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(color: onSurfaceVariant, fontSize: 12),
    ),
  );
}
