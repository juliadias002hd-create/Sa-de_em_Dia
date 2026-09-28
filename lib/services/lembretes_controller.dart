import 'dart:async';

import 'package:flutter/material.dart';

import '../models/historico.dart';
import '../models/medicamento.dart';
import '../screens/alertas/alerta_dose_screen.dart';
import '../utils/agenda.dart';
import '../utils/lembretes.dart';
import 'api_service.dart';
import 'dados_notifier.dart';
import 'dose_service.dart';
import 'medicamentos_service.dart';
import 'navegacao.dart';
import 'notification_service.dart';

/// Mantém os lembretes em dia:
///  - agenda as notificações do aparelho e as refaz quando os dados mudam;
///  - abre a tela "Hora do ..." quando o horário chega com o app aberto;
///  - abre a mesma tela quando o usuário toca numa notificação.
///
/// Só fica ativo enquanto há um paciente logado.
class LembretesController {
  LembretesController._();

  static final LembretesController instance = LembretesController._();

  /// Doses que chegaram há até este tempo ainda geram alerta com o app
  /// aberto (cobre o caso de outro alerta estar na tela na hora certa).
  static const Duration _tolerancia = Duration(minutes: 5);

  final MedicamentoService _medicamentos = MedicamentoService();
  final DoseService _doses = DoseService();

  bool _ativo = false;
  bool _alertaAberto = false;
  Timer? _relogio;

  List<Medicamento> _lista = [];
  Set<String> _tomadas = {};

  /// Doses que já geraram alerta nesta execução (para não repetir).
  final Set<String> _alertadas = {};


  /// Liga os lembretes (chamado quando o paciente entra no app).
  Future<void> iniciar() async {
    if (_ativo) {
      return;
    }

    _ativo = true;

    DadosApp.versao.addListener(recarregar);

    final notificacoes = NotificationService.instance;

    notificacoes.aoAbrirAlerta = abrirAlerta;

    await notificacoes.iniciar();

    // Se o app foi aberto pelo toque numa notificação, abre o alerta dela.
    final deAbertura = await notificacoes.alertaDeAbertura();

    await notificacoes.pedirPermissoes();

    await recarregar();

    _relogio = Timer.periodic(const Duration(seconds: 15), (_) => _verificar());

    if (deAbertura != null) {
      abrirAlerta(deAbertura);
    }
  }


  /// Desliga tudo. Ao sair da conta, [cancelarNotificacoes] apaga também os
  /// lembretes agendados (para não avisarem outra pessoa no mesmo celular).
  /// Quando só a sessão expira, eles são mantidos: o paciente continua
  /// sendo lembrado até entrar de novo.
  Future<void> parar({bool cancelarNotificacoes = true}) async {
    _ativo = false;

    DadosApp.versao.removeListener(recarregar);

    _relogio?.cancel();
    _relogio = null;

    _lista = [];
    _tomadas = {};
    _alertadas.clear();
    _alertaAberto = false;

    if (cancelarNotificacoes) {
      await NotificationService.instance.cancelarTudo();
    }
  }


  /// Busca os dados de novo e refaz a agenda de notificações.
  Future<void> recarregar() async {
    if (!_ativo) {
      return;
    }

    try {
      final hoje = DateTime.now();

      final resultados = await Future.wait<Object>([
        _medicamentos.listar(somenteAtivos: true),
        _doses.listar(
          inicio: hoje,
          fim: hoje.add(const Duration(days: Lembretes.janelaDias)),
        ),
      ]);

      if (!_ativo) {
        return;
      }

      _lista = resultados[0] as List<Medicamento>;

      final registros = resultados[1] as List<RegistroDose>;

      _tomadas = {
        for (final r in registros)
          Agenda.chave(r.medicamentoId, r.horarioPrevisto),
      };

      await NotificationService.instance.reagendar(
        Lembretes.planejar(
          medicamentos: _lista,
          tomadas: _tomadas,
          agora: DateTime.now(),
        ),
      );
    } on ApiException {
      // Sem conexão agora: mantém os lembretes que já estavam agendados.
    }
  }


  /// Vê se alguma dose chegou na hora (com o app aberto).
  void _verificar() {
    if (!_ativo || _alertaAberto) {
      return;
    }

    final agora = DateTime.now();

    for (final dose in Agenda.dosesDoDia(_lista, agora)) {
      final atraso = agora.difference(dose.horario);

      if (atraso.isNegative || atraso > _tolerancia) {
        continue;
      }

      final chave = Agenda.chave(dose.medicamento.id, dose.horario);

      if (_tomadas.contains(chave) || _alertadas.contains(chave)) {
        continue;
      }

      abrirAlerta(AlertaDose.deMedicamento(dose.medicamento, dose.horario));

      return;
    }
  }


  /// Abre a tela "Hora do ...!" para uma dose.
  Future<void> abrirAlerta(AlertaDose alerta) async {
    final navegador = navegadorKey.currentState;

    if (!_ativo || navegador == null || _alertaAberto) {
      return;
    }

    _alertadas.add(alerta.chave);
    _alertaAberto = true;

    await navegador.push(
      MaterialPageRoute<void>(
        builder: (_) => AlertaDoseScreen(alerta: alerta),
        fullscreenDialog: true,
      ),
    );

    _alertaAberto = false;

    // O usuário pode ter tomado ou adiado: atualiza a agenda.
    unawaited(recarregar());
  }
}
