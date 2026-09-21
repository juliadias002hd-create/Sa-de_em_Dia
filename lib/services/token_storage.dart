import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o token de login no armazenamento seguro do aparelho
/// (Keystore no Android, Keychain no iOS).
class TokenStorage {
  TokenStorage._();

  static const String _chave = 'token_jwt';

  static const FlutterSecureStorage _armazenamento = FlutterSecureStorage();

  static Future<void> salvar(String token) async {
    try {
      await _armazenamento.write(key: _chave, value: token);
    } catch (_) {
      // Se o aparelho não deixar guardar, o app funciona nesta sessão,
      // e o usuário só precisará entrar de novo na próxima vez.
    }
  }

  static Future<String?> ler() async {
    try {
      return await _armazenamento.read(key: _chave);
    } catch (_) {
      return null;
    }
  }

  static Future<void> apagar() async {
    try {
      await _armazenamento.delete(key: _chave);
    } catch (_) {}
  }
}
