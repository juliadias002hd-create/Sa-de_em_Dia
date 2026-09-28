import 'package:flutter/material.dart';

/// Cores da marca Saúde em Dia: roxo, turquesa e branco.
///
/// São as cores que NÃO mudam entre o tema claro e o escuro. As cores que
/// mudam (texto, fundo, cartões...) vêm do tema: use `context.texto`,
/// `context.textoSuave`, `context.fundo`, `context.cartao`, `context.borda`
/// e `context.destaque` (veja [CoresDoTema]).
class AppColors {
  AppColors._();

  static const Color roxo = Color(0xFF7138D4);
  static const Color roxoEscuro = Color(0xFF5A2BB0);
  static const Color turquesa = Color(0xFF14B8C4);

  static const Color sucesso = Color(0xFF1FA971);
  static const Color alerta = Color(0xFFE08A00);
  static const Color perigo = Color(0xFFD64545);

  static const LinearGradient gradiente = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [roxo, turquesa],
  );
}


/// Cores que mudam conforme o tema (claro ou escuro).
extension CoresDoTema on BuildContext {
  ColorScheme get _esquema => Theme.of(this).colorScheme;

  /// Texto principal.
  Color get texto => _esquema.onSurface;

  /// Texto secundário (legendas, dicas).
  Color get textoSuave => _esquema.onSurfaceVariant;

  /// Fundo das telas.
  Color get fundo => Theme.of(this).scaffoldBackgroundColor;

  /// Fundo de cartões e caixas.
  Color get cartao => _esquema.surface;

  /// Linhas e contornos discretos.
  Color get borda => _esquema.outlineVariant;

  /// Contorno dos campos e caixas de seleção.
  Color get bordaCampo => _esquema.outline;

  /// Roxo para ícones e textos de destaque (mais claro no tema escuro, para
  /// ter contraste sobre o fundo escuro).
  Color get destaque => _esquema.primary;

  bool get temaEscuro => Theme.of(this).brightness == Brightness.dark;
}


/// Paleta de um tema.
class _Paleta {
  final Brightness brilho;
  final Color fundo;
  final Color cartao;
  final Color texto;
  final Color textoSuave;
  final Color borda;
  final Color bordaCampo;
  final Color destaque;

  const _Paleta({
    required this.brilho,
    required this.fundo,
    required this.cartao,
    required this.texto,
    required this.textoSuave,
    required this.borda,
    required this.bordaCampo,
    required this.destaque,
  });

  static const claro = _Paleta(
    brilho: Brightness.light,
    fundo: Color(0xFFF6F4FC),
    cartao: Colors.white,
    texto: Color(0xFF241B3D),
    textoSuave: Color(0xFF6E6787),
    borda: Color(0xFFEAE6F6),
    bordaCampo: Color(0xFFDCD6EE),
    destaque: AppColors.roxo,
  );

  static const escuro = _Paleta(
    brilho: Brightness.dark,
    fundo: Color(0xFF14111F),
    cartao: Color(0xFF1F1A30),
    texto: Color(0xFFEEEAF8),
    textoSuave: Color(0xFFB2AACB),
    borda: Color(0xFF342E4A),
    bordaCampo: Color(0xFF4A4266),
    destaque: Color(0xFFB79EFF),
  );
}


class AppTheme {
  AppTheme._();

  static ThemeData get claro => _montar(_Paleta.claro);

  static ThemeData get escuro => _montar(_Paleta.escuro);

  static ThemeData _montar(_Paleta p) {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppColors.roxo,
      brightness: p.brilho,
      primary: p.destaque,
      secondary: AppColors.turquesa,
      surface: p.cartao,
      onSurface: p.texto,
      onSurfaceVariant: p.textoSuave,
      outlineVariant: p.borda,
      outline: p.bordaCampo,
      error: AppColors.perigo,
    );

    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.bordaCampo),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brilho,
      colorScheme: esquema,
      scaffoldBackgroundColor: p.fundo,

      appBarTheme: AppBarTheme(
        backgroundColor: p.fundo,
        foregroundColor: p.texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.texto,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cartao,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: borda,
        enabledBorder: borda,
        focusedBorder: borda.copyWith(
          borderSide: BorderSide(color: p.destaque, width: 2),
        ),
        errorBorder: borda.copyWith(
          borderSide: const BorderSide(color: AppColors.perigo),
        ),
        focusedErrorBorder: borda.copyWith(
          borderSide: const BorderSide(color: AppColors.perigo, width: 2),
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
          foregroundColor: p.destaque,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: p.destaque, width: 1.5),
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
          foregroundColor: p.destaque,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        color: p.cartao,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.borda),
        ),
      ),

      dividerTheme: DividerThemeData(color: p.borda),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.cartao,
        indicatorColor: p.destaque.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((estados) {
          return IconThemeData(
            color: estados.contains(WidgetState.selected)
                ? p.destaque
                : p.textoSuave,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((estados) {
          final ativo = estados.contains(WidgetState.selected);

          return TextStyle(
            fontSize: 12,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
            color: ativo ? p.destaque : p.textoSuave,
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
