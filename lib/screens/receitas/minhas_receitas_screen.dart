import 'package:flutter/material.dart';

import '../../models/receita.dart';
import '../../services/api_service.dart';
import '../../services/dados_notifier.dart';
import '../../services/receita_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/estado_vazio.dart';
import 'adicionar_receita_screen.dart';
import 'detalhe_receita_screen.dart';

/// Aba "Minhas Receitas": lista das receitas do paciente.
class MinhasReceitasScreen extends StatefulWidget {
  const MinhasReceitasScreen({super.key});

  @override
  State<MinhasReceitasScreen> createState() => _MinhasReceitasScreenState();
}

class _MinhasReceitasScreenState extends State<MinhasReceitasScreen> {
  final _servico = ReceitaService();

  List<Receita> _receitas = [];
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
    try {
      final lista = await _servico.listar();

      if (!mounted) {
        return;
      }

      setState(() {
        _receitas = lista;
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

  void _adicionar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdicionarReceitaScreen()),
    );
  }

  void _abrir(Receita receita) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalheReceitaScreen(receitaId: receita.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Receitas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionar,
        backgroundColor: AppColors.roxo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova receita'),
      ),
      body: _corpo(),
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

    if (_receitas.isEmpty) {
      return EstadoVazio(
        icone: Icons.receipt_long_rounded,
        titulo: 'Nenhuma receita ainda',
        mensagem:
            'Tire uma foto da sua receita e cadastre os medicamentos para receber lembretes.',
        acao: ElevatedButton.icon(
          onPressed: _adicionar,
          icon: const Icon(Icons.add_rounded),
          label: const Text('ADICIONAR RECEITA'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(240, 52)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: _receitas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _ReceitaCard(
              receita: _receitas[i],
              aoTocar: () => _abrir(_receitas[i]),
            ),
          ),
        ),
      ),
    );
  }
}


class _ReceitaCard extends StatelessWidget {
  final Receita receita;
  final VoidCallback aoTocar;

  const _ReceitaCard({required this.receita, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final total = receita.totalMedicamentos ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.roxo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  receita.ehPdf
                      ? Icons.picture_as_pdf_rounded
                      : receita.ehImagem
                          ? Icons.image_rounded
                          : Icons.receipt_long_rounded,
                  color: AppColors.roxo,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receita.medico,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      receita.especialidade,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textoSuave),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppColors.textoSuave,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Datas.paraBr(receita.dataReceita),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textoSuave,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.medication_outlined,
                          size: 14,
                          color: AppColors.textoSuave,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          total == 1 ? '1 medicamento' : '$total medicamentos',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textoSuave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
