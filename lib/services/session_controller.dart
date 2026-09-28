import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'lembretes_controller.dart';
import 'token_storage.dart';

enum EstadoSessao { carregando, semConexao, deslogado, logado }


/// Guarda quem está logado e decide qual parte do app mostrar
/// (carregando / login / telas internas).
class SessionController extends ChangeNotifier {
  SessionController._();

  static final SessionController instance = SessionController._();

  final AuthService _auth = AuthService();

  EstadoSessao _estado = EstadoSessao.carregando;
  Usuario? _usuario;

  /// Mensagem opcional para mostrar na tela de login
  /// (ex.: "Sessão expirada").
  String? avisoLogin;

  EstadoSessao get estado => _estado;

  Usuario? get usuario => _usuario;

  /// Chamado ao abrir o app: se há token guardado, tenta reaproveitá-lo.
  Future<void> iniciar() async {
    ApiService.instance.aoSessaoExpirar = () {
      _usuario = null;
      avisoLogin = 'Sua sessão expirou. Entre novamente.';

      // Desliga o relógio de alertas, mas mantém os lembretes já agendados.
      LembretesController.instance.parar(cancelarNotificacoes: false);

      _mudar(EstadoSessao.deslogado);
    };

    _mudar(EstadoSessao.carregando);

    final token = await TokenStorage.ler();

    if (token == null) {
      _mudar(EstadoSessao.deslogado);
      return;
    }

    ApiService.instance.definirToken(token);

    try {
      _usuario = await _auth.meusDados();
      _mudar(EstadoSessao.logado);
    } on ApiException catch (e) {
      if (e.statusCode == null) {
        // Sem conexão: mantém o token e deixa o usuário tentar de novo.
        _mudar(EstadoSessao.semConexao);
        return;
      }

      // Token inválido ou vencido.
      await _auth.sair();
      _mudar(EstadoSessao.deslogado);
    }
  }

  Future<void> entrar(String email, String senha) async {
    _usuario = await _auth.entrar(email: email, senha: senha);
    avisoLogin = null;
    _mudar(EstadoSessao.logado);
  }

  Future<void> sair() async {
    await LembretesController.instance.parar();
    await _auth.sair();
    _usuario = null;
    avisoLogin = null;
    _mudar(EstadoSessao.deslogado);
  }

  void _mudar(EstadoSessao novo) {
    _estado = novo;
    notifyListeners();
  }
}
