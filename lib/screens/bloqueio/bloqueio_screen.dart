import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometria_service.dart';
import '../../services/bloqueio_controller.dart';
import '../../services/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Tela que cobre o app enquanto ele está bloqueado. Pede digital ou rosto;
/// se não der certo, a pessoa pode confirmar com a senha da conta.
class BloqueioScreen extends StatefulWidget {
  const BloqueioScreen({super.key});

  @override
  State<BloqueioScreen> createState() => _BloqueioScreenState();
}

class _BloqueioScreenState extends State<BloqueioScreen> {
  final _servico = BiometriaService.instance;
  final _auth = AuthService();
  final _senha = TextEditingController();
  final _formulario = GlobalKey<FormState>();

  bool _verificando = false;
  bool _usandoSenha = false;
  bool _conferindoSenha = false;
  String? _aviso;
  String? _erroSenha;

  ({bool digital, bool rosto}) _tipos = (digital: true, rosto: false);

  @override
  void initState() {
    super.initState();

    // Já abre a janela do sistema, sem a pessoa precisar tocar em nada.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tipos = await _servico.tipos();

      if (mounted && (tipos.digital || tipos.rosto)) {
        setState(() => _tipos = tipos);
      }

      await _pedirBiometria();
    });
  }

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  String get _nomeDoRecurso {
    if (_tipos.digital && _tipos.rosto) {
      return 'digital ou rosto';
    }

    return _tipos.rosto ? 'rosto' : 'digital';
  }

  IconData get _icone => _tipos.rosto && !_tipos.digital
      ? Icons.face_unlock_rounded
      : Icons.fingerprint_rounded;

  Future<void> _pedirBiometria() async {
    if (_verificando || !mounted) {
      return;
    }

    setState(() {
      _verificando = true;
      _aviso = null;
    });

    final resultado = await _servico.autenticar('Desbloqueie o Saúde em Dia');

    if (!mounted) {
      return;
    }

    switch (resultado) {
      case ResultadoBiometria.aprovada:
        BloqueioController.instance.desbloquear();
        return;
      case ResultadoBiometria.negada:
        _aviso = null;
      case ResultadoBiometria.bloqueadaTemporariamente:
        _aviso = 'Muitas tentativas. Aguarde um pouco ou use a senha.';
      case ResultadoBiometria.indisponivel:
        _aviso = 'Nenhuma digital ou rosto cadastrado neste celular. '
            'Use a senha para entrar.';
    }

    setState(() => _verificando = false);
  }

  Future<void> _confirmarSenha() async {
    if (_conferindoSenha || !(_formulario.currentState?.validate() ?? false)) {
      return;
    }

    final usuario = SessionController.instance.usuario;

    if (usuario == null) {
      BloqueioController.instance.liberar();
      return;
    }

    setState(() {
      _conferindoSenha = true;
      _erroSenha = null;
    });

    try {
      await _auth.confirmarSenha(email: usuario.email, senha: _senha.text);

      if (mounted) {
        BloqueioController.instance.desbloquear();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _conferindoSenha = false;
          _erroSenha = e.mensagem;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = SessionController.instance.usuario;

    return Scaffold(
      backgroundColor: context.fundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.destaque.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        _usandoSenha ? Icons.lock_outline_rounded : _icone,
                        size: 64,
                        color: context.destaque,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Saúde em Dia bloqueado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.texto,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    usuario == null
                        ? 'Confirme que é você para continuar.'
                        : 'Olá, ${usuario.primeiroNome}. Confirme que é você para continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textoSuave),
                  ),
                  const SizedBox(height: 28),
                  if (_aviso != null) ...[
                    Text(
                      _aviso!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.alerta),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_usandoSenha) ..._camposDeSenha() else ..._botoesDeBiometria(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _botoesDeBiometria() {
    return [
      AppButton(
        texto: 'USAR ${_nomeDoRecurso.toUpperCase()}',
        icone: _icone,
        carregando: _verificando,
        onPressed: _pedirBiometria,
      ),
      const SizedBox(height: 12),
      AppButton(
        texto: 'USAR A SENHA DA CONTA',
        icone: Icons.password_rounded,
        secundario: true,
        onPressed: () => setState(() {
          _usandoSenha = true;
          _aviso = null;
        }),
      ),
    ];
  }

  List<Widget> _camposDeSenha() {
    return [
      Form(
        key: _formulario,
        child: AppTextField(
          controller: _senha,
          rotulo: 'Senha',
          icone: Icons.lock_outline_rounded,
          senha: true,
          acaoTeclado: TextInputAction.done,
          validador: (v) => Validators.obrigatorio(v, 'Digite sua senha.'),
          aoEnviar: (_) => _confirmarSenha(),
        ),
      ),
      if (_erroSenha != null) ...[
        const SizedBox(height: 10),
        Text(
          _erroSenha!,
          style: const TextStyle(color: AppColors.perigo),
        ),
      ],
      const SizedBox(height: 16),
      AppButton(
        texto: 'DESBLOQUEAR',
        icone: Icons.lock_open_rounded,
        carregando: _conferindoSenha,
        onPressed: _confirmarSenha,
      ),
      const SizedBox(height: 12),
      AppButton(
        texto: 'VOLTAR PARA ${_nomeDoRecurso.toUpperCase()}',
        icone: _icone,
        secundario: true,
        onPressed: () {
          setState(() {
            _usandoSenha = false;
            _erroSenha = null;
            _senha.clear();
          });
          _pedirBiometria();
        },
      ),
    ];
  }
}
