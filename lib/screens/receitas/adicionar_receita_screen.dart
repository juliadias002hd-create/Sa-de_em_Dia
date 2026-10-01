import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/receita.dart';
import '../../services/api_service.dart';
import '../../services/dados_notifier.dart';
import '../../services/file_service.dart';
import '../../services/image_service.dart';
import '../../services/receita_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'detalhe_receita_screen.dart';

/// Cadastra (ou edita) uma receita: foto/galeria/PDF + data, médico e
/// especialidade.
///
/// Sem [receita]: cadastro novo. Com [receita]: edição dela.
class AdicionarReceitaScreen extends StatefulWidget {
  final Receita? receita;

  const AdicionarReceitaScreen({super.key, this.receita});

  @override
  State<AdicionarReceitaScreen> createState() => _AdicionarReceitaScreenState();
}

class _AdicionarReceitaScreenState extends State<AdicionarReceitaScreen> {
  static const int _limiteBytes = 10 * 1024 * 1024;

  final _formulario = GlobalKey<FormState>();
  final _imagens = ImageService();
  final _arquivos = FileService();
  final _servico = ReceitaService();

  final _dataController = TextEditingController();
  final _medicoController = TextEditingController();
  final _especialidadeController = TextEditingController();

  /// Um arquivo novo, escolhido agora (substitui o atual, se houver).
  ArquivoParaEnvio? _arquivo;
  bool _ehPdf = false;

  /// A pessoa pediu para remover o arquivo atual (sem escolher outro).
  bool _removerArquivoAtual = false;

  /// Bytes do arquivo atual da receita, carregados para a prévia.
  Future<Uint8List>? _imagemAtual;

  bool _carregando = false;

  bool get _editando => widget.receita != null;

  /// Há um arquivo (novo ou o atual) que vai ficar valendo ao salvar.
  bool get _temArquivo => _arquivo != null || (_mostrarArquivoAtual);

  bool get _mostrarArquivoAtual =>
      _editando &&
      !_removerArquivoAtual &&
      _arquivo == null &&
      widget.receita!.temArquivo;

  @override
  void initState() {
    super.initState();

    final r = widget.receita;

    if (r != null) {
      _dataController.text = Datas.paraBr(r.dataReceita);
      _medicoController.text = r.medico;
      _especialidadeController.text = r.especialidade;

      if (r.ehImagem) {
        _imagemAtual = _servico.baixarArquivo(r.id);
      }
    } else {
      // A receita costuma ser de hoje; o usuário pode trocar.
      _dataController.text = Datas.paraBr(DateTime.now());
    }
  }

  @override
  void dispose() {
    _dataController.dispose();
    _medicoController.dispose();
    _especialidadeController.dispose();
    super.dispose();
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _escolher(
    Future<ArquivoParaEnvio?> Function() escolha, {
    required bool pdf,
  }) async {
    try {
      final resultado = await escolha();

      if (resultado == null) {
        return;
      }

      if (resultado.bytes.length > _limiteBytes) {
        _mostrarMensagem('O arquivo é grande demais. O limite é 10 MB.');
        return;
      }

      setState(() {
        _arquivo = resultado;
        _ehPdf = pdf;
        _removerArquivoAtual = false;
      });
    } catch (_) {
      _mostrarMensagem(
        'Não foi possível acessar a câmera ou os arquivos. Verifique as permissões do aplicativo.',
      );
    }
  }

  void _removerArquivo() {
    setState(() {
      _arquivo = null;
      _removerArquivoAtual = true;
    });
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();

    final escolhida = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: DateTime(2000),
      lastDate: agora,
      helpText: 'Data da receita',
    );

    if (escolhida != null) {
      _dataController.text = Datas.paraBr(escolhida);
    }
  }

