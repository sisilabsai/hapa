import 'package:flutter/material.dart';

class HapaColors {
  static const ochre = Color(0xFFC47B2B);
  static const ochreMuted = Color(0xFFE8A84A);
  static const deep = Color(0xFF1A1208);
  static const cream = Color(0xFFF5EFE0);
  static const rust = Color(0xFF8B3A1F);
  static const sage = Color(0xFF3D6B38);
  static const sand = Color(0xFFDDD0B3);
  static const muted = Color(0xFF7A6E5F);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: HapaColors.ochre,
          onPrimary: Colors.white,
          secondary: HapaColors.deep,
          onSecondary: HapaColors.cream,
          surface: Colors.white,
          onSurface: HapaColors.deep,
          error: Color(0xFFB00020),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F5F0),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: HapaColors.deep,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: HapaColors.deep,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: HapaColors.ochre,
          unselectedItemColor: Color(0xFFA8A29E),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: HapaColors.ochre,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: HapaColors.ochre, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: Color(0xFFE7E5E4)),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w900),
          displayMedium: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          labelSmall: TextStyle(fontFamily: 'JetBrainsMono', letterSpacing: 1.2),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: HapaColors.ochre,
          onPrimary: HapaColors.deep,
          secondary: HapaColors.ochreMuted,
          surface: Color(0xFF1E1410),
          onSurface: HapaColors.cream,
        ),
        scaffoldBackgroundColor: HapaColors.deep,
        fontFamily: 'Inter',
      );
}
