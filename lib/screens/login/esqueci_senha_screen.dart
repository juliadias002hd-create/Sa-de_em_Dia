import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'redefinir_senha_screen.dart';

/// Passo 1 do "Esqueci minha senha": informar o e-mail para receber o
/// código de 6 dígitos.
///
/// Ao terminar com sucesso (senha trocada), fecha devolvendo o e-mail, para
/// a tela de login já deixá-lo preenchido.
class EsqueciSenhaScreen extends StatefulWidget {
  final String emailInicial;

  const EsqueciSenhaScreen({super.key, this.emailInicial = ''});

  @override
  State<EsqueciSenhaScreen> createState() => _EsqueciSenhaScreenState();
}

class _EsqueciSenhaScreenState extends State<EsqueciSenhaScreen> {
  final _formulario = GlobalKey<FormState>();
  final _auth = AuthService();
  final _emailController = TextEditingController();

  bool _carregando = false;

  @override
  void initState() {
    super.initState();

    _emailController.text = widget.emailInicial;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _enviarCodigo() async {
    if (!_formulario.currentState!.validate()) {
      return;
    }

    setState(() => _carregando = true);

    final email = _emailController.text.trim();

    try {
      await _auth.solicitarRedefinicaoDeSenha(email);

      if (!mounted) {
        return;
      }

      // Vai para o passo 2. Se a senha for trocada lá, o e-mail volta aqui.
      final resultado = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => RedefinirSenhaScreen(email: email),
        ),
      );

      if (resultado != null && mounted) {
        Navigator.of(context).pop(resultado);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Esqueci minha senha')),
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
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.roxo.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          size: 48,
                          color: context.destaque,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Vamos redefinir sua senha',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.texto,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Informe o e-mail da sua conta. Vamos enviar um código de 6 números para você criar uma senha nova.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.4, color: context.textoSuave),
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _emailController,
                      rotulo: 'E-mail',
                      icone: Icons.mail_outline_rounded,
                      teclado: TextInputType.emailAddress,
                      acaoTeclado: TextInputAction.done,
                      validador: Validators.email,
                      aoEnviar: (_) => _enviarCodigo(),
                      autofill: const [AutofillHints.email],
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      texto: 'ENVIAR CÓDIGO',
                      carregando: _carregando,
                      onPressed: _enviarCodigo,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _carregando
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Voltar para o login'),
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
