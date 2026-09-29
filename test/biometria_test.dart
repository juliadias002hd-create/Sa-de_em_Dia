import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:saude_em_dia/screens/bloqueio/bloqueio_screen.dart';
import 'package:saude_em_dia/services/biometria_service.dart';
import 'package:saude_em_dia/services/bloqueio_controller.dart';
import 'package:saude_em_dia/theme/app_theme.dart';

/// Leitor de digital de mentira: devolve o que o teste mandar.
class _LeitorFalso extends LocalAuthPlatform with MockPlatformInterfaceMixin {
  bool suportado = true;
  bool temHardware = true;
  List<BiometricType> cadastradas = [BiometricType.fingerprint];
  Object? resposta = true; // true, false ou uma LocalAuthException
  int pedidos = 0;

  @override
  Future<bool> isDeviceSupported() async => suportado;

  @override
  Future<bool> deviceSupportsBiometrics() async => temHardware;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => cadastradas;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    pedidos++;

    final r = resposta;

    if (r is LocalAuthException) {
      throw r;
    }

    return r == true;
  }
}

void main() {
  late _LeitorFalso leitor;

  setUp(() {
    leitor = _LeitorFalso();
    LocalAuthPlatform.instance = leitor;
  });

  group('BiometriaService', () {
    // A plataforma "android" só é forçada aqui (não no arquivo inteiro):
    // testWidgets confere, ao final de CADA teste, que nenhuma variável de
    // depuração do Flutter ficou alterada, e essa checagem roda antes do
    // tearDown() de fora deste grupo — deixaria as telas (mais abaixo)
    // reprovando por um motivo que nada tem a ver com elas.
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('digital cadastrada: disponível', () async {
      expect(
        await BiometriaService().verificar(),
        DisponibilidadeBiometria.disponivel,
      );
    });

    test('hardware sem nada cadastrado: pede para cadastrar', () async {
      leitor.cadastradas = [];

      expect(
        await BiometriaService().verificar(),
        DisponibilidadeBiometria.semCadastro,
      );
    });

    test('aparelho sem suporte', () async {
      leitor.suportado = false;

      expect(
        await BiometriaService().verificar(),
        DisponibilidadeBiometria.naoSuportado,
      );
    });

    test('desktop não é suportado', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(
        await BiometriaService().verificar(),
        DisponibilidadeBiometria.naoSuportado,
      );
    });

    test('reconhece digital e rosto', () async {
      leitor.cadastradas = [BiometricType.face, BiometricType.fingerprint];

      final tipos = await BiometriaService().tipos();

      expect(tipos.digital, isTrue);
      expect(tipos.rosto, isTrue);
    });

    test('autenticar: aprovada e negada', () async {
      final servico = BiometriaService();

      leitor.resposta = true;
      expect(await servico.autenticar('x'), ResultadoBiometria.aprovada);

      leitor.resposta = false;
      expect(await servico.autenticar('x'), ResultadoBiometria.negada);
    });

    test('autenticar: erros do sistema viram resultados amigáveis', () async {
      final servico = BiometriaService();

      leitor.resposta = const LocalAuthException(
        code: LocalAuthExceptionCode.temporaryLockout,
      );
      expect(
        await servico.autenticar('x'),
        ResultadoBiometria.bloqueadaTemporariamente,
      );

      leitor.resposta = const LocalAuthException(
        code: LocalAuthExceptionCode.noBiometricsEnrolled,
      );
      expect(await servico.autenticar('x'), ResultadoBiometria.indisponivel);

      leitor.resposta = const LocalAuthException(
        code: LocalAuthExceptionCode.userCanceled,
      );
      expect(await servico.autenticar('x'), ResultadoBiometria.negada);
    });
  });

  group('BloqueioController', () {
    Future<BloqueioController> ligado() async {
      final c = BloqueioController.instance;
      await c.ligar();
      c.tempoParaBloquear = const Duration(milliseconds: 20);
      return c;
    }

    tearDown(() async {
      await BloqueioController.instance.desligar();
    });

    test('desligado nunca bloqueia', () {
      final c = BloqueioController.instance;

      c.bloquearSeAtivo();

      expect(c.bloqueado, isFalse);
    });

    test('ligado bloqueia ao abrir e libera ao desbloquear', () async {
      final c = await ligado();

      c.bloquearSeAtivo();
      expect(c.bloqueado, isTrue);

      c.desbloquear();
      expect(c.bloqueado, isFalse);
    });

    test('voltar depressa do segundo plano não bloqueia', () async {
      final c = await ligado();
      c.tempoParaBloquear = const Duration(hours: 1);

      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(c.bloqueado, isFalse);
    });

    test('voltar depois do tempo bloqueia', () async {
      final c = await ligado();

      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(c.bloqueado, isTrue);
    });

    test('estado inactive (janela de digital) não conta como sair', () async {
      final c = await ligado();

      c.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(c.bloqueado, isFalse);
    });

    test('desligar tira o bloqueio da frente', () async {
      final c = await ligado();

      c.bloquearSeAtivo();
      await c.desligar();

      expect(c.ativo, isFalse);
      expect(c.bloqueado, isFalse);
    });
  });

  group('BloqueioScreen', () {
    Widget app() => MaterialApp(
          theme: AppTheme.claro,
          home: const BloqueioScreen(),
        );

    testWidgets('pede a digital sozinha e desbloqueia se aprovada', (t) async {
      final c = BloqueioController.instance;
      await t.runAsync(c.ligar);
      c.bloquearSeAtivo();

      await t.pumpWidget(app());
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));

      expect(leitor.pedidos, 1);
      expect(c.bloqueado, isFalse);

      await t.runAsync(c.desligar);
    });

    testWidgets('se negada, continua bloqueado e mostra os botões', (t) async {
      leitor.resposta = false;

      final c = BloqueioController.instance;
      await t.runAsync(c.ligar);
      c.bloquearSeAtivo();

      await t.pumpWidget(app());
      await t.pumpAndSettle();

      expect(c.bloqueado, isTrue);
      expect(find.text('USAR DIGITAL'), findsOneWidget);
      expect(find.text('USAR A SENHA DA CONTA'), findsOneWidget);

      await t.tap(find.text('USAR A SENHA DA CONTA'));
      await t.pumpAndSettle();

      expect(find.text('DESBLOQUEAR'), findsOneWidget);

      await t.runAsync(c.desligar);
    });

    testWidgets('não estoura em tela pequena com letra enorme', (t) async {
      leitor.resposta = false;
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          builder: (context, filho) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: filho!,
          ),
          home: const BloqueioScreen(),
        ),
      );
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
    });
  });
}
