import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências de aparência do usuário: tema (claro/escuro/automático) e
/// tamanho da letra. Ficam guardadas no aparelho e valem para o app inteiro.
class ConfiguracoesController extends ChangeNotifier {
  ConfiguracoesController._();

  static final ConfiguracoesController instance = ConfiguracoesController._();

  static const String _chaveTema = 'config_tema';
  static const String _chaveFonte = 'config_fonte';

  /// Tamanhos de letra oferecidos (1.0 = tamanho normal).
  static const List<double> niveisDeFonte = [0.9, 1.0, 1.15, 1.3, 1.5];

  static const List<String> nomesDosNiveis = [
    'Pequena',
    'Normal',
    'Grande',
    'Muito grande',
    'Enorme',
  ];

  static const int nivelPadrao = 1;

  ThemeMode _modo = ThemeMode.system;
  int _nivel = nivelPadrao;

  ThemeMode get modoDoTema => _modo;

  /// Posição do tamanho escolhido em [niveisDeFonte].
  int get nivelDeFonte => _nivel;

  double get escalaDaFonte => niveisDeFonte[_nivel];

  String get nomeDoNivel => nomesDosNiveis[_nivel];

  bool get estaNoPadrao => _modo == ThemeMode.system && _nivel == nivelPadrao;

  /// Lê o que estava salvo. Chamado uma vez, antes de o app aparecer.
  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _modo = _modoDoTexto(prefs.getString(_chaveTema));

      final nivel = prefs.getInt(_chaveFonte);

      if (nivel != null && nivel >= 0 && nivel < niveisDeFonte.length) {
        _nivel = nivel;
      }
    } catch (_) {
      // Sem acesso ao armazenamento: usa os padrões.
    }
  }

  Future<void> definirModoDoTema(ThemeMode modo) async {
    if (modo == _modo) {
      return;
    }

    _modo = modo;
    notifyListeners();

    await _salvar((p) => p.setString(_chaveTema, _textoDoModo(modo)));
  }

  Future<void> definirNivelDeFonte(int nivel) async {
    final valido = nivel.clamp(0, niveisDeFonte.length - 1);

    if (valido == _nivel) {
      return;
    }

    _nivel = valido;
    notifyListeners();

    await _salvar((p) => p.setInt(_chaveFonte, valido));
  }

  Future<void> restaurarPadrao() async {
    _modo = ThemeMode.system;
    _nivel = nivelPadrao;
    notifyListeners();

    await _salvar((p) async {
      await p.remove(_chaveTema);
      await p.remove(_chaveFonte);
    });
  }

  Future<void> _salvar(Future<void> Function(SharedPreferences) escrever) async {
    try {
      await escrever(await SharedPreferences.getInstance());
    } catch (_) {
      // Não conseguiu guardar: a escolha vale só até fechar o app.
    }
  }

  static ThemeMode _modoDoTexto(String? texto) {
    return switch (texto) {
      'claro' => ThemeMode.light,
      'escuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _textoDoModo(ThemeMode modo) {
    return switch (modo) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'escuro',
      ThemeMode.system => 'sistema',
    };
  }
}
