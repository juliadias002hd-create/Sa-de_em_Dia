import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../cadastro/cadastro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formulario = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _carregando = false;

  @override
  void initState() {
    super.initState();

    // Mostra o aviso de "sessão expirada", se houver.
    final aviso = SessionController.instance.avisoLogin;

    if (aviso != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarMensagem(aviso);
        SessionController.instance.avisoLogin = null;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
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

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) {
      return;
    }

    setState(() => _carregando = true);

    try {
      await SessionController.instance.entrar(
        _emailController.text.trim(),
        _senhaController.text,
      );

      // Ao logar, o app troca de tela sozinho (veja app.dart).
    } on ApiException catch (e) {
      _mostrarMensagem(e.mensagem);
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _criarConta() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CadastroScreen()),
    );

    // Voltou do cadastro com sucesso: já deixa o e-mail preenchido.
    if (email != null && mounted) {
      _emailController.text = email;
      _senhaController.clear();
      _mostrarMensagem('Cadastro concluído! Entre com sua senha.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradiente),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, restricoes) {
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: restricoes.maxHeight - 48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _Logo(),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formulario,
                              child: AutofillGroup(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.texto,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Acesse suas receitas e lembretes.',
                                      style: TextStyle(
                                        color: AppColors.textoSuave,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    AppTextField(
                                      controller: _emailController,
                                      rotulo: 'E-mail',
                                      icone: Icons.mail_outline_rounded,
                                      teclado: TextInputType.emailAddress,
                                      acaoTeclado: TextInputAction.next,
                                      validador: Validators.email,
                                      autofill: const [AutofillHints.email],
                                      desativado: _carregando,
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _senhaController,
                                      rotulo: 'Senha',
                                      icone: Icons.lock_outline_rounded,
                                      senha: true,
                                      acaoTeclado: TextInputAction.done,
                                      validador: (v) => Validators.obrigatorio(
                                        v,
                                        'Informe a senha.',
                                      ),
                                      aoEnviar: (_) => _entrar(),
                                      autofill: const [AutofillHints.password],
                                      desativado: _carregando,
                                    ),
                                    const SizedBox(height: 24),
                                    AppButton(
                                      texto: 'ENTRAR',
                                      carregando: _carregando,
                                      onPressed: _entrar,
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _carregando ? null : _criarConta,
                                      child: const Text(
                                        'Ainda não tem conta? Criar conta',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}


class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: Colors.white,
          child: Icon(
            Icons.medication_rounded,
            size: 50,
            color: AppColors.roxo,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Saúde em Dia',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Seus remédios na hora certa',
          style: TextStyle(fontSize: 15, color: Colors.white70),
        ),
      ],
    );
  }
}
