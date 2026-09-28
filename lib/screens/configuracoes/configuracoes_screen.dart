import 'package:flutter/material.dart';

import '../../services/configuracoes_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

/// Configurações de aparência: tema (claro, escuro ou automático) e tamanho
/// da letra. As mudanças valem na hora, no app inteiro.
class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = ConfiguracoesController.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: config,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SecaoTema(config: config),
                      const SizedBox(height: 20),
                      _SecaoFonte(config: config),
                      const SizedBox(height: 28),
                      AppButton(
                        texto: 'RESTAURAR PADRÃO',
                        icone: Icons.restart_alt_rounded,
                        secundario: true,
                        onPressed: config.estaNoPadrao
                            ? null
                            : config.restaurarPadrao,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


class _Titulo extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Titulo({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, color: context.destaque),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.texto,
            ),
          ),
        ),
      ],
    );
  }
}


class _SecaoTema extends StatelessWidget {
  final ConfiguracoesController config;

  const _SecaoTema({required this.config});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titulo(icone: Icons.palette_outlined, texto: 'Tema'),
            const SizedBox(height: 14),
            _OpcaoDeTema(
              config: config,
              modo: ThemeMode.light,
              icone: Icons.light_mode_rounded,
              titulo: 'Claro',
              descricao: 'Fundo claro.',
            ),
            const SizedBox(height: 10),
            _OpcaoDeTema(
              config: config,
              modo: ThemeMode.dark,
              icone: Icons.dark_mode_rounded,
              titulo: 'Escuro',
              descricao: 'Fundo escuro, mais confortável à noite.',
            ),
            const SizedBox(height: 10),
            _OpcaoDeTema(
              config: config,
              modo: ThemeMode.system,
              icone: Icons.brightness_auto_rounded,
              titulo: 'Automático',
              descricao: 'Acompanha o tema do seu celular.',
            ),
          ],
        ),
      ),
    );
  }
}


/// Uma das três opções de tema. É uma lista (e não botões lado a lado) para
/// os textos nunca quebrarem, mesmo com a letra bem grande.
class _OpcaoDeTema extends StatelessWidget {
  final ConfiguracoesController config;
  final ThemeMode modo;
  final IconData icone;
  final String titulo;
  final String descricao;

  const _OpcaoDeTema({
    required this.config,
    required this.modo,
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    final escolhida = config.modoDoTema == modo;

    return Semantics(
      button: true,
      selected: escolhida,
      label: '$titulo. $descricao',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => config.definirModoDoTema(modo),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: escolhida ? context.destaque.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: escolhida ? context.destaque : context.borda,
              width: escolhida ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icone, color: escolhida ? context.destaque : context.textoSuave),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.texto,
                      ),
                    ),
                    Text(
                      descricao,
                      style: TextStyle(fontSize: 13, color: context.textoSuave),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                escolhida
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: escolhida ? context.destaque : context.textoSuave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SecaoFonte extends StatelessWidget {
  final ConfiguracoesController config;

  const _SecaoFonte({required this.config});

  @override
  Widget build(BuildContext context) {
    final niveis = ConfiguracoesController.niveisDeFonte.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titulo(icone: Icons.text_fields_rounded, texto: 'Tamanho da letra'),
            const SizedBox(height: 6),
            Text(
              config.nomeDoNivel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.destaque,
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Diminuir a letra',
                  onPressed: config.nivelDeFonte > 0
                      ? () => config.definirNivelDeFonte(config.nivelDeFonte - 1)
                      : null,
                  icon: const Icon(Icons.text_decrease_rounded),
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: (niveis - 1).toDouble(),
                    divisions: niveis - 1,
                    value: config.nivelDeFonte.toDouble(),
                    label: config.nomeDoNivel,
                    onChanged: (v) => config.definirNivelDeFonte(v.round()),
                  ),
                ),
                IconButton(
                  tooltip: 'Aumentar a letra',
                  onPressed: config.nivelDeFonte < niveis - 1
                      ? () => config.definirNivelDeFonte(config.nivelDeFonte + 1)
                      : null,
                  icon: const Icon(Icons.text_increase_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Exemplo',
              style: TextStyle(fontSize: 12, color: context.textoSuave),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.fundo,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borda),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hora do Paracetamol!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.texto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '500 mg • Dr. João da Silva',
                    style: TextStyle(fontSize: 14, color: context.textoSuave),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sucesso.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Tomado às 08:00',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sucesso,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
