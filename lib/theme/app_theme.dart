import 'package:flutter/material.dart';

class AppTheme {
  // Dynamic primary color - can change at runtime
  static Color primaryColor = const Color(0xFF1DB954);

  // Fixed semantic colors
  static const Color accentColor = Color(0xFFE53935);

  // Dark theme colors
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color cardColor = Color(0xFF282828);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color dividerColor = Color(0xFF333333);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF121212);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color lightDivider = Color(0xFFE0E0E0);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? backgroundColor : lightBackground,
      primaryColor: primaryColor,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primaryColor,
              secondary: accentColor,
              surface: surfaceColor,
              error: accentColor,
            )
          : ColorScheme.light(
              primary: primaryColor,
              secondary: accentColor,
              surface: lightSurface,
              error: accentColor,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? backgroundColor : lightBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: isDark ? textPrimary : lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: isDark ? textPrimary : lightTextPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? surfaceColor : lightSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: isDark ? textSecondary : lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: isDark ? cardColor : lightCard,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? dividerColor : lightDivider,
        thickness: 0.5,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontWeight: FontWeight.w500),
        bodyLarge:
            TextStyle(color: isDark ? textPrimary : lightTextPrimary),
        bodyMedium: TextStyle(
            color: isDark ? textSecondary : lightTextSecondary),
        labelLarge: TextStyle(
            color: isDark ? textPrimary : lightTextPrimary,
            fontWeight: FontWeight.w500),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: isDark ? dividerColor : lightDivider,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
      iconTheme:
          IconThemeData(color: isDark ? textPrimary : lightTextPrimary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primaryColor),
    );
  }
}
