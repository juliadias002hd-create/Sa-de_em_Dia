import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/session_controller.dart';
import 'theme/app_theme.dart';

class SaudeEmDiaApp extends StatefulWidget {
  const SaudeEmDiaApp({super.key});

  @override
  State<SaudeEmDiaApp> createState() => _SaudeEmDiaAppState();
}

class _SaudeEmDiaAppState extends State<SaudeEmDiaApp> {
  final _navegador = GlobalKey<NavigatorState>();
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
    return MaterialApp(
      navigatorKey: _navegador,
      debugShowCheckedModeBanner: false,
      title: 'Saúde em Dia',
      theme: AppTheme.claro,

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
  }
}
