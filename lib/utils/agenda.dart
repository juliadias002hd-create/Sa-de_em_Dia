import '../models/historico.dart';
import '../models/medicamento.dart';

/// Uma linha do histórico: uma dose e o que aconteceu com ela.
class ItemHistorico {
  final String nome;
  final String dosagem;

  /// Horário programado da dose.
  final DateTime horario;
  final StatusDose status;

  /// Quando foi tomada (só para doses "tomado").
  final DateTime? horarioTomado;

  const ItemHistorico({
    required this.nome,
    required this.dosagem,
    required this.horario,
    required this.status,
    this.horarioTomado,
  });
}


/// Todas as doses de um dia, em ordem de horário.
class DiaHistorico {
  final DateTime dia;
  final List<ItemHistorico> itens;

  const DiaHistorico({required this.dia, required this.itens});

  int get tomadas => itens.where((i) => i.status == StatusDose.tomado).length;
}


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

  /// Situação de uma dose:
  ///  - [tomado]: há um registro de que o paciente tomou;
  ///  - senão, "atrasado" se o horário já passou, ou "a tomar" se ainda não.
  static StatusDose status(
    DateTime horario,
    DateTime agora, {
    bool tomado = false,
  }) {
    if (tomado) {
      return StatusDose.tomado;
    }

    return horario.isBefore(agora) ? StatusDose.atrasado : StatusDose.aTomar;
  }

  /// Monta o histórico de [inicio] a [fim] (dias inteiros, inclusive).
  ///
  /// Junta as doses que deveriam ter sido tomadas (até [agora]) com os
  /// registros de "tomado":
  ///  - dose com registro  -> Tomado
  ///  - dose sem registro  -> Atrasado
  /// Registros que não batem com nenhuma dose programada (ex.: medicamento
  /// pausado depois) aparecem como Tomado.
  /// Devolve os dias do mais recente para o mais antigo.
  static List<DiaHistorico> historico({
    required List<Medicamento> medicamentos,
    required List<RegistroDose> registros,
    required DateTime inicio,
    required DateTime fim,
    required DateTime agora,
  }) {
    final comecoDoPeriodo = DateTime(inicio.year, inicio.month, inicio.day);
    final fimDoPeriodo = DateTime(fim.year, fim.month, fim.day + 1);

    final porChave = {
      for (final r in registros)
        chave(r.medicamentoId, r.horarioPrevisto): r,
    };

    final usadas = <String>{};
    final itens = <ItemHistorico>[];

    for (final m in medicamentos.where((m) => m.ativo)) {
      for (final h in horariosDoTratamento(m)) {
        if (h.isBefore(comecoDoPeriodo) ||
            !h.isBefore(fimDoPeriodo) ||
            h.isAfter(agora)) {
          continue;
        }

        final c = chave(m.id, h);
        final registro = porChave[c];

        if (registro != null) {
          usadas.add(c);
        }

        itens.add(
          ItemHistorico(
            nome: m.nome,
            dosagem: m.dosagem,
            horario: h,
            status: registro == null ? StatusDose.atrasado : StatusDose.tomado,
            horarioTomado: registro?.horarioTomado,
          ),
        );
      }
    }

    for (final entrada in porChave.entries) {
      if (usadas.contains(entrada.key)) {
        continue;
      }

      final r = entrada.value;

      itens.add(
        ItemHistorico(
          nome: r.medicamentoNome,
          dosagem: r.medicamentoDosagem,
          horario: r.horarioPrevisto,
          status: StatusDose.tomado,
          horarioTomado: r.horarioTomado,
        ),
      );
    }

    final dias = <DateTime, List<ItemHistorico>>{};

    for (final item in itens) {
      final dia = DateTime(item.horario.year, item.horario.month, item.horario.day);

      dias.putIfAbsent(dia, () => []).add(item);
    }

    final ordenados = dias.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final dia in ordenados)
        DiaHistorico(
          dia: dia,
          itens: dias[dia]!..sort((a, b) => a.horario.compareTo(b.horario)),
        ),
    ];
  }

  /// Identifica uma dose (medicamento + horário, por minuto). Serve para
  /// ligar uma dose programada ao seu registro de "tomado".
  static String chave(int medicamentoId, DateTime horario) {
    final mes = horario.month.toString().padLeft(2, '0');
    final dia = horario.day.toString().padLeft(2, '0');
    final hora = horario.hour.toString().padLeft(2, '0');
    final minuto = horario.minute.toString().padLeft(2, '0');

    return '$medicamentoId|${horario.year}-$mes-$dia $hora:$minuto';
  }
}
