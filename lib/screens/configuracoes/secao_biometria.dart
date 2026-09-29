import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/biometria_service.dart';
import '../../services/bloqueio_controller.dart';
import '../../theme/app_theme.dart';

/// Cartão "Segurança" das Configurações: liga e desliga o bloqueio do app por
/// digital ou reconhecimento facial.
class SecaoBiometria extends StatefulWidget {
  const SecaoBiometria({super.key});

  @override
  State<SecaoBiometria> createState() => _SecaoBiometriaState();
}

class _SecaoBiometriaState extends State<SecaoBiometria> {
  final _servico = BiometriaService.instance;
  final _bloqueio = BloqueioController.instance;

  DisponibilidadeBiometria? _situacao;
  ({bool digital, bool rosto}) _tipos = (digital: false, rosto: false);
  bool _trabalhando = false;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    final situacao = await _servico.verificar();
    final tipos = situacao == DisponibilidadeBiometria.disponivel
        ? await _servico.tipos()
        : _tipos;

    if (mounted) {
      setState(() {
        _situacao = situacao;
        _tipos = tipos;
      });
    }
  }

  String get _nome {
    if (_tipos.digital && _tipos.rosto) {
      return 'digital ou rosto';
    }

    if (_tipos.rosto) {
      return 'rosto';
    }

    return 'digital';
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _alternar(bool ligar) async {
    if (_trabalhando) {
      return;
    }

    setState(() => _trabalhando = true);

    // Confirma que é a pessoa mesma, tanto para ligar quanto para desligar.
    final resultado = await _servico.autenticar(
      ligar
          ? 'Confirme para ativar o bloqueio do app'
          : 'Confirme para desativar o bloqueio do app',
    );

    if (!mounted) {
      return;
    }

    switch (resultado) {
      case ResultadoBiometria.aprovada:
        if (ligar) {
          await _bloqueio.ligar();
          _avisar('Bloqueio ativado. O app vai pedir $_nome ao abrir.');
        } else {
          await _bloqueio.desligar();
          _avisar('Bloqueio desativado.');
        }
      case ResultadoBiometria.negada:
        _avisar('Não foi possível confirmar. Nada foi alterado.');
      case ResultadoBiometria.bloqueadaTemporariamente:
        _avisar('Muitas tentativas. Aguarde um pouco e tente de novo.');
      case ResultadoBiometria.indisponivel:
        _avisar('Cadastre uma digital ou rosto nas configurações do celular.');
        _verificar();
    }

    if (mounted) {
      setState(() => _trabalhando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ListenableBuilder(
          listenable: _bloqueio,
          builder: (context, _) => _conteudo(context),
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    final situacao = _situacao;
    final ligado = _bloqueio.ativo;

    final podeUsar = situacao == DisponibilidadeBiometria.disponivel;

    // Mesmo sem biometria disponível, deixa DESLIGAR se estava ligado
    // (ex.: a pessoa apagou as digitais do celular depois).
    final podeMexer = !_trabalhando && situacao != null && (podeUsar || ligado);

    final String explicacao;

    if (kIsWeb) {
      explicacao = 'Disponível apenas no aplicativo do celular.';
    } else if (situacao == null) {
      explicacao = 'Verificando o seu aparelho...';
    } else if (situacao == DisponibilidadeBiometria.naoSuportado) {
      explicacao = 'Este aparelho não tem leitor de digital nem '
          'reconhecimento facial disponível.';
    } else if (situacao == DisponibilidadeBiometria.semCadastro) {
      explicacao = 'Cadastre uma digital ou rosto nas configurações do '
          'celular para usar este recurso.';
    } else {
      explicacao = 'Pede $_nome ao abrir o app e ao voltar depois de alguns '
          'instantes. Os alarmes dos remédios continuam tocando normalmente.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              _tipos.rosto && !_tipos.digital
                  ? Icons.face_unlock_rounded
                  : Icons.fingerprint_rounded,
              color: context.destaque,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Segurança',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.texto,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Bloquear o app com digital ou rosto',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: ligado,
            onChanged: podeMexer ? _alternar : null,
            title: Text(
              'Bloquear com digital ou rosto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.texto,
              ),
            ),
            subtitle: Text(
              explicacao,
              style: TextStyle(fontSize: 13, color: context.textoSuave),
            ),
          ),
        ),
      ],
    );
  }
}
