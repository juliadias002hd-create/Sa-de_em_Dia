import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Som de despertador tocado pela tela do alerta ("Hora do ...!").
///
/// Funciona no navegador, no Android e no iOS: enquanto a tela estiver
/// aberta, o "bip-bip-bip-bip" se repete até o usuário tomar, adiar ou
/// fechar (ou por [_duracaoMaxima], no máximo).
///
///  - Android: usa o volume de ALARME do celular.
///  - iOS: usa a categoria "playback", que toca mesmo com o botão lateral
///    no silencioso.
///  - Navegador: o áudio só toca depois que a pessoa interagiu com a página
///    (o login já conta).
class SomAlarme {
  SomAlarme._();

  static final SomAlarme instance = SomAlarme._();

  static const String _arquivo = 'sons/alarme.wav'; // dentro de assets/
  static const Duration _duracaoMaxima = Duration(minutes: 3);

  final AudioPlayer _player = AudioPlayer();

  Timer? _limite;

  /// Cada chamada de [tocar]/[parar] muda este número. Assim uma chamada de
  /// [tocar] que ainda estava carregando percebe que já foi cancelada.
  int _geracao = 0;

  /// Começa a tocar em loop. Devolve true se o som realmente começou.
  Future<bool> tocar() async {
    final minha = ++_geracao;

    _limite?.cancel();

    try {
      if (!kIsWeb) {
        await _player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.alarm,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gain,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
          ),
        );
      }

      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);

      // Se a tela foi fechada durante o carregamento, não toca.
      if (minha != _geracao) {
        return false;
      }

      await _player.play(AssetSource(_arquivo));

      if (minha != _geracao) {
        await _player.stop();
        return false;
      }

      _limite = Timer(_duracaoMaxima, parar);

      return true;
    } catch (_) {
      // Sem permissão do navegador, arquivo ausente ou aparelho sem áudio:
      // o alerta continua aparecendo, só que sem som.
      return false;
    }
  }

  /// Para o som.
  void parar() {
    _geracao++;

    _limite?.cancel();
    _limite = null;

    unawaited(_player.stop().catchError((Object _) {}));
  }
}
