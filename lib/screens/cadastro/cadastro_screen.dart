import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formulario = GlobalKey<FormState>();
  final _auth = AuthService();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _nascimentoController = TextEditingController();

  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    _telefoneController.dispose();
    _nascimentoController.dispose();
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

  Future<void> _escolherData() async {
    final hoje = DateTime.now();

    final escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime(hoje.year - 30),
      firstDate: DateTime(1900),
      lastDate: hoje,
      helpText: 'Data de nascimento',
    );

    if (escolhida != null) {
      _nascimentoController.text = Datas.paraBr(escolhida);
    }
  }

  Future<void> _cadastrar() async {
    if (!_formulario.currentState!.validate()) {
      return;
    }

    setState(() => _carregando = true);

    try {
      final nascimento = _nascimentoController.text.trim();
      final telefone = _telefoneController.text.trim();

      await _auth.cadastrar(
        nome: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        senha: _senhaController.text,
        confirmarSenha: _confirmarController.text,
        telefone: telefone.isEmpty ? null : telefone,
        dataNascimentoIso: nascimento.isEmpty ? null : Datas.brParaIso(nascimento),
      );

      if (mounted) {
        // Devolve o e-mail para a tela de login preencher.
        Navigator.of(context).pop(_emailController.text.trim());
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
      appBar: AppBar(title: const Text('Criar conta')),
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
                    AppTextField(
                      controller: _nomeController,
                      rotulo: 'Nome completo',
                      icone: Icons.person_outline_rounded,
                      capitalizacao: TextCapitalization.words,
                      acaoTeclado: TextInputAction.next,
                      validador: Validators.nome,
                      limiteCaracteres: 150,
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emailController,
                      rotulo: 'E-mail',
                      icone: Icons.mail_outline_rounded,
                      teclado: TextInputType.emailAddress,
                      acaoTeclado: TextInputAction.next,
                      validador: Validators.email,
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _senhaController,
                      rotulo: 'Senha',
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
                      rotulo: 'Confirmar senha',
                      icone: Icons.lock_reset_rounded,
                      senha: true,
                      acaoTeclado: TextInputAction.next,
                      validador: Validators.confirmarSenha(
                        () => _senhaController.text,
                      ),
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _telefoneController,
                      rotulo: 'Telefone (opcional)',
                      dica: '(11) 98888-7777',
                      icone: Icons.phone_outlined,
                      teclado: TextInputType.phone,
                      acaoTeclado: TextInputAction.next,
                      formatadores: [TelefoneInputFormatter()],
                      validador: Validators.telefoneOpcional,
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _nascimentoController,
                      rotulo: 'Data de nascimento (opcional)',
                      dica: 'dd/mm/aaaa',
                      icone: Icons.cake_outlined,
                      teclado: TextInputType.number,
                      acaoTeclado: TextInputAction.done,
                      formatadores: [DataInputFormatter()],
                      validador: Validators.data(opcional: true, naoFutura: true),
                      aoEnviar: (_) => _cadastrar(),
                      desativado: _carregando,
                      sufixo: IconButton(
                        tooltip: 'Escolher no calendário',
                        icon: const Icon(Icons.calendar_month_rounded),
                        onPressed: _carregando ? null : _escolherData,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      texto: 'CRIAR CONTA',
                      carregando: _carregando,
                      onPressed: _cadastrar,
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
