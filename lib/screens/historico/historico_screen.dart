import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/historico.dart';
import '../../models/medicamento.dart';
import '../../services/api_service.dart';
import '../../services/dados_notifier.dart';
import '../../services/dose_service.dart';
import '../../services/medicamentos_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/agenda.dart';
import '../../utils/formatters.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/medicamentos_card.dart';

/// Histórico: o que foi tomado e o que ficou atrasado, dia a dia.
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final _medicamentos = MedicamentoService();
  final _doses = DoseService();

  int _periodoDias = 7;
  List<DiaHistorico> _dias = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();

    DadosApp.versao.addListener(_carregar);

    _carregar();
  }

  @override
  void dispose() {
    DadosApp.versao.removeListener(_carregar);
    super.dispose();
  }

  Future<void> _carregar() async {
    final agora = DateTime.now();
    final inicio = DateTime(agora.year, agora.month, agora.day - (_periodoDias - 1));

    try {
      final resultados = await Future.wait<Object>([
        _medicamentos.listar(),
        _doses.listar(inicio: inicio, fim: agora),
      ]);

      if (!mounted) {
        return;
      }

      final dias = Agenda.historico(
        medicamentos: resultados[0] as List<Medicamento>,
        registros: resultados[1] as List<RegistroDose>,
        inicio: inicio,
        fim: agora,
        agora: agora,
      );

      setState(() {
        _dias = dias;
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

  void _trocarPeriodo(int dias) {
    setState(() {
      _periodoDias = dias;
      _carregando = true;
    });

    _carregar();
  }

  String _titulo(DateTime dia) {
    final hoje = DateTime.now();
    final hojeDia = DateTime(hoje.year, hoje.month, hoje.day);
    final diferenca = hojeDia.difference(dia).inDays;

    final data = Datas.paraBr(dia);

    if (diferenca == 0) {
      return 'Hoje • $data';
    }

    if (diferenca == 1) {
      return 'Ontem • $data';
    }

    final semana = DateFormat('EEEE', 'pt_BR').format(dia);

    return '${semana[0].toUpperCase()}${semana.substring(1)} • $data';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 dias')),
                      ButtonSegment(value: 30, label: Text('30 dias')),
                    ],
                    selected: {_periodoDias},
                    onSelectionChanged: (s) => _trocarPeriodo(s.first),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _corpo()),
        ],
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
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

    if (_dias.isEmpty) {
      return const EstadoVazio(
        icone: Icons.history_rounded,
        titulo: 'Nada por aqui ainda',
        mensagem:
            'Quando você tomar seus medicamentos e marcar como tomados, o histórico aparece aqui.',
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _dias.length,
        itemBuilder: (_, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _SecaoDia(
              titulo: _titulo(_dias[i].dia),
              dia: _dias[i],
            ),
          ),
        ),
      ),
    );
  }
}


class _SecaoDia extends StatelessWidget {
  final String titulo;
  final DiaHistorico dia;

  const _SecaoDia({required this.titulo, required this.dia});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texto,
                  ),
                ),
              ),
              Text(
                '${dia.tomadas} de ${dia.itens.length} tomadas',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textoSuave,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < dia.itens.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _Linha(item: dia.itens[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _Linha extends StatelessWidget {
  final ItemHistorico item;

  const _Linha({required this.item});

  @override
  Widget build(BuildContext context) {
    final (rotulo, cor) = situacaoDaDose(item.status);

    final tomado = item.horarioTomado;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              Datas.hora(item.horario.hour, item.horario.minute),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.texto,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
                Text(
                  tomado == null
                      ? item.dosagem
                      : '${item.dosagem} • tomado às ${Datas.hora(tomado.hour, tomado.minute)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textoSuave,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
