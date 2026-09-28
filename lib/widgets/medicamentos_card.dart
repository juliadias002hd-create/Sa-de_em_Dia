import 'package:flutter/material.dart';

import '../models/medicamento.dart';
import '../theme/app_theme.dart';
import '../utils/agenda.dart';
import '../utils/formatters.dart';

/// Ação escolhida no menu de um cartão de medicamento.
enum AcaoMedicamento { editar, alternarAtivo, excluir }


/// Cartão de um medicamento (usado dentro da receita).
class MedicamentoCard extends StatelessWidget {
  final Medicamento medicamento;
  final void Function(AcaoMedicamento acao)? aoEscolherAcao;

  const MedicamentoCard({
    super.key,
    required this.medicamento,
    this.aoEscolherAcao,
  });

  @override
  Widget build(BuildContext context) {
    final m = medicamento;

    return Opacity(
      opacity: m.ativo ? 1 : 0.6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.turquesa.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppColors.turquesa,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nome,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.dosagem,
                      style: TextStyle(color: context.textoSuave),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Etiqueta(
                          icone: Icons.schedule_rounded,
                          texto: 'Início ${m.horarioFormatado}',
                        ),
                        _Etiqueta(
                          icone: Icons.repeat_rounded,
                          texto: m.intervaloTexto,
                        ),
                        _Etiqueta(
                          icone: Icons.event_rounded,
                          texto: m.duracaoTexto,
                        ),
                        if (!m.ativo)
                          const _Etiqueta(
                            icone: Icons.pause_circle_outline_rounded,
                            texto: 'Pausado',
                          ),
                      ],
                    ),
                    if (m.observacoes != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        m.observacoes!,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: context.textoSuave,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (aoEscolherAcao != null)
                PopupMenuButton<AcaoMedicamento>(
                  tooltip: 'Mais opções',
                  onSelected: aoEscolherAcao,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: AcaoMedicamento.editar,
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
                      value: AcaoMedicamento.alternarAtivo,
                      child: Text(m.ativo ? 'Pausar' : 'Reativar'),
                    ),
                    const PopupMenuItem(
                      value: AcaoMedicamento.excluir,
                      child: Text('Excluir'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Cores e rótulos de cada situação de uma dose.
(String, Color) situacaoDaDose(BuildContext context, StatusDose status) {
  return switch (status) {
    StatusDose.aTomar => ('A tomar', context.destaque),
    StatusDose.tomado => ('Tomado', AppColors.sucesso),
    StatusDose.atrasado => ('Atrasado', AppColors.alerta),
  };
}


/// Cartão de uma dose na tela inicial: horário, nome, dosagem e situação.
///
/// Com [aoTomar], mostra o botão "TOMAR" (dose ainda não tomada).
/// Com [aoDesfazer], mostra "Desfazer" (dose já tomada).
class DoseCard extends StatelessWidget {
  final DoseAgendada dose;
  final StatusDose status;

  /// Quando a dose foi tomada (só para doses "Tomado").
  final DateTime? horarioTomado;

  final VoidCallback? aoTomar;
  final VoidCallback? aoDesfazer;

  /// Deixa os botões desativados enquanto uma chamada está em andamento.
  final bool ocupado;

  const DoseCard({
    super.key,
    required this.dose,
    required this.status,
    this.horarioTomado,
    this.aoTomar,
    this.aoDesfazer,
    this.ocupado = false,
  });

  @override
  Widget build(BuildContext context) {
    final (rotulo, cor) = situacaoDaDose(context, status);

    final m = dose.medicamento;

    // Com a letra grande, o cartão passa a ter duas linhas (informações em
    // cima; situação e botões embaixo), para nada ficar espremido.
    final letraGrande = MediaQuery.textScalerOf(context).scale(1.0) >= 1.25;

    final horario = Container(
      // Largura mínima (e não fixa): cresce junto com a letra.
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        Datas.hora(dose.horario.hour, dose.horario.minute),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: cor,
        ),
      ),
    );

    final informacoes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          m.nome,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.texto,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          horarioTomado == null
              ? m.dosagem
              : '${m.dosagem} • tomado às ${Datas.hora(horarioTomado!.hour, horarioTomado!.minute)}',
          style: TextStyle(
            fontSize: 13,
            color: context.textoSuave,
          ),
        ),
        // De qual receita é: diferencia dois medicamentos iguais.
        if (m.medico != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 13,
                color: context.textoSuave,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  m.medico!,
                  maxLines: letraGrande ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textoSuave,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final situacao = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );

    final tomar = aoTomar == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: FilledButton(
              onPressed: ocupado ? null : aoTomar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sucesso,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('TOMAR'),
            ),
          );

    final desfazer = aoDesfazer == null
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30),
            child: TextButton(
              onPressed: ocupado ? null : aoDesfazer,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Desfazer'),
            ),
          );

    return LayoutBuilder(
      builder: (context, restricoes) {
        // Empilha quando a letra é grande OU quando a tela é estreita para o
        // tamanho da letra. 315 é a largura mínima (já descontada a escala)
        // em que a versão de uma linha cabe sem estourar.
        final empilhar = letraGrande ||
            restricoes.maxWidth / MediaQuery.textScalerOf(context).scale(1.0) < 315;

        return empilhar
            ? _duasLinhas(horario, informacoes, situacao, tomar, desfazer)
            : _umaLinha(horario, informacoes, situacao, tomar, desfazer);
      },
    );
  }

  Widget _duasLinhas(
    Widget horario,
    Widget informacoes,
    Widget situacao,
    Widget? tomar,
    Widget? desfazer,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                horario,
                const SizedBox(width: 16),
                Expanded(child: informacoes),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                situacao,
                ?tomar,
                ?desfazer,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _umaLinha(
    Widget horario,
    Widget informacoes,
    Widget situacao,
    Widget? tomar,
    Widget? desfazer,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            horario,
            const SizedBox(width: 16),
            Expanded(child: informacoes),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                situacao,
                if (tomar != null) ...[
                  const SizedBox(height: 8),
                  tomar,
                ],
                if (desfazer != null) ...[
                  const SizedBox(height: 4),
                  desfazer,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _Etiqueta extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Etiqueta({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.fundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: context.textoSuave),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(fontSize: 12, color: context.textoSuave),
          ),
        ],
      ),
    );
  }
}
