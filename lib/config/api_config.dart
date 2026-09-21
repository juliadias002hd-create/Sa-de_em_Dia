import 'package:flutter/foundation.dart';

/// Configuração central da API.
///
/// É o ÚNICO lugar do app onde o endereço do servidor aparece.
///
/// Endereços usados por padrão:
///  - Navegador / Windows / iOS Simulator: http://localhost:3000
///  - Android Emulator:                    http://10.0.2.2:3000
///    (no emulador, "localhost" é o próprio celular virtual;
///     10.0.2.2 é o atalho para o computador que roda o emulador)
///
/// Celular físico: o computador e o celular precisam estar na mesma rede
/// Wi-Fi. Descubra o IP do computador (comando `ipconfig`, campo
/// "Endereço IPv4", ex.: 192.168.0.15) e rode o app assim:
///
///   flutter run --dart-define=API_URL=http://192.168.0.15:3000
class ApiConfig {
  ApiConfig._();

  static const String _urlManual = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_urlManual.isNotEmpty) {
      return _urlManual;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    return 'http://localhost:3000';
  }

  /// Tempo máximo de espera por uma resposta comum.
  static const Duration tempoLimite = Duration(seconds: 15);

  /// Tempo máximo para envio de arquivos (fotos e PDFs).
  static const Duration tempoLimiteUpload = Duration(seconds: 60);
}