  Future<bool> _confirmarSemArquivo() async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Salvar sem foto ou PDF?'),
        content: const Text(
          'Guardar a imagem da receita ajuda a consultá-la depois. '
          'Você pode salvar assim mesmo, se preferir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('VOLTAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('SALVAR ASSIM'),
          ),
        ],
      ),
    );

    return resposta == true;
  }

  Future<void> _confirmar() async {
    if (!_formulario.currentState!.validate()) {
      return;
    }

    if (!_temArquivo && !await _confirmarSemArquivo()) {
      return;
    }

    setState(() => _carregando = true);

    try {
      final dataIso = Datas.brParaIso(_dataController.text.trim())!;
      final medico = _medicoController.text.trim();
      final especialidade = _especialidadeController.text.trim();

      if (_editando) {
        await _servico.atualizar(
          id: widget.receita!.id,
          dataReceitaIso: dataIso,
          medico: medico,
          especialidade: especialidade,
          arquivo: _arquivo,
          removerArquivo: _removerArquivoAtual,
        );

        DadosApp.mudou();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receita atualizada com sucesso!')),
        );

        // O detalhe da receita (tela anterior) recarrega sozinho.
        Navigator.of(context).pop(true);
        return;
      }

      final receita = await _servico.criar(
        dataReceitaIso: dataIso,
        medico: medico,
        especialidade: especialidade,
        arquivo: _arquivo,
      );

      DadosApp.mudou();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receita salva com sucesso!')),
      );

      // Segue para a receita, onde já dá para adicionar os medicamentos.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DetalheReceitaScreen(
            receitaId: receita.id,
            abrirCadastroDeMedicamento: true,
          ),
        ),
      );
    } on ApiException catch (e) {
      _mostrarMensagem(e.mensagem);
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Receita' : 'Adicionar Receita'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Previa(
                      arquivo: _arquivo,
                      ehPdf: _ehPdf,
                      mostrarArquivoAtual: _mostrarArquivoAtual,
                      nomeArquivoAtual: widget.receita?.nomeArquivo,
                      ehPdfAtual: widget.receita?.ehPdf ?? false,
                      imagemAtual: _imagemAtual,
                    ),
                    if (_temArquivo) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _carregando ? null : _removerArquivo,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Remover arquivo'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.perigo,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    AppButton(
                      texto: 'TIRAR FOTO',
                      icone: Icons.camera_alt_rounded,
                      onPressed: _carregando
                          ? null
                          : () => _escolher(_imagens.tirarFoto, pdf: false),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      texto: 'ESCOLHER DA GALERIA',
                      icone: Icons.photo_library_rounded,
                      secundario: true,
                      onPressed: _carregando
                          ? null
                          : () => _escolher(
                                _imagens.escolherDaGaleria,
                                pdf: false,
                              ),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      texto: 'SELECIONAR PDF',
                      icone: Icons.picture_as_pdf_rounded,
                      secundario: true,
                      onPressed: _carregando
                          ? null
                          : () => _escolher(_arquivos.selecionarPdf, pdf: true),
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _dataController,
                      rotulo: 'Data da receita',
                      dica: 'dd/mm/aaaa',
                      icone: Icons.calendar_today_rounded,
                      teclado: TextInputType.number,
                      acaoTeclado: TextInputAction.next,
                      formatadores: [DataInputFormatter()],
                      validador: Validators.data(
                        naoFutura: true,
                        mensagemVazio: 'Informe a data da receita.',
                      ),
                      desativado: _carregando,
                      sufixo: IconButton(
                        tooltip: 'Escolher no calendário',
                        icon: const Icon(Icons.calendar_month_rounded),
                        onPressed: _carregando ? null : _escolherData,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _medicoController,
                      rotulo: 'Médico',
                      dica: 'Ex.: Dr. João da Silva',
                      icone: Icons.person_outline_rounded,
                      capitalizacao: TextCapitalization.words,
                      acaoTeclado: TextInputAction.next,
                      limiteCaracteres: 150,
                      validador: (v) {
                        final t = (v ?? '').trim();

                        if (t.isEmpty) {
                          return 'Informe o nome do médico.';
                        }

                        return t.length < 2 ? 'Informe um nome válido.' : null;
                      },
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _especialidadeController,
                      rotulo: 'Especialidade',
                      dica: 'Ex.: Clínico Geral',
                      icone: Icons.medical_services_outlined,
                      capitalizacao: TextCapitalization.words,
                      acaoTeclado: TextInputAction.done,
                      limiteCaracteres: 100,
                      validador: (v) {
                        final t = (v ?? '').trim();

                        if (t.isEmpty) {
                          return 'Informe a especialidade.';
                        }

                        return t.length < 2 ? 'Informe uma especialidade válida.' : null;
                      },
                      aoEnviar: (_) => _confirmar(),
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      texto: _editando ? 'SALVAR' : 'CONFIRMAR',
                      carregando: _carregando,
                      onPressed: _confirmar,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Mostra a foto escolhida agora, o arquivo já salvo na receita (ao
/// editar), o nome do PDF ou um espaço vazio.
class _Previa extends StatelessWidget {
  final ArquivoParaEnvio? arquivo;
  final bool ehPdf;

  final bool mostrarArquivoAtual;
  final String? nomeArquivoAtual;
  final bool ehPdfAtual;
  final Future<Uint8List>? imagemAtual;

  const _Previa({
    required this.arquivo,
    required this.ehPdf,
    required this.mostrarArquivoAtual,
    required this.nomeArquivoAtual,
    required this.ehPdfAtual,
    required this.imagemAtual,
  });

  @override
  Widget build(BuildContext context) {
    if (arquivo != null && !ehPdf) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 260,
          color: context.cartao,
          child: Image.memory(arquivo!.bytes, fit: BoxFit.contain),
        ),
      );
    }

    if (arquivo == null && mostrarArquivoAtual) {
      if (ehPdfAtual) {
        return _vazio(context, icone: Icons.picture_as_pdf_rounded, texto: nomeArquivoAtual);
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 260,
          color: context.cartao,
          child: FutureBuilder<Uint8List>(
            future: imagemAtual,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.memory(snapshot.data!, fit: BoxFit.contain);
              }

              if (snapshot.hasError) {
                return Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: context.textoSuave,
                  ),
                );
              }

              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      );
    }

    return _vazio(
      context,
      icone: arquivo != null ? Icons.picture_as_pdf_rounded : Icons.receipt_long_rounded,
      texto: arquivo?.nome ?? 'Nenhuma receita selecionada',
    );
  }

  Widget _vazio(BuildContext context, {required IconData icone, String? texto}) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: context.cartao,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.bordaCampo),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 64, color: AppColors.roxo),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              texto ?? 'Nenhuma receita selecionada',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textoSuave),
            ),
          ),
        ],
      ),
    );
  }
}
