import 'package:flutter/material.dart';

/// Identidade visual do Saúde em Dia: roxo, turquesa e branco.
class AppColors {
  AppColors._();

  static const Color roxo = Color(0xFF7138D4);
  static const Color roxoEscuro = Color(0xFF5A2BB0);
  static const Color turquesa = Color(0xFF14B8C4);
  static const Color fundo = Color(0xFFF6F4FC);
  static const Color texto = Color(0xFF241B3D);
  static const Color textoSuave = Color(0xFF6E6787);

  static const Color sucesso = Color(0xFF1FA971);
  static const Color alerta = Color(0xFFE08A00);
  static const Color perigo = Color(0xFFD64545);

  static const LinearGradient gradiente = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [roxo, turquesa],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppColors.roxo,
      primary: AppColors.roxo,
      secondary: AppColors.turquesa,
      surface: Colors.white,
      error: AppColors.perigo,
    );

    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDCD6EE)),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fundo,
      fontFamily: null,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.fundo,
        foregroundColor: AppColors.texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.texto,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: borda,
        enabledBorder: borda,
        focusedBorder: borda.copyWith(
          borderSide: const BorderSide(
            color: AppColors.roxo,
            width: 2,
          ),
        ),
        errorBorder: borda.copyWith(
          borderSide: const BorderSide(color: AppColors.perigo),
        ),
        focusedErrorBorder: borda.copyWith(
          borderSide: const BorderSide(
            color: AppColors.perigo,
            width: 2,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.roxo,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.roxo,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.roxo, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.roxo,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEAE6F6)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.roxo.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((estados) {
          final ativo = estados.contains(WidgetState.selected);

          return TextStyle(
            fontSize: 12,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
            color: ativo ? AppColors.roxo : AppColors.textoSuave,
          );
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
