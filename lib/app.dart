import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/configuracoes_controller.dart';
import 'services/navegacao.dart';
import 'services/session_controller.dart';
import 'theme/app_theme.dart';

class SaudeEmDiaApp extends StatefulWidget {
  const SaudeEmDiaApp({super.key});

  @override
  State<SaudeEmDiaApp> createState() => _SaudeEmDiaAppState();
}

class _SaudeEmDiaAppState extends State<SaudeEmDiaApp> {
  final _navegador = navegadorKey;
  final _sessao = SessionController.instance;

  @override
  void initState() {
    super.initState();

    _sessao.addListener(_aoMudarSessao);
    _sessao.iniciar();
  }

  @override
  void dispose() {
    _sessao.removeListener(_aoMudarSessao);
    super.dispose();
  }

  // Se a sessão acabar (logout ou token vencido) com telas abertas por cima,
  // volta para a raiz para o login aparecer.
  void _aoMudarSessao() {
    if (_sessao.estado != EstadoSessao.logado) {
      _navegador.currentState?.popUntil((rota) => rota.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refaz o app inteiro quando o usuário muda o tema ou o tamanho da letra.
    return ListenableBuilder(
      listenable: ConfiguracoesController.instance,
      builder: (context, _) {
        final config = ConfiguracoesController.instance;

        return MaterialApp(
          navigatorKey: _navegador,
          debugShowCheckedModeBanner: false,
          title: 'Saúde em Dia',

          theme: AppTheme.claro,
          darkTheme: AppTheme.escuro,
          themeMode: config.modoDoTema,

          // Tamanho da letra: soma a escolha do usuário à configuração de
          // fonte do próprio celular (com um teto, para nada quebrar).
          builder: (context, filho) {
            final dados = MediaQuery.of(context);
            final doSistema = dados.textScaler.scale(1.0);
            final escala = (doSistema * config.escalaDaFonte).clamp(0.8, 2.2);

            return MediaQuery(
              data: dados.copyWith(textScaler: TextScaler.linear(escala)),
              child: filho!,
            );
          },

          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: ListenableBuilder(
            listenable: _sessao,
            builder: (context, _) {
              return switch (_sessao.estado) {
                EstadoSessao.carregando => const SplashScreen(),
                EstadoSessao.semConexao => SemConexaoScreen(
                    aoTentarNovamente: _sessao.iniciar,
                  ),
                EstadoSessao.deslogado => const LoginScreen(),
                EstadoSessao.logado => const HomeScreen(),
              };
            },
          ),
        );
      },
    );
  }
}
