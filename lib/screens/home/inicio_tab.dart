import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/medicamento.dart';
import '../../services/api_service.dart';
import '../../services/dados_notifier.dart';
import '../../services/medicamentos_service.dart';
import '../../services/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/agenda.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/medicamentos_card.dart';

/// Aba inicial: saudação e os medicamentos que o paciente deve tomar hoje.
class InicioTab extends StatefulWidget {
  const InicioTab({super.key});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  final _servico = MedicamentoService();

  List<Medicamento> _medicamentos = [];
  bool _carregando = true;
  String? _erro;

  Timer? _relogio;

  @override
  void initState() {
    super.initState();

    DadosApp.versao.addListener(_carregar);

    _carregar();

    // Atualiza a cada minuto para que "A tomar" vire "Atrasado" na hora certa.
    _relogio = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    DadosApp.versao.removeListener(_carregar);
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await _servico.listar(somenteAtivos: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _medicamentos = lista;
        _erro = null;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    }
  }

  String _dataPorExtenso() {
    final texto = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = SessionController.instance.usuario;
    final agora = DateTime.now();
    final doses = Agenda.dosesDoDia(_medicamentos, agora);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _Cabecalho(
              nome: usuario?.primeiroNome ?? '',
              data: _dataPorExtenso(),
              totalDoses: _carregando || _erro != null ? null : doses.length,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: _conteudo(doses, agora),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(List<DoseAgendada> doses, DateTime agora) {
    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_erro != null) {
      return ErroCarregamento(
        mensagem: _erro!,
        aoTentarNovamente: () {
          setState(() => _carregando = true);
          _carregar();
        },
      );
    }

    if (_medicamentos.isEmpty) {
      return const EstadoVazio(
        icone: Icons.medication_liquid_rounded,
        titulo: 'Nenhum medicamento ainda',
        mensagem:
            'Cadastre uma receita na aba "Receitas" e adicione seus medicamentos para receber os lembretes.',
      );
    }

    if (doses.isEmpty) {
      return const EstadoVazio(
        icone: Icons.check_circle_outline_rounded,
        titulo: 'Nada para tomar hoje',
        mensagem: 'Você não tem doses programadas para hoje. Bom descanso!',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Medicamentos de hoje',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.texto,
          ),
        ),
        const SizedBox(height: 14),
        for (final dose in doses) ...[
          DoseCard(
            dose: dose,
            status: Agenda.status(dose.horario, agora),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}


class _Cabecalho extends StatelessWidget {
  final String nome;
  final String data;
  final int? totalDoses;

  const _Cabecalho({
    required this.nome,
    required this.data,
    required this.totalDoses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.gradiente,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Olá, $nome!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (totalDoses != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        totalDoses == 0
                            ? 'Nenhuma dose hoje'
                            : totalDoses == 1
                                ? '1 dose hoje'
                                : '$totalDoses doses hoje',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
