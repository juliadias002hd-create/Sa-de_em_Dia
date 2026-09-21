import '../models/medicamento.dart';

/// Uma dose de um medicamento em um horário específico.
class DoseAgendada {
  final Medicamento medicamento;
  final DateTime horario;

  const DoseAgendada({
    required this.medicamento,
    required this.horario,
  });
}


enum StatusDose { aTomar, tomado, atrasado }


/// Cálculo dos horários dos medicamentos.
///
/// REGRA (a mesma para a tela inicial e para os lembretes):
///
///  - Os horários seguem uma grade que parte do "horário inicial"
///    no dia do cadastro e avança de "intervalo" em "intervalo" horas.
///  - O tratamento começa na primeira dose da grade que NÃO é anterior
///    ao momento do cadastro (não se criam lembretes para o passado).
///  - Ele dura "duração em dias" a partir dessa primeira dose.
///
/// Exemplo: Paracetamol, de 8 em 8 horas, início 08:00, 3 dias.
///  - Cadastrado às 07:00 -> 08:00, 16:00, 00:00, 08:00, ... (9 doses)
///  - Cadastrado às 15:00 -> 16:00, 00:00, 08:00, ...       (9 doses)
class Agenda {
  Agenda._();

  /// Todos os horários de dose de um tratamento, em ordem.
  static List<DateTime> horariosDoTratamento(Medicamento m) {
    final horario = m.horario;
    final cadastro = m.criadoEm;

    final base = DateTime(
      cadastro.year,
      cadastro.month,
      cadastro.day,
      horario.hour,
      horario.minute,
    );

    final passo = Duration(hours: m.intervaloHoras);

    var inicio = base;

    if (inicio.isBefore(cadastro)) {
      final passados = cadastro.difference(base).inMinutes;
      final voltas = (passados / passo.inMinutes).ceil();

      inicio = base.add(passo * voltas);
    }

    final fim = inicio.add(Duration(days: m.duracaoDias));

    final horarios = <DateTime>[];

    var atual = inicio;

    while (atual.isBefore(fim)) {
      horarios.add(atual);
      atual = atual.add(passo);
    }

    return horarios;
  }

  /// Doses de um dia (apenas medicamentos ativos), ordenadas por horário.
  static List<DoseAgendada> dosesDoDia(
    List<Medicamento> medicamentos,
    DateTime dia,
  ) {
    final doses = <DoseAgendada>[];

    for (final m in medicamentos.where((m) => m.ativo)) {
      for (final h in horariosDoTratamento(m)) {
        if (h.year == dia.year && h.month == dia.month && h.day == dia.day) {
          doses.add(DoseAgendada(medicamento: m, horario: h));
        }
      }
    }

    doses.sort((a, b) => a.horario.compareTo(b.horario));

    return doses;
  }

  /// Próxima dose futura de um medicamento (ou null se já terminou).
  static DateTime? proximaDose(Medicamento m, DateTime agora) {
    for (final h in horariosDoTratamento(m)) {
      if (h.isAfter(agora)) {
        return h;
      }
    }

    return null;
  }

  /// Situação de uma dose. (O status "tomado" passa a existir quando o
  /// histórico de doses for implementado.)
  static StatusDose status(DateTime horario, DateTime agora) {
    return horario.isBefore(agora) ? StatusDose.atrasado : StatusDose.aTomar;
  }
}
