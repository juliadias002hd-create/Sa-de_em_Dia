import 'package:flutter_test/flutter_test.dart';
import 'package:saude_em_dia/models/medicamento.dart';
import 'package:saude_em_dia/utils/agenda.dart';
import 'package:saude_em_dia/utils/formatters.dart';
import 'package:saude_em_dia/utils/lembretes.dart';

Medicamento medicamento({
  int id = 1,
  String nome = 'Paracetamol',
  String horarioInicio = '08:00:00',
  int intervalo = 8,
  int dias = 3,
  required DateTime criadoEm,
  bool ativo = true,
}) {
  return Medicamento(
    id: id,
    receitaId: 1,
    nome: nome,
    dosagem: '500 mg',
    intervaloHoras: intervalo,
    horarioInicio: horarioInicio,
    duracaoDias: dias,
    ativo: ativo,
    criadoEm: criadoEm,
  );
}

String hm(DateTime d) => Datas.hora(d.hour, d.minute);

void main() {
  final cadastro = DateTime(2026, 9, 18, 7, 0);

  group('Lembretes.planejar', () {
    test('agenda só doses futuras, em ordem, cada uma com número próprio', () {
      // Exemplo do pedido: 8 em 8 horas, início 08:00, 3 dias.
      final plano = Lembretes.planejar(
        medicamentos: [medicamento(criadoEm: cadastro)],
        tomadas: const {},
        agora: DateTime(2026, 9, 18, 9, 0),
      );

      expect(plano.first.horario, DateTime(2026, 9, 18, 16, 0));
      expect(plano.map((l) => l.id).toSet().length, plano.length);
      expect(plano.every((l) => l.id >= 1 && l.id < Lembretes.primeiroIdAdiado), isTrue);
      expect(plano.first.id, Lembretes.idLembrete(plano.first.alerta.chave));
      expect(
        plano.map((l) => l.horario).toList(),
        (List.of(plano.map((l) => l.horario))..sort()),
      );
      expect(plano.every((l) => l.horario.isAfter(DateTime(2026, 9, 18, 9, 0))), isTrue);
    });

    test('não agenda doses já tomadas', () {
      final plano = Lembretes.planejar(
        medicamentos: [medicamento(criadoEm: cadastro)],
        tomadas: {Agenda.chave(1, DateTime(2026, 9, 18, 16, 0))},
        agora: DateTime(2026, 9, 18, 9, 0),
      );

      expect(plano.first.horario, DateTime(2026, 9, 19, 0, 0));
    });

    test('ignora medicamentos pausados', () {
      final plano = Lembretes.planejar(
        medicamentos: [medicamento(criadoEm: cadastro, ativo: false)],
        tomadas: const {},
        agora: DateTime(2026, 9, 18, 9, 0),
      );

      expect(plano, isEmpty);
    });

    test('mistura vários medicamentos em ordem de horário', () {
      final plano = Lembretes.planejar(
        medicamentos: [
          medicamento(id: 1, nome: 'A', horarioInicio: '08:00:00', intervalo: 24, criadoEm: cadastro),
          medicamento(id: 2, nome: 'B', horarioInicio: '07:30:00', intervalo: 24, criadoEm: cadastro),
        ],
        tomadas: const {},
        agora: DateTime(2026, 9, 18, 6, 0),
      );

      expect(
        plano.take(3).map((l) => '${l.alerta.nome} ${hm(l.horario)}').toList(),
        ['B 07:30', 'A 08:00', 'B 07:30'],
      );
    });

    test('respeita o limite de 60 lembretes', () {
      final plano = Lembretes.planejar(
        medicamentos: [
          medicamento(intervalo: 1, dias: 30, criadoEm: cadastro),
        ],
        tomadas: const {},
        agora: DateTime(2026, 9, 18, 7, 30),
      );

      expect(plano.length, Lembretes.limite);
    });

    test('respeita a janela de 7 dias', () {
      final plano = Lembretes.planejar(
        medicamentos: [
          medicamento(intervalo: 24, dias: 60, criadoEm: cadastro),
        ],
        tomadas: const {},
        agora: DateTime(2026, 9, 18, 7, 30),
      );

      final limite = DateTime(2026, 9, 18, 7, 30).add(const Duration(days: 7));

      expect(plano.every((l) => !l.horario.isAfter(limite)), isTrue);
      expect(plano.length, 7);
    });

    test('tratamento terminado não gera lembretes', () {
      final plano = Lembretes.planejar(
        medicamentos: [medicamento(dias: 2, criadoEm: cadastro)],
        tomadas: const {},
        agora: DateTime(2026, 10, 30, 9, 0),
      );

      expect(plano, isEmpty);
    });
  });

  group('AlertaDose (dados dentro da notificação)', () {
    final alerta = AlertaDose(
      medicamentoId: 12,
      nome: 'Dipirona Sódica',
      dosagem: '1 g',
      horario: DateTime(2026, 9, 26, 8, 0),
    );

    test('vai e volta sem perder nada, inclusive acentos', () {
      final volta = AlertaDose.doPayload(alerta.payload);

      expect(volta, isNotNull);
      expect(volta!.medicamentoId, 12);
      expect(volta.nome, 'Dipirona Sódica');
      expect(volta.dosagem, '1 g');
      expect(volta.horario, DateTime(2026, 9, 26, 8, 0));
      expect(volta.chave, alerta.chave);
    });

    test('guarda qual notificação tocou, sem mudar a identidade da dose', () {
      final comId = alerta.comNotificacao(7);

      expect(comId.notificacaoId, 7);
      expect(comId.chave, alerta.chave);
      expect(comId.payload, alerta.payload);

      // O número da notificação não viaja dentro do texto dela.
      expect(AlertaDose.doPayload(comId.payload)!.notificacaoId, isNull);
    });

    test('texto inválido devolve null, sem quebrar', () {
      expect(AlertaDose.doPayload(null), isNull);
      expect(AlertaDose.doPayload(''), isNull);
      expect(AlertaDose.doPayload('não é json'), isNull);
      expect(AlertaDose.doPayload('{"m":"x"}'), isNull);
      expect(AlertaDose.doPayload('[1,2]'), isNull);
    });

    test('título e corpo do lembrete', () {
      expect(Lembretes.titulo(alerta), 'Hora do Dipirona Sódica!');
      expect(Lembretes.corpo(alerta), contains('1 g'));
    });
  });

  group('Diferenciar medicamentos iguais pela receita', () {
    Medicamento deReceita(int id, String medico, {String? especialidade, DateTime? data}) {
      return Medicamento(
        id: id,
        receitaId: id,
        nome: 'Paracetamol',
        dosagem: '500 mg',
        intervaloHoras: 24,
        horarioInicio: '08:00:00',
        duracaoDias: 3,
        ativo: true,
        criadoEm: DateTime(2026, 9, 18, 7, 0),
        medico: medico,
        especialidade: especialidade,
        dataReceita: data,
      );
    }

    test('dois medicamentos iguais no mesmo horário geram dois lembretes distintos', () {
      final plano = Lembretes.planejar(
        medicamentos: [
          deReceita(1, 'Dr. João da Silva'),
          deReceita(2, 'Dra. Ana Paula'),
        ],
        tomadas: const {},
        agora: DateTime(2026, 9, 18, 7, 30),
      );

      final primeiros = plano.take(2).toList();

      expect(primeiros.map((l) => l.horario).toSet(), {DateTime(2026, 9, 18, 8, 0)});
      expect(primeiros[0].id, isNot(primeiros[1].id));
      expect(primeiros[0].alerta.chave, isNot(primeiros[1].alerta.chave));

      // O que diferencia na notificação:
      expect(
        {Lembretes.corpo(primeiros[0].alerta), Lembretes.corpo(primeiros[1].alerta)},
        {'500 mg • Dr. João da Silva', '500 mg • Dra. Ana Paula'},
      );
    });

    test('o médico, a especialidade e a data viajam dentro da notificação', () {
      final alerta = AlertaDose.deMedicamento(
        deReceita(
          5,
          'Dr. João da Silva',
          especialidade: 'Clínico Geral',
          data: DateTime(2026, 9, 18),
        ),
        DateTime(2026, 9, 21, 8, 0),
      );

      final volta = AlertaDose.doPayload(alerta.payload)!;

      expect(volta.medico, 'Dr. João da Silva');
      expect(volta.especialidade, 'Clínico Geral');
      expect(volta.dataReceita, DateTime(2026, 9, 18));
      expect(Lembretes.detalheDaReceita(volta), 'Clínico Geral • Receita de 18/09/2026');
    });

    test('notificação antiga, sem médico, continua funcionando', () {
      const antigo = '{"m":3,"h":"2026-09-21 08:00","n":"Ibuprofeno","d":"400 mg"}';

      final alerta = AlertaDose.doPayload(antigo)!;

      expect(alerta.medico, isNull);
      expect(Lembretes.corpo(alerta), '400 mg • toque para marcar como tomado');
      expect(Lembretes.detalheDaReceita(alerta), '');
    });

    test('detalhe da receita mostra só o que existe', () {
      final soData = AlertaDose(
        medicamentoId: 1,
        nome: 'X',
        dosagem: '1',
        horario: DateTime(2026, 9, 21, 8, 0),
        medico: 'Dr. Y',
        dataReceita: DateTime(2026, 1, 5),
      );

      expect(Lembretes.detalheDaReceita(soData), 'Receita de 05/01/2026');
    });
  });

  group('Lembretes.idAdiado', () {
    test('é sempre o mesmo para a mesma dose e diferente entre doses', () {
      final a = Lembretes.idAdiado('1|2026-09-26 08:00');
      final b = Lembretes.idAdiado('1|2026-09-26 08:00');
      final c = Lembretes.idAdiado('1|2026-09-26 16:00');

      expect(a, b);
      expect(a, isNot(c));
    });

    test('fica na faixa dos adiados e cabe num inteiro de 32 bits', () {
      final id = Lembretes.idAdiado('99|2030-12-31 23:59');

      expect(id, greaterThanOrEqualTo(Lembretes.primeiroIdAdiado));
      expect(id, lessThan(2147483647));
    });

    test('nunca colide com os lembretes normais (1 a 60)', () {
      expect(Lembretes.idAdiado('1|x'), greaterThan(Lembretes.limite));
    });
  });
}
