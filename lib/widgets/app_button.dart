import 'package:flutter/material.dart';

/// Botão padrão do app, com estado de carregamento.
///
/// [secundario] deixa o botão só com contorno.
class AppButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;
  final bool secundario;
  final IconData? icone;

  const AppButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.carregando = false,
    this.secundario = false,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    // Enquanto carrega, o botão fica desativado (evita toque duplo).
    final acao = carregando ? null : onPressed;

    final conteudo = carregando
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    if (secundario) {
      return OutlinedButton(
        onPressed: acao,
        child: conteudo,
      );
    }

    return ElevatedButton(
      onPressed: acao,
      child: conteudo,
    );
  }
}
