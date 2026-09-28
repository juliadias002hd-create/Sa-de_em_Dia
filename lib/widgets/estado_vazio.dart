import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mensagem amigável quando não há nada para mostrar.
class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String mensagem;
  final Widget? acao;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.mensagem,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.roxo.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 44, color: context.destaque),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.texto,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: context.textoSuave,
              ),
            ),
            if (acao != null) ...[
              const SizedBox(height: 22),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}


/// Mensagem de erro de carregamento, com botão para tentar de novo.
class ErroCarregamento extends StatelessWidget {
  final String mensagem;
  final VoidCallback aoTentarNovamente;

  const ErroCarregamento({
    super.key,
    required this.mensagem,
    required this.aoTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return EstadoVazio(
      icone: Icons.cloud_off_rounded,
      titulo: 'Ops! Algo deu errado',
      mensagem: mensagem,
      acao: OutlinedButton.icon(
        onPressed: aoTentarNovamente,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('TENTAR NOVAMENTE'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(220, 48)),
      ),
    );
  }
}
