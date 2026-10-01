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

  /// Período escolhido: 7, 30 ou `null` (Tudo, desde o medicamento mais
  /// antigo cadastrado).
  int? _periodoDias = 7;
  List<DiaHistorico> _dias = [];
  bool _carregando = true;
  String? _erro;

  /// A API só aceita até 92 dias por pedido; "Tudo" pode passar disso,
  /// então busca em pedaços e junta o resultado.
  static const int _maxDiasPorPedido = 92;

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

    try {
      final medicamentos = await _medicamentos.listar();

      if (!mounted) {
        return;
      }

      final inicio = _calcularInicio(agora, medicamentos);
      final registros = await _buscarRegistros(inicio: inicio, fim: agora);

      if (!mounted) {
        return;
      }

      final dias = Agenda.historico(
        medicamentos: medicamentos,
        registros: registros,
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

  /// Com um período (7/30 dias): esses dias para trás, a partir de hoje.
  /// Com "Tudo": desde o dia em que o medicamento mais antigo foi
  /// cadastrado (ou hoje, se ainda não há nenhum).
  DateTime _calcularInicio(DateTime agora, List<Medicamento> medicamentos) {
    final hoje = DateTime(agora.year, agora.month, agora.day);

    final periodo = _periodoDias;

    if (periodo != null) {
      return hoje.subtract(Duration(days: periodo - 1));
    }

    if (medicamentos.isEmpty) {
      return hoje;
    }

    final maisAntigo = medicamentos
        .map((m) => m.criadoEm)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return DateTime(maisAntigo.year, maisAntigo.month, maisAntigo.day);
  }

  /// Busca os registros de [inicio] a [fim], dividindo em vários pedidos
  /// quando o período passa do limite que a API aceita de uma vez.
  Future<List<RegistroDose>> _buscarRegistros({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final pedidos = <Future<List<RegistroDose>>>[];

    var comeco = inicio;

    while (!comeco.isAfter(fim)) {
      final tetoDoPedaco = comeco.add(const Duration(days: _maxDiasPorPedido - 1));
      final fimDoPedaco = tetoDoPedaco.isAfter(fim) ? fim : tetoDoPedaco;

      pedidos.add(_doses.listar(inicio: comeco, fim: fimDoPedaco));

      comeco = fimDoPedaco.add(const Duration(days: 1));
    }

    final resultados = await Future.wait(pedidos);

    return resultados.expand((lista) => lista).toList();
  }

  void _trocarPeriodo(int? dias) {
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
                  child: SegmentedButton<int?>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 dias')),
                      ButtonSegment(value: 30, label: Text('30 dias')),
                      ButtonSegment(value: null, label: Text('Tudo')),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.texto,
                  ),
                ),
              ),
              Text(
                '${dia.tomadas} de ${dia.itens.length} tomadas',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textoSuave,
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
    final (rotulo, cor) = situacaoDaDose(context, item.status);

    final tomado = item.horarioTomado;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52),
            child: Text(
              Datas.hora(item.horario.hour, item.horario.minute),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.texto,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.texto,
                  ),
                ),
                Text(
                  tomado == null
                      ? item.dosagem
                      : '${item.dosagem} • tomado às ${Datas.hora(tomado.hour, tomado.minute)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textoSuave,
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
