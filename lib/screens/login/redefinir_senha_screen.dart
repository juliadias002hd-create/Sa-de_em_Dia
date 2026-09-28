import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Passo 2 do "Esqueci minha senha": código recebido por e-mail + senha nova.
///
/// Fecha devolvendo o e-mail quando a senha é trocada com sucesso.
class RedefinirSenhaScreen extends StatefulWidget {
  final String email;

  const RedefinirSenhaScreen({super.key, required this.email});

  @override
  State<RedefinirSenhaScreen> createState() => _RedefinirSenhaScreenState();
}

class _RedefinirSenhaScreenState extends State<RedefinirSenhaScreen> {
  /// Espera entre um "Reenviar código" e outro.
  static const int _esperaSegundos = 30;

  final _formulario = GlobalKey<FormState>();
  final _auth = AuthService();

  final _codigoController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _carregando = false;
  bool _reenviando = false;

  int _restante = _esperaSegundos;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();

    _iniciarEspera();
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _codigoController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  void _iniciarEspera() {
    _relogio?.cancel();

    setState(() => _restante = _esperaSegundos);

    _relogio = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      setState(() => _restante--);

      if (_restante <= 0) {
        t.cancel();
      }
    });
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _reenviar() async {
    setState(() => _reenviando = true);

    try {
      await _auth.solicitarRedefinicaoDeSenha(widget.email);

      _iniciarEspera();

      _mostrarMensagem('Enviamos um novo código. O anterior deixou de valer.');
    } on ApiException catch (e) {
      _mostrarMensagem(e.mensagem);
    } finally {
      if (mounted) {
        setState(() => _reenviando = false);
      }
    }
  }

  Future<void> _redefinir() async {
    if (!_formulario.currentState!.validate()) {
      return;
    }

    setState(() => _carregando = true);

    try {
      await _auth.redefinirSenha(
        email: widget.email,
        codigo: _codigoController.text.trim(),
        novaSenha: _senhaController.text,
      );

      if (mounted) {
        Navigator.of(context).pop(widget.email);
      }
    } on ApiException catch (e) {
      _mostrarMensagem(e.mensagem);
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final podeReenviar = _restante <= 0 && !_reenviando && !_carregando;

    return Scaffold(
      appBar: AppBar(title: const Text('Nova senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.turquesa.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.mark_email_read_outlined,
                            color: AppColors.turquesa,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Se ${widget.email} estiver cadastrado, enviamos um código de 6 números. Ele vale por 15 minutos. Se não chegar, olhe também a caixa de spam.',
                              style: TextStyle(
                                height: 1.4,
                                color: context.texto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      controller: _codigoController,
                      rotulo: 'Código de 6 números',
                      dica: '000000',
                      icone: Icons.pin_outlined,
                      teclado: TextInputType.number,
                      acaoTeclado: TextInputAction.next,
                      formatadores: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validador: Validators.codigo,
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _senhaController,
                      rotulo: 'Nova senha',
                      dica: 'Mínimo de 8 caracteres',
                      icone: Icons.lock_outline_rounded,
                      senha: true,
                      acaoTeclado: TextInputAction.next,
                      validador: Validators.senha,
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirmarController,
                      rotulo: 'Confirmar nova senha',
                      icone: Icons.lock_reset_rounded,
                      senha: true,
                      acaoTeclado: TextInputAction.done,
                      validador: Validators.confirmarSenha(
                        () => _senhaController.text,
                      ),
                      aoEnviar: (_) => _redefinir(),
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      texto: 'ALTERAR SENHA',
                      carregando: _carregando,
                      onPressed: _redefinir,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: podeReenviar ? _reenviar : null,
                      child: Text(
                        _reenviando
                            ? 'Enviando...'
                            : _restante > 0
                                ? 'Reenviar código em ${_restante}s'
                                : 'Reenviar código',
                      ),
                    ),
                    TextButton(
                      onPressed: _carregando
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Usar outro e-mail'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
