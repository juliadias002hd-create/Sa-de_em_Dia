import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/medicamento.dart';
import '../../models/receita.dart';
import '../../services/api_service.dart';
import '../../services/dados_notifier.dart';
import '../../services/medicamentos_service.dart';
import '../../services/receita_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/medicamentos_card.dart';
import '../medicamentos/cadastrar_medicamento_screen.dart';

/// Uma receita com o arquivo anexado e os medicamentos dela.
class DetalheReceitaScreen extends StatefulWidget {
  final int receitaId;

  /// Logo depois de cadastrar a receita, já abre a tela para adicionar
  /// o primeiro medicamento.
  final bool abrirCadastroDeMedicamento;

  const DetalheReceitaScreen({
    super.key,
    required this.receitaId,
    this.abrirCadastroDeMedicamento = false,
  });

  @override
  State<DetalheReceitaScreen> createState() => _DetalheReceitaScreenState();
}

class _DetalheReceitaScreenState extends State<DetalheReceitaScreen> {
  final _receitas = ReceitaService();
  final _medicamentos = MedicamentoService();

  Receita? _receita;
  Future<Uint8List>? _imagem;
  bool _carregando = true;
  String? _erro;
  bool _jaAbriuCadastro = false;

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
      final receita = await _receitas.buscar(widget.receitaId);

      if (!mounted) {
        return;
      }

      setState(() {
        // A imagem só é baixada de novo se ainda não foi.
        if (receita.ehImagem && _imagem == null) {
          _imagem = _receitas.baixarArquivo(receita.id);
        }

        _receita = receita;
        _erro = null;
        _carregando = false;
      });

      if (widget.abrirCadastroDeMedicamento &&
          !_jaAbriuCadastro &&
          receita.medicamentos.isEmpty) {
        _jaAbriuCadastro = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _adicionarMedicamento();
          }
        });
      }
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

  void _mostrarMensagem(String texto) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensagem,
    required String rotuloConfirmar,
  }) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.perigo),
            child: Text(rotuloConfirmar),
          ),
        ],
      ),
    );

    return resposta == true;
  }

  Future<void> _adicionarMedicamento() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CadastrarMedicamentoScreen(receitaId: widget.receitaId),
      ),
    );
  }

  Future<void> _excluirReceita() async {
    final confirmou = await _confirmar(
      titulo: 'Excluir esta receita?',
      mensagem:
          'A receita, o arquivo anexado e todos os medicamentos dela serão excluídos. Essa ação não pode ser desfeita.',
      rotuloConfirmar: 'EXCLUIR',
    );

    if (!confirmou) {
      return;
    }

    try {
      await _receitas.excluir(widget.receitaId);

      DadosApp.mudou();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receita excluída com sucesso!')),
      );

      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _mostrarMensagem(e.mensagem);
    }
  }

  Future<void> _acaoMedicamento(Medicamento m, AcaoMedicamento acao) async {
    switch (acao) {
      case AcaoMedicamento.editar:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CadastrarMedicamentoScreen(
              receitaId: widget.receitaId,
              medicamento: m,
            ),
          ),
        );

      case AcaoMedicamento.alternarAtivo:
        try {
          await _medicamentos.atualizar(
            id: m.id,
            nome: m.nome,
            dosagem: m.dosagem,
            intervaloHoras: m.intervaloHoras,
            horarioInicio: m.horarioFormatado,
            duracaoDias: m.duracaoDias,
            observacoes: m.observacoes,
            ativo: !m.ativo,
          );

          DadosApp.mudou();

          _mostrarMensagem(
            m.ativo ? 'Medicamento pausado.' : 'Medicamento reativado.',
          );
        } on ApiException catch (e) {
          _mostrarMensagem(e.mensagem);
        }

      case AcaoMedicamento.excluir:
        final confirmou = await _confirmar(
          titulo: 'Excluir ${m.nome}?',
          mensagem: 'Os lembretes deste medicamento também serão removidos.',
          rotuloConfirmar: 'EXCLUIR',
        );

        if (!confirmou) {
          return;
        }

        try {
          await _medicamentos.excluir(m.id);

          DadosApp.mudou();

          _mostrarMensagem('Medicamento excluído com sucesso!');
        } on ApiException catch (e) {
          _mostrarMensagem(e.mensagem);
        }
    }
  }

  void _ampliarImagem(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (contexto) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image.memory(bytes)),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Fechar',
                  color: Colors.white,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(contexto).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receita'),
        actions: [
          if (_receita != null)
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (_) => _excluirReceita(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'excluir', child: Text('Excluir receita')),
              ],
            ),
        ],
      ),
      floatingActionButton: _receita == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _adicionarMedicamento,
              backgroundColor: AppColors.roxo,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Medicamento'),
            ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null || _receita == null) {
      return ErroCarregamento(
        mensagem: _erro ?? 'Não foi possível carregar a receita.',
        aoTentarNovamente: () {
          setState(() => _carregando = true);
          _carregar();
        },
      );
    }

    final receita = _receita!;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DadosReceita(receita: receita),
                  if (receita.temArquivo) ...[
                    const SizedBox(height: 16),
                    _Arquivo(
                      receita: receita,
                      imagem: _imagem,
                      aoAmpliar: _ampliarImagem,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Medicamentos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.texto,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (receita.medicamentos.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.medication_liquid_rounded,
                              size: 40,
                              color: context.textoSuave,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Nenhum medicamento nesta receita.\nToque em "Medicamento" para adicionar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.textoSuave),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final m in receita.medicamentos) ...[
                      MedicamentoCard(
                        medicamento: m,
                        aoEscolherAcao: (acao) => _acaoMedicamento(m, acao),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DadosReceita extends StatelessWidget {
  final Receita receita;

  const _DadosReceita({required this.receita});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradiente,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receita.medico,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            receita.especialidade,
            style: const TextStyle(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                Datas.paraBr(receita.dataReceita),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _Arquivo extends StatelessWidget {
  final Receita receita;
  final Future<Uint8List>? imagem;
  final void Function(Uint8List bytes) aoAmpliar;

  const _Arquivo({
    required this.receita,
    required this.imagem,
    required this.aoAmpliar,
  });

  @override
  Widget build(BuildContext context) {
    if (receita.ehImagem && imagem != null) {
      return FutureBuilder<Uint8List>(
        future: imagem,
        builder: (context, retorno) {
          if (retorno.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (retorno.hasError || retorno.data == null) {
            return const _AvisoArquivo(
              icone: Icons.broken_image_outlined,
              texto: 'Não foi possível carregar a imagem da receita.',
            );
          }

          final bytes = retorno.data!;

          return GestureDetector(
            onTap: () => aoAmpliar(bytes),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Container(
                    height: 240,
                    width: double.infinity,
                    color: context.cartao,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return _AvisoArquivo(
      icone: Icons.picture_as_pdf_rounded,
      texto: 'PDF anexado: ${receita.nomeArquivo ?? 'receita.pdf'}',
    );
  }
}


class _AvisoArquivo extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _AvisoArquivo({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icone, color: context.destaque, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(color: context.texto),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
