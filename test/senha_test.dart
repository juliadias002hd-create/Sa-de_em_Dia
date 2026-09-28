import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_em_dia/screens/login/esqueci_senha_screen.dart';
import 'package:saude_em_dia/screens/login/login_screen.dart';
import 'package:saude_em_dia/screens/login/redefinir_senha_screen.dart';
import 'package:saude_em_dia/theme/app_theme.dart';
import 'package:saude_em_dia/utils/validators.dart';

Widget app(Widget tela) => MaterialApp(theme: AppTheme.claro, home: tela);

void main() {
  group('Validators.codigo', () {
    test('aceita só 6 números', () {
      expect(Validators.codigo('123456'), isNull);
      expect(Validators.codigo(' 123456 '), isNull);
      expect(Validators.codigo(''), isNotNull);
      expect(Validators.codigo('12345'), isNotNull);
      expect(Validators.codigo('1234567'), isNotNull);
      expect(Validators.codigo('12a456'), isNotNull);
    });
  });

  group('Login', () {
    testWidgets('tem o link "Esqueci minha senha" e ele abre a tela certa', (tester) async {
      await tester.pumpWidget(app(const LoginScreen()));

      expect(find.text('Esqueci minha senha'), findsOneWidget);

      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      expect(find.text('Vamos redefinir sua senha'), findsOneWidget);
      expect(find.text('ENVIAR CÓDIGO'), findsOneWidget);
    });
  });

  group('Esqueci minha senha - passo 1', () {
    testWidgets('e-mail digitado no login já vem preenchido', (tester) async {
      await tester.pumpWidget(app(const EsqueciSenhaScreen(emailInicial: 'ana@teste.com')));

      expect(find.text('ana@teste.com'), findsOneWidget);
    });

    testWidgets('e-mail vazio ou inválido é recusado antes de chamar a API', (tester) async {
      await tester.pumpWidget(app(const EsqueciSenhaScreen()));

      await tester.tap(find.text('ENVIAR CÓDIGO'));
      await tester.pump();

      expect(find.text('Informe seu e-mail.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'abc@');
      await tester.tap(find.text('ENVIAR CÓDIGO'));
      await tester.pump();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    });
  });

  group('Esqueci minha senha - passo 2', () {
    testWidgets('mostra para qual e-mail o código foi enviado', (tester) async {
      await tester.pumpWidget(app(const RedefinirSenhaScreen(email: 'ana@teste.com')));

      expect(find.textContaining('ana@teste.com'), findsOneWidget);
      expect(find.text('ALTERAR SENHA'), findsOneWidget);

      // Limpa o relógio do "Reenviar código" para o teste terminar limpo.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('campos vazios mostram as mensagens de erro', (tester) async {
      await tester.pumpWidget(app(const RedefinirSenhaScreen(email: 'ana@teste.com')));

      await tester.tap(find.text('ALTERAR SENHA'));
      await tester.pump();

      expect(find.text('Informe o código que você recebeu por e-mail.'), findsOneWidget);
      expect(find.text('Informe a senha.'), findsOneWidget);
      expect(find.text('Confirme a senha.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('código com menos de 6 números e senhas diferentes são recusados', (tester) async {
      await tester.pumpWidget(app(const RedefinirSenhaScreen(email: 'ana@teste.com')));

      final campos = find.byType(TextFormField);

      await tester.enterText(campos.at(0), '123');
      await tester.enterText(campos.at(1), 'SenhaNova@1');
      await tester.enterText(campos.at(2), 'OutraCoisa@2');
      await tester.tap(find.text('ALTERAR SENHA'));
      await tester.pump();

      expect(find.text('O código tem 6 números.'), findsOneWidget);
      expect(find.text('As senhas não são iguais.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('o campo do código só aceita números e no máximo 6', (tester) async {
      await tester.pumpWidget(app(const RedefinirSenhaScreen(email: 'ana@teste.com')));

      await tester.enterText(find.byType(TextFormField).first, '12ab34567890');
      await tester.pump();

      expect(find.text('123456'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('"Reenviar código" começa bloqueado, com contagem regressiva', (tester) async {
      await tester.pumpWidget(app(const RedefinirSenhaScreen(email: 'ana@teste.com')));

      expect(find.textContaining('Reenviar código em'), findsOneWidget);

      await tester.pump(const Duration(seconds: 31));

      expect(find.text('Reenviar código'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
