import '../models/usuario.dart';
import 'api_service.dart';
import 'token_storage.dart';

/// Cadastro, login e dados do paciente logado.
class AuthService {
  final ApiService _api = ApiService.instance;

  /// POST /api/auth/register
  Future<Usuario> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String confirmarSenha,
    String? telefone,
    String? dataNascimentoIso,
  }) async {
    final resposta = await _api.post('/api/auth/register', {
      'nome': nome,
      'email': email,
      'senha': senha,
      'confirmar_senha': confirmarSenha,
      'telefone': telefone,
      'data_nascimento': dataNascimentoIso,
    });

    return Usuario.fromJson(resposta['data']['usuario']);
  }

  /// POST /api/auth/login  (guarda o token para as próximas requisições)
  Future<Usuario> entrar({
    required String email,
    required String senha,
  }) async {
    final resposta = await _api.post('/api/auth/login', {
      'email': email,
      'senha': senha,
    });

    final token = resposta['data']['token'] as String;

    _api.definirToken(token);

    await TokenStorage.salvar(token);

    return Usuario.fromJson(resposta['data']['usuario']);
  }

  /// Confere a senha de quem já está logado (usado no desbloqueio quando a
  /// biometria não funciona). Senha errada NÃO derruba a sessão.
  Future<void> confirmarSenha({
    required String email,
    required String senha,
  }) async {
    final resposta = await _api.post(
      '/api/auth/login',
      {'email': email, 'senha': senha},
      expirarSessao: false,
    );

    final token = resposta['data']['token'] as String;

    _api.definirToken(token);

    await TokenStorage.salvar(token);
  }

  /// POST /api/auth/forgot-password
  ///
  /// Pede o código de 6 dígitos por e-mail. A API responde igual exista ou
  /// não o e-mail (para não revelar quem tem conta); por isso, o app também
  /// sempre segue para a tela do código.
  Future<void> solicitarRedefinicaoDeSenha(String email) async {
    await _api.post('/api/auth/forgot-password', {'email': email});
  }

  /// POST /api/auth/reset-password
  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    await _api.post('/api/auth/reset-password', {
      'email': email,
      'codigo': codigo,
      'nova_senha': novaSenha,
    });
  }

  /// GET /api/auth/me
  Future<Usuario> meusDados() async {
    final resposta = await _api.get('/api/auth/me');

    return Usuario.fromJson(resposta['data']['usuario']);
  }

  Future<void> sair() async {
    _api.definirToken(null);

    await TokenStorage.apagar();
  }
}
