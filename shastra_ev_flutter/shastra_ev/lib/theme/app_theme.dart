import 'package:flutter/material.dart';


class AppColors {
  // Backgrounds
  static const bg = Color(0xFF0A0C0F);
  static const bg2 = Color(0xFF111318);
  static const bg3 = Color(0xFF181C23);
  static const surface = Color(0xFF1E2330);
  static const surface2 = Color(0xFF252A38);
  static const border = Color(0xFF2A3248);

  // Accents
  static const cyan = Color(0xFF00E5FF);
  static const orange = Color(0xFFFF6B35);
  static const green = Color(0xFFA8FF3E);
  static const amber = Color(0xFFFFB700);
  static const red = Color(0xFFFF3D3D);
  static const purple = Color(0xFF9D4EDD);

  // Mode colors
  static const eco = Color(0xFFA8FF3E);
  static const sport = Color(0xFFFFB700);
  static const race = Color(0xFFFF3D3D);

  // Text
  static const textPrimary = Color(0xFFE8ECF4);
  static const textSecondary = Color(0xFF9BA3C2);
  static const textMuted = Color(0xFF6B7694);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyan,
          secondary: AppColors.orange,
          surface: AppColors.surface,
          background: AppColors.bg,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'monospace',
            fontSize: 52,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
          displayMedium: TextStyle(
            fontFamily: 'monospace',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          displaySmall: TextStyle(
            fontFamily: 'monospace',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'monospace',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 2,
          ),
          titleLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        // cardTheme: CardTheme(
        //   color: AppColors.bg2,
        //   elevation: 0,
        //   shape: RoundedRectangleBorder(
        //     borderRadius: BorderRadius.circular(16),
        //     side: const BorderSide(color: AppColors.border, width: 1),
        //   ),
        // ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg2,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 2,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.bg2,
          selectedItemColor: AppColors.cyan,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      );
}
