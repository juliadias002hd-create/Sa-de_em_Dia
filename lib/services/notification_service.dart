import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_dados;
import 'package:timezone/timezone.dart' as tz;

import '../utils/lembretes.dart';
import 'token_storage.dart';

/// Lembretes no aparelho (notificações locais). Só existe no Android e no
/// iOS: no navegador e no computador todas as chamadas não fazem nada.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  // No Android, o som e a importância de um canal não mudam depois de
  // criado. Por isso o canal do alarme tem outro nome e o antigo é apagado.
  static const String _canalId = 'alarme_medicamentos';
  static const String _canalNome = 'Alarme de medicamentos';
  static const String _canalAntigoId = 'lembretes_medicamentos';

  /// Som de despertador (android/app/src/main/res/raw/alarme_medicamento.wav).
  static const String _somAlarme = 'alarme_medicamento';

  /// O alarme toca em loop até o usuário atender ou até este tempo.
  static const Duration _duracaoDoAlarme = Duration(minutes: 3);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _pronto = false;

  /// Chamado quando o usuário toca numa notificação.
  void Function(AlertaDose alerta)? aoAbrirAlerta;

  bool get suportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();


  /// Prepara o plugin (fuso horário, canal, ação ao tocar).
  Future<void> iniciar() async {
    if (!suportado || _pronto) {
      return;
    }

    tz_dados.initializeTimeZones();

    try {
      final fuso = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(tz.getLocation(fuso.identifier));
    } catch (_) {
      // Se não der para descobrir, usa o horário de Brasília.
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (resposta) {
        final alerta = AlertaDose.doPayload(resposta.payload);

        if (alerta != null) {
          aoAbrirAlerta?.call(alerta.comNotificacao(resposta.id));
        }
      },
    );

    // Remove o canal da versão anterior (sem som de alarme).
    await _android?.deleteNotificationChannel(channelId: _canalAntigoId);

    _pronto = true;
  }


  /// Se o app foi aberto ao tocar numa notificação, devolve a dose dela.
  Future<AlertaDose?> alertaDeAbertura() async {
    if (!_pronto) {
      return null;
    }

    final detalhes = await _plugin.getNotificationAppLaunchDetails();

    if (detalhes?.didNotificationLaunchApp != true) {
      return null;
    }

    return AlertaDose.doPayload(detalhes?.notificationResponse?.payload)
        ?.comNotificacao(detalhes?.notificationResponse?.id);
  }


  /// Pede as permissões necessárias. Devolve true se as notificações
  /// estão liberadas.
  Future<bool> pedirPermissoes() async {
    if (!_pronto) {
      return false;
    }

    var liberado = false;

    final android = _android;

    if (android != null) {
      liberado = await android.requestNotificationsPermission() ?? false;

      // Horário exato: o Android exige uma autorização especial, que abre
      // as configurações. Pede uma única vez para não incomodar.
      final exato = await android.canScheduleExactNotifications() ?? false;

      if (!exato && !await TokenStorage.lerMarca('pediu_alarme_exato')) {
        await TokenStorage.salvarMarca('pediu_alarme_exato');
        await android.requestExactAlarmsPermission();
      }

      // Tela cheia sobre o bloqueio (Android 14+ pode exigir autorização).
      if (!await TokenStorage.lerMarca('pediu_tela_cheia')) {
        await TokenStorage.salvarMarca('pediu_tela_cheia');
        await android.requestFullScreenIntentPermission();
      }
    }

    final ios = _ios;

    if (ios != null) {
      liberado = await ios.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }

    return liberado;
  }


  /// Aparência de um lembrete: comporta-se como um despertador.
  ///  - toca o som de alarme em loop (flag "insistente") até ser atendido;
  ///  - usa o volume de ALARME do celular;
  ///  - vibra em padrão repetido;
  ///  - abre a tela do alerta sozinha se o celular estiver bloqueado.
  NotificationDetails get _detalhes {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _canalId,
        _canalNome,
        channelDescription: 'Toca como um despertador na hora de cada medicamento.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(_somAlarme),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(<int>[0, 700, 350, 700, 350, 700]),
        // 4 = FLAG_INSISTENT: repete o som até o usuário atender.
        additionalFlags: Int32List.fromList(<int>[4]),
        // Para de tocar sozinho depois de um tempo.
        timeoutAfter: _duracaoDoAlarme.inMilliseconds,
        ticker: 'Hora do medicamento',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }


  Future<AndroidScheduleMode> _modo() async {
    final exato = await _android?.canScheduleExactNotifications() ?? false;

    return exato
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }


  tz.TZDateTime _paraFuso(DateTime d) {
    return tz.TZDateTime(tz.local, d.year, d.month, d.day, d.hour, d.minute);
  }


  /// Troca todos os lembretes agendados pelos de [planejados].
  /// (Os lembretes adiados não são mexidos.)
  Future<void> reagendar(List<LembretePlanejado> planejados) async {
    if (!_pronto) {
      return;
    }

    final pendentes = await _plugin.pendingNotificationRequests();

    for (final p in pendentes) {
      if (p.id < Lembretes.primeiroIdAdiado) {
        await _plugin.cancel(id: p.id);
      }
    }

    final modo = await _modo();
    final agora = tz.TZDateTime.now(tz.local);

    for (final lembrete in planejados) {
      final quando = _paraFuso(lembrete.horario);

      if (!quando.isAfter(agora)) {
        continue;
      }

      await _plugin.zonedSchedule(
        id: lembrete.id,
        scheduledDate: quando,
        notificationDetails: _detalhes,
        androidScheduleMode: modo,
        title: Lembretes.titulo(lembrete.alerta),
        body: Lembretes.corpo(lembrete.alerta),
        payload: lembrete.alerta.payload,
      );
    }
  }


  /// Adia o lembrete de uma dose: toca de novo daqui a [tempo].
  Future<void> adiar(AlertaDose alerta, Duration tempo) async {
    if (!_pronto) {
      return;
    }

    final quando = tz.TZDateTime.now(tz.local).add(tempo);

    await _plugin.zonedSchedule(
      id: Lembretes.idAdiado(alerta.chave),
      scheduledDate: quando,
      notificationDetails: _detalhes,
      androidScheduleMode: await _modo(),
      title: Lembretes.titulo(alerta),
      body: Lembretes.corpo(alerta),
      payload: alerta.payload,
    );
  }


  /// Para o alarme de uma dose que está tocando agora (som e vibração) e
  /// tira a notificação dela da barra. Chamado quando o alerta é atendido.
  Future<void> silenciar(AlertaDose alerta) async {
    if (!_pronto) {
      return;
    }

    try {
      // 1) O alarme desta dose: o número dela é fixo e conhecido.
      await _plugin.cancel(id: Lembretes.idLembrete(alerta.chave));

      // Se a notificação que tocou tiver outro número (caso raro de dois
      // números iguais na fila), cancela também esse.
      if (alerta.notificacaoId != null) {
        await _plugin.cancel(id: alerta.notificacaoId!);
      }

      // 2) O lembrete adiado desta dose, se houver.
      await _plugin.cancel(id: Lembretes.idAdiado(alerta.chave));

      // 3) Reforço: qualquer notificação ativa com o mesmo título e texto.
      //    (No Android, a lista de ativas não traz o "payload".)
      final titulo = Lembretes.titulo(alerta);
      final corpo = Lembretes.corpo(alerta);

      final ativas = await _android?.getActiveNotifications() ?? const [];

      for (final n in ativas) {
        if (n.id != null &&
            n.channelId == _canalId &&
            n.title == titulo &&
            n.body == corpo) {
          await _plugin.cancel(id: n.id!);
        }
      }
    } catch (_) {
      // Se algo falhar, o alarme para sozinho pelo tempo limite.
    }
  }


  /// Cancela o lembrete adiado de uma dose (ex.: quando ela é tomada).
  Future<void> cancelarAdiado(AlertaDose alerta) async {
    if (!_pronto) {
      return;
    }

    await _plugin.cancel(id: Lembretes.idAdiado(alerta.chave));
  }


  /// Remove todos os lembretes (ex.: ao sair da conta).
  Future<void> cancelarTudo() async {
    if (!_pronto) {
      return;
    }

    await _plugin.cancelAll();
  }
}
