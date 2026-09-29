import 'dart:async';

import 'package:flutter/widgets.dart';

import 'biometria_service.dart';
import 'token_storage.dart';

/// Bloqueio do app por digital ou rosto.
///
/// Quando ligado, o app pede a biometria ao ser aberto e ao voltar do
/// segundo plano depois de um tempo. É uma camada EXTRA sobre o login: a
/// senha continua sendo a forma de entrar em uma conta.
class BloqueioController extends ChangeNotifier with WidgetsBindingObserver {
  BloqueioController._();

  static final BloqueioController instance = BloqueioController._();

  static const String _marca = 'biometria_ativa';

  /// Tempo fora do app a partir do qual ele volta bloqueado.
  static const Duration tempoPadrao = Duration(seconds: 30);

  @visibleForTesting
  Duration tempoParaBloquear = tempoPadrao;

  final BiometriaService _servico = BiometriaService.instance;

  bool _ativo = false;
  bool _bloqueado = false;
  bool _observando = false;
  DateTime? _saiuEm;

  /// O usuário ligou o bloqueio por biometria.
  bool get ativo => _ativo;

  /// O app está coberto pela tela de bloqueio agora.
  bool get bloqueado => _bloqueado;

  /// Lê se a biometria estava ligada. Chamado ao iniciar o app.
  Future<void> carregar() async {
    _ativo = _servico.plataformaSuportada && await TokenStorage.lerMarca(_marca);

    if (!_observando) {
      WidgetsBinding.instance.addObserver(this);
      _observando = true;
    }
  }

  /// Liga o bloqueio (o chamador já confirmou a biometria).
  Future<void> ligar() async {
    _ativo = true;
    await TokenStorage.salvarMarca(_marca);
    notifyListeners();
  }

  /// Desliga e tira o bloqueio da frente (ex.: ao sair da conta).
  Future<void> desligar() async {
    _ativo = false;
    _bloqueado = false;
    _saiuEm = null;
    await TokenStorage.apagarMarca(_marca);
    notifyListeners();
  }

  /// Cobre o app agora, se o bloqueio estiver ligado (abertura do app).
  void bloquearSeAtivo() {
    if (_ativo && !_bloqueado) {
      _bloqueado = true;
      notifyListeners();
    }
  }

  /// Chamado quando a pessoa passou pela biometria.
  void desbloquear() {
    if (_bloqueado) {
      _bloqueado = false;
      notifyListeners();
    }
  }

  /// Sem sessão não há o que proteger (login novo, sessão vencida).
  void liberar() => desbloquear();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ativo) {
      return;
    }

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // "inactive" é ignorado de propósito: a própria janela de digital
        // do sistema deixa o app assim por um instante.
        _saiuEm ??= DateTime.now();
      case AppLifecycleState.resumed:
        final saiu = _saiuEm;
        _saiuEm = null;

        if (saiu != null && DateTime.now().difference(saiu) >= tempoParaBloquear) {
          bloquearSeAtivo();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
