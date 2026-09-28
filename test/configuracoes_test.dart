import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_em_dia/models/medicamento.dart';
import 'package:saude_em_dia/screens/configuracoes/configuracoes_screen.dart';
import 'package:saude_em_dia/services/configuracoes_controller.dart';
import 'package:saude_em_dia/theme/app_theme.dart';
import 'package:saude_em_dia/utils/agenda.dart';
import 'package:saude_em_dia/widgets/medicamentos_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um cartão de dose com nomes compridos, o pior caso para o layout.
Widget cartao({
  required double escala,
  required Brightness brilho,
  required StatusDose status,
  bool comBotoes = true,
}) {
  final medicamento = Medicamento(
    id: 1,
    receitaId: 1,
    nome: 'Amoxicilina com Clavulanato de Potássio',
    dosagem: '875 mg + 125 mg',
    intervaloHoras: 8,
    horarioInicio: '08:00:00',
    duracaoDias: 7,
    ativo: true,
    criadoEm: DateTime(2026, 9, 28, 7, 0),
    medico: 'Dra. Maria Fernanda de Albuquerque Souza',
  );

  return MaterialApp(
    theme: brilho == Brightness.dark ? AppTheme.escuro : AppTheme.claro,
    builder: (context, filho) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
      child: filho!,
    ),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: DoseCard(
          dose: DoseAgendada(medicamento: medicamento, horario: DateTime(2026, 9, 28, 8, 0)),
          status: status,
          horarioTomado: status == StatusDose.tomado ? DateTime(2026, 9, 28, 8, 5) : null,
          aoTomar: comBotoes && status != StatusDose.tomado ? () {} : null,
          aoDesfazer: status == StatusDose.tomado ? () {} : null,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cartão de dose em todos os tamanhos de letra e temas', () {
    for (final escala in ConfiguracoesController.niveisDeFonte) {
      for (final brilho in Brightness.values) {
        for (final status in StatusDose.values) {
          testWidgets(
            'sem estouro: letra x$escala, tema ${brilho.name}, ${status.name}',
            (tester) async {
              // Celular pequeno (320 x 640): o pior caso.
              tester.view.physicalSize = const Size(320 * 2, 640 * 2);
              tester.view.devicePixelRatio = 2;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(cartao(escala: escala, brilho: brilho, status: status));
              await tester.pump();

              // Qualquer estouro de layout vira exceção e reprova o teste.
              expect(tester.takeException(), isNull);
              expect(find.text('Amoxicilina com Clavulanato de Potássio'), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('ConfiguracoesController', () {
    test('começa no padrão: tema automático e letra normal', () async {
      final c = ConfiguracoesController.instance;
      await c.restaurarPadrao();

      expect(c.modoDoTema, ThemeMode.system);
      expect(c.nivelDeFonte, ConfiguracoesController.nivelPadrao);
      expect(c.escalaDaFonte, 1.0);
      expect(c.estaNoPadrao, isTrue);
    });

    test('guarda as escolhas e as recupera na próxima vez que o app abre', () async {
      final c = ConfiguracoesController.instance;
      await c.restaurarPadrao();

      await c.definirModoDoTema(ThemeMode.dark);
      await c.definirNivelDeFonte(4);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('config_tema'), 'escuro');
      expect(prefs.getInt('config_fonte'), 4);

      // Simula fechar e abrir o app: zera a memória e lê do disco.
      await c.definirModoDoTema(ThemeMode.light);
      await c.definirNivelDeFonte(0);
      SharedPreferences.setMockInitialValues({'config_tema': 'escuro', 'config_fonte': 4});
      await c.carregar();

      expect(c.modoDoTema, ThemeMode.dark);
      expect(c.nivelDeFonte, 4);
      expect(c.escalaDaFonte, 1.5);
    });

    test('valor guardado inválido é ignorado, sem quebrar', () async {
      final c = ConfiguracoesController.instance;
      await c.restaurarPadrao();

      SharedPreferences.setMockInitialValues({'config_tema': 'roxo', 'config_fonte': 99});
      await c.carregar();

      expect(c.modoDoTema, ThemeMode.system);
      expect(c.nivelDeFonte, ConfiguracoesController.nivelPadrao);
    });

    test('não passa dos limites da lista de tamanhos', () async {
      final c = ConfiguracoesController.instance;

      await c.definirNivelDeFonte(99);
      expect(c.nivelDeFonte, ConfiguracoesController.niveisDeFonte.length - 1);

      await c.definirNivelDeFonte(-5);
      expect(c.nivelDeFonte, 0);

      await c.restaurarPadrao();
    });

    test('restaurar padrão apaga o que estava guardado', () async {
      final c = ConfiguracoesController.instance;

      await c.definirModoDoTema(ThemeMode.dark);
      await c.definirNivelDeFonte(3);
      await c.restaurarPadrao();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('config_tema'), isFalse);
      expect(prefs.containsKey('config_fonte'), isFalse);
      expect(c.estaNoPadrao, isTrue);
    });
  });

  group('Tela de Configurações', () {
    testWidgets('mostra as três opções de tema e o tamanho da letra', (tester) async {
      await ConfiguracoesController.instance.restaurarPadrao();

      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const ConfiguracoesScreen()));

      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
      expect(find.text('Automático'), findsOneWidget);
      expect(find.text('Tamanho da letra'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
    });

    testWidgets('tocar em "Escuro" e no A+ muda as preferências', (tester) async {
      final c = ConfiguracoesController.instance;
      await c.restaurarPadrao();

      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const ConfiguracoesScreen()));

      await tester.tap(find.text('Escuro'));
      await tester.pump();
      expect(c.modoDoTema, ThemeMode.dark);

      await tester.tap(find.byTooltip('Aumentar a letra'));
      await tester.pump();
      expect(c.nomeDoNivel, 'Grande');
      expect(find.text('Grande'), findsWidgets);

      await c.restaurarPadrao();
    });
  });
}
