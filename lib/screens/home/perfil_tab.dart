import 'package:flutter/material.dart';

import '../../services/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../configuracoes/configuracoes_screen.dart';

/// Dados do paciente, acesso às configurações e botão de sair.
class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  Future<void> _sair(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Você precisará entrar novamente para ver suas receitas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('SAIR'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      await SessionController.instance.sair();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = SessionController.instance.usuario;

    if (usuario == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.roxo,
                      child: Text(
                        usuario.primeiroNome.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    usuario.nome,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.texto,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: [
                        _Linha(
                          icone: Icons.mail_outline_rounded,
                          rotulo: 'E-mail',
                          valor: usuario.email,
                        ),
                        const Divider(height: 1),
                        _Linha(
                          icone: Icons.phone_outlined,
                          rotulo: 'Telefone',
                          valor: usuario.telefone ?? 'Não informado',
                        ),
                        const Divider(height: 1),
                        _Linha(
                          icone: Icons.cake_outlined,
                          rotulo: 'Nascimento',
                          valor: usuario.dataNascimento == null
                              ? 'Não informado'
                              : Datas.isoParaBr(usuario.dataNascimento!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(Icons.settings_rounded, color: context.destaque),
                      title: Text(
                        'Configurações',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.texto,
                        ),
                      ),
                      subtitle: Text(
                        'Tema, tamanho da letra e bloqueio com digital ou rosto',
                        style: TextStyle(color: context.textoSuave),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.textoSuave,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ConfiguracoesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    texto: 'SAIR DA CONTA',
                    icone: Icons.logout_rounded,
                    secundario: true,
                    onPressed: () => _sair(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _Linha extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;

  const _Linha({
    required this.icone,
    required this.rotulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icone, color: context.destaque),
      title: Text(
        rotulo,
        style: TextStyle(fontSize: 12, color: context.textoSuave),
      ),
      subtitle: Text(
        valor,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.texto,
        ),
      ),
    );
  }
}
