import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Situação da biometria no aparelho.
enum DisponibilidadeBiometria {
  /// Digital ou rosto cadastrados: pode usar.
  disponivel,

  /// O aparelho tem o recurso, mas a pessoa ainda não cadastrou digital/rosto.
  semCadastro,

  /// Web, aparelho sem leitor, ou sistema sem suporte.
  naoSuportado,
}

/// Resultado de um pedido de digital/rosto.
enum ResultadoBiometria {
  aprovada,

  /// Não reconheceu, ou a pessoa fechou a janela.
  negada,

  /// Muitas tentativas erradas: o sistema travou por um tempo.
  bloqueadaTemporariamente,

  /// O aparelho não tem (mais) digital/rosto cadastrados.
  indisponivel,
}

/// Conversa com o leitor de digital / reconhecimento facial do aparelho
/// (BiometricPrompt no Android, Touch ID / Face ID no iOS).
class BiometriaService {
  BiometriaService([this._auth]);

  static final BiometriaService instance = BiometriaService();

  // Criado só quando preciso: na web o plugin não existe.
  LocalAuthentication? _auth;

  LocalAuthentication get _local => _auth ??= LocalAuthentication();

  /// Só Android e iOS têm suporte no app.
  bool get plataformaSuportada {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<DisponibilidadeBiometria> verificar() async {
    if (!plataformaSuportada) {
      return DisponibilidadeBiometria.naoSuportado;
    }

    try {
      if (!await _local.isDeviceSupported()) {
        return DisponibilidadeBiometria.naoSuportado;
      }

      final cadastradas = await _local.getAvailableBiometrics();

      if (cadastradas.isEmpty) {
        return await _local.canCheckBiometrics
            ? DisponibilidadeBiometria.semCadastro
            : DisponibilidadeBiometria.naoSuportado;
      }

      return DisponibilidadeBiometria.disponivel;
    } catch (_) {
      return DisponibilidadeBiometria.naoSuportado;
    }
  }

  /// Tipos cadastrados (para escolher o ícone e o texto certos).
  Future<({bool digital, bool rosto})> tipos() async {
    try {
      final lista = await _local.getAvailableBiometrics();

      return (
        digital: lista.contains(BiometricType.fingerprint),
        rosto: lista.contains(BiometricType.face),
      );
    } catch (_) {
      return (digital: false, rosto: false);
    }
  }

  /// Mostra a janela do sistema pedindo digital ou rosto.
  ///
  /// Se o aparelho oferecer, a pessoa também pode usar o PIN/padrão do
  /// celular (útil quando a digital falha várias vezes).
  Future<ResultadoBiometria> autenticar(String motivo) async {
    try {
      final ok = await _local.authenticate(
        localizedReason: motivo,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Confirme que é você',
            cancelButton: 'Cancelar',
          ),
          IOSAuthMessages(cancelButton: 'Cancelar'),
        ],
      );

      return ok ? ResultadoBiometria.aprovada : ResultadoBiometria.negada;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          ResultadoBiometria.bloqueadaTemporariamente,
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          ResultadoBiometria.indisponivel,
        _ => ResultadoBiometria.negada,
      };
    } catch (_) {
      return ResultadoBiometria.negada;
    }
  }
}
