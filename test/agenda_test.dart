import 'package:flutter_test/flutter_test.dart';
import 'package:saude_em_dia/models/medicamento.dart';
import 'package:saude_em_dia/utils/agenda.dart';
import 'package:saude_em_dia/utils/formatters.dart';
import 'package:saude_em_dia/utils/validators.dart';

Medicamento medicamento({
  required String horarioInicio,
  required int intervalo,
  required int dias,
  required DateTime criadoEm,
  bool ativo = true,
}) {
  return Medicamento(
    id: 1,
    receitaId: 1,
    nome: 'Paracetamol',
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
  group('Agenda.horariosDoTratamento', () {
    test('cadastrado antes do horário inicial: começa no horário inicial', () {
      // Exemplo do pedido: 8 em 8 horas, início 08:00, 3 dias.
      final m = medicamento(
        horarioInicio: '08:00:00',
        intervalo: 8,
        dias: 3,
        criadoEm: DateTime(2026, 9, 18, 7, 0),
      );

      final h = Agenda.horariosDoTratamento(m);

      expect(h.length, 9);
      expect(h.take(3).map(hm).toList(), ['08:00', '16:00', '00:00']);
      expect(h.first, DateTime(2026, 9, 18, 8, 0));
      expect(h.last, DateTime(2026, 9, 21, 0, 0));
    });

    test('cadastrado depois do horário inicial: pula as doses do passado', () {
      final m = medicamento(
        horarioInicio: '08:00:00',
        intervalo: 8,
        dias: 3,
        criadoEm: DateTime(2026, 9, 18, 15, 0),
      );

      final h = Agenda.horariosDoTratamento(m);

      expect(h.first, DateTime(2026, 9, 18, 16, 0));
      expect(h.length, 9);
      expect(h.every((d) => !d.isBefore(m.criadoEm)), isTrue);
    });

    test('intervalo de 24 horas e 5 dias gera 5 doses', () {
      final m = medicamento(
        horarioInicio: '21:30:00',
        intervalo: 24,
        dias: 5,
        criadoEm: DateTime(2026, 9, 18, 9, 0),
      );

      final h = Agenda.horariosDoTratamento(m);

      expect(h.length, 5);
      expect(h.map(hm).toSet(), {'21:30'});
    });

    test('intervalo que não divide 24 horas segue a grade sem quebrar', () {
      final m = medicamento(
        horarioInicio: '06:00:00',
        intervalo: 5,
        dias: 1,
        criadoEm: DateTime(2026, 9, 18, 5, 0),
      );

      final h = Agenda.horariosDoTratamento(m);

      expect(h.map(hm).toList(), ['06:00', '11:00', '16:00', '21:00', '02:00']);
    });
  });

  group('Agenda.dosesDoDia', () {
    test('lista só as doses do dia, em ordem, e ignora pausados', () {
      final ativo = medicamento(
        horarioInicio: '08:00:00',
        intervalo: 8,
        dias: 3,
        criadoEm: DateTime(2026, 9, 18, 7, 0),
      );

      final pausado = medicamento(
        horarioInicio: '09:00:00',
        intervalo: 12,
        dias: 3,
        criadoEm: DateTime(2026, 9, 18, 7, 0),
        ativo: false,
      );

      final doses = Agenda.dosesDoDia([pausado, ativo], DateTime(2026, 9, 19));

      expect(doses.map((d) => hm(d.horario)).toList(), ['00:00', '08:00', '16:00']);
    });

    test('dia depois do fim do tratamento não tem doses', () {
      final m = medicamento(
        horarioInicio: '08:00:00',
        intervalo: 12,
        dias: 2,
        criadoEm: DateTime(2026, 9, 18, 7, 0),
      );

      expect(Agenda.dosesDoDia([m], DateTime(2026, 9, 25)), isEmpty);
    });
  });

  group('Agenda.status', () {
    test('a tomar (futuro) e atrasado (passado)', () {
      final agora = DateTime(2026, 9, 18, 12, 0);

      expect(Agenda.status(DateTime(2026, 9, 18, 16, 0), agora), StatusDose.aTomar);
      expect(Agenda.status(DateTime(2026, 9, 18, 8, 0), agora), StatusDose.atrasado);
    });
  });

  group('Validators e formatadores', () {
    test('data inexistente é recusada', () {
      final validar = Validators.data();

      expect(validar('31/02/2026'), isNotNull);
      expect(validar('18/09/2026'), isNull);
      expect(validar('18/09/26'), isNotNull);
    });

    test('data no futuro é recusada quando naoFutura', () {
      expect(Validators.data(naoFutura: true)('01/01/2999'), isNotNull);
    });

    test('telefone opcional', () {
      expect(Validators.telefoneOpcional(''), isNull);
      expect(Validators.telefoneOpcional('(11) 98888-7777'), isNull);
      expect(Validators.telefoneOpcional('123'), isNotNull);
    });

    test('máscara de telefone', () {
      final f = TelefoneInputFormatter();

      String aplicar(String t) => f
          .formatEditUpdate(TextEditingValue.empty, TextEditingValue.empty.copyWith(text: t))
          .text;

      expect(aplicar('11988887777'), '(11) 98888-7777');
      expect(aplicar('1138887777'), '(11) 3888-7777');
      expect(aplicar('119'), '(11) 9');
    });

    test('conversão de datas', () {
      expect(Datas.brParaIso('18/09/2026'), '2026-09-18');
      expect(Datas.isoParaBr('2026-09-18'), '18/09/2026');
    });
  });
}

