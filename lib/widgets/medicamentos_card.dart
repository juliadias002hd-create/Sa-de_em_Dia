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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.dosagem,
                      style: const TextStyle(color: AppColors.textoSuave),
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textoSuave,
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
(String, Color) situacaoDaDose(StatusDose status) {
  return switch (status) {
    StatusDose.aTomar => ('A tomar', AppColors.roxo),
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
    final (rotulo, cor) = situacaoDaDose(status);

    final m = dose.medicamento;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.texto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    horarioTomado == null
                        ? m.dosagem
                        : '${m.dosagem} • tomado às ${Datas.hora(horarioTomado!.hour, horarioTomado!.minute)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                ),
                if (aoTomar != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: ocupado ? null : aoTomar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sucesso,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('TOMAR'),
                    ),
                  ),
                ],
                if (aoDesfazer != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 30,
                    child: TextButton(
                      onPressed: ocupado ? null : aoDesfazer,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Desfazer'),
                    ),
                  ),
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
        color: AppColors.fundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: AppColors.textoSuave),
          const SizedBox(width: 4),
          Text(
            texto,
            style: const TextStyle(fontSize: 12, color: AppColors.textoSuave),
          ),
        ],
      ),
    );
  }
}
