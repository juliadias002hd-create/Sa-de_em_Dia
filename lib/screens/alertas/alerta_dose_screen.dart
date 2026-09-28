import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/dados_notifier.dart';
import '../../services/dose_service.dart';
import '../../services/notification_service.dart';
import '../../services/som_alarme.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/lembretes.dart';

/// "Hora do Paracetamol!" com os botões TOMAR AGORA e ADIAR.
///
/// Aparece quando o usuário toca na notificação ou quando o horário chega
/// com o app aberto.
class AlertaDoseScreen extends StatefulWidget {
  final AlertaDose alerta;

  const AlertaDoseScreen({super.key, required this.alerta});

  @override
  State<AlertaDoseScreen> createState() => _AlertaDoseScreenState();
}

class _AlertaDoseScreenState extends State<AlertaDoseScreen> {
  static const List<int> _opcoesAdiar = [5, 10, 15, 30];

  final _doses = DoseService();

  bool _carregando = false;

  @override
  void initState() {
    super.initState();

    _iniciarSom();
  }

  /// Toca o som de despertador em loop enquanto esta tela estiver aberta
  /// (navegador, Android e iOS).
  Future<void> _iniciarSom() async {
    final tocou = await SomAlarme.instance.tocar();

    // Se o som da tela começou, o alarme da notificação para de tocar para
    // não haver dois sons juntos (no Android ele repetia o mesmo som).
    if (tocou) {
      await NotificationService.instance.silenciar(widget.alerta);
    }
  }

  @override
  void dispose() {
    // Qualquer que seja o jeito de fechar (tomar, adiar, "agora não" ou
    // voltar), o alarme dessa dose para de tocar.
    SomAlarme.instance.parar();
    NotificationService.instance.silenciar(widget.alerta);

    super.dispose();
  }

  void _mensagem(String texto) {
    // O aviso aparece na tela que ficar por baixo depois que esta fechar.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _tomarAgora() async {
    // O som para assim que o usuário responde, sem esperar a tela fechar.
    SomAlarme.instance.parar();

    setState(() => _carregando = true);

    try {
      await _doses.registrar(
        medicamentoId: widget.alerta.medicamentoId,
        horarioPrevisto: widget.alerta.horario,
      );

      await NotificationService.instance.cancelarAdiado(widget.alerta);

      DadosApp.mudou();

      if (!mounted) {
        return;
      }

      _mensagem('${widget.alerta.nome}: dose registrada!');

      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      if (e.statusCode == 409) {
        // Já estava marcada: só encerra o alerta.
        await NotificationService.instance.cancelarAdiado(widget.alerta);

        DadosApp.mudou();

        if (mounted) {
          _mensagem('Você já marcou esta dose como tomada.');
          Navigator.of(context).pop();
        }

        return;
      }

      _mensagem(e.mensagem);

      setState(() => _carregando = false);
    }
  }

  Future<void> _adiar() async {
    // Ao abrir o menu de adiar, o som já se cala.
    SomAlarme.instance.parar();

    final minutos = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Lembrar de novo em...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.texto,
                ),
              ),
            ),
            for (final m in _opcoesAdiar)
              ListTile(
                leading: Icon(Icons.snooze_rounded, color: context.destaque),
                title: Text('$m minutos'),
                onTap: () => Navigator.of(contexto).pop(m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (minutos == null || !mounted) {
      return;
    }

    await NotificationService.instance.adiar(
      widget.alerta,
      Duration(minutes: minutos),
    );

    if (!mounted) {
      return;
    }

    _mensagem('Lembrete adiado por $minutos minutos.');

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alerta;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.gradiente),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, restricoes) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: restricoes.maxHeight - 48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.alarm_rounded,
                              size: 60,
                              color: AppColors.roxo,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Hora do ${a.nome}!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            a.dosagem,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Horário: ${Datas.hora(a.horario.hour, a.horario.minute)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          if (a.medico != null) ...[
                            const SizedBox(height: 20),
                            _CartaoDaReceita(alerta: a),
                          ],
                          const SizedBox(height: 44),
                          ElevatedButton(
                            onPressed: _carregando ? null : _tomarAgora,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.roxo,
                              minimumSize: const Size.fromHeight(60),
                            ),
                            child: _carregando
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('TOMAR AGORA'),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: _carregando ? null : _adiar,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              minimumSize: const Size.fromHeight(56),
                            ),
                            child: const Text('ADIAR'),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: _carregando
                                ? null
                                : () {
                                    SomAlarme.instance.parar();
                                    Navigator.of(context).pop();
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            child: const Text('Agora não'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}


/// "De qual receita é": médico, especialidade e data. É o que diferencia
/// dois medicamentos iguais que tocam no mesmo horário.
class _CartaoDaReceita extends StatelessWidget {
  final AlertaDose alerta;

  const _CartaoDaReceita({required this.alerta});

  @override
  Widget build(BuildContext context) {
    final detalhe = Lembretes.detalheDaReceita(alerta);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receita de',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  alerta.medico!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (detalhe.isNotEmpty)
                  Text(
                    detalhe,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
