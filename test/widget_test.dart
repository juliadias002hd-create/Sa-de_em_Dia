import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_em_dia/screens/login/login_screen.dart';
import 'package:saude_em_dia/theme/app_theme.dart';

void main() {
  Widget app() => MaterialApp(theme: AppTheme.claro, home: const LoginScreen());

  testWidgets('tela de login mostra os campos e o botão', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Saúde em Dia'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.textContaining('Criar conta'), findsOneWidget);
  });

  testWidgets('login com campos vazios mostra mensagens de erro', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('ENTRAR'));
    await tester.pump();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
  });

  testWidgets('e-mail inválido é recusado antes de chamar a API', (tester) async {
    await tester.pumpWidget(app());

    await tester.enterText(find.byType(TextFormField).first, 'abc@');
    await tester.tap(find.text('ENTRAR'));
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
  });
}
