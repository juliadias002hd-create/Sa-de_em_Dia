import 'package:flutter/material.dart';

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

/// Cadastro de uma receita: foto/galeria/PDF + data, médico e especialidade.
class AdicionarReceitaScreen extends StatefulWidget {
  const AdicionarReceitaScreen({super.key});

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

  ArquivoParaEnvio? _arquivo;
  bool _ehPdf = false;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();

    // A receita costuma ser de hoje; o usuário pode trocar.
    _dataController.text = Datas.paraBr(DateTime.now());
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
      });
    } catch (_) {
      _mostrarMensagem(
        'Não foi possível acessar a câmera ou os arquivos. Verifique as permissões do aplicativo.',
      );
    }
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

    if (_arquivo == null && !await _confirmarSemArquivo()) {
      return;
    }

    setState(() => _carregando = true);

    try {
      final receita = await _servico.criar(
        dataReceitaIso: Datas.brParaIso(_dataController.text.trim())!,
        medico: _medicoController.text.trim(),
        especialidade: _especialidadeController.text.trim(),
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
      appBar: AppBar(title: const Text('Adicionar Receita')),
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
                    _Previa(arquivo: _arquivo, ehPdf: _ehPdf),
                    const SizedBox(height: 16),
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
                      texto: 'CONFIRMAR',
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


/// Mostra a foto escolhida, o nome do PDF ou um espaço vazio.
class _Previa extends StatelessWidget {
  final ArquivoParaEnvio? arquivo;
  final bool ehPdf;

  const _Previa({required this.arquivo, required this.ehPdf});

  @override
  Widget build(BuildContext context) {
    if (arquivo != null && !ehPdf) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 260,
          color: Colors.white,
          child: Image.memory(arquivo!.bytes, fit: BoxFit.contain),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCD6EE)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            arquivo != null ? Icons.picture_as_pdf_rounded : Icons.receipt_long_rounded,
            size: 64,
            color: AppColors.roxo,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              arquivo?.nome ?? 'Nenhuma receita selecionada',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textoSuave),
            ),
          ),
        ],
      ),
    );
  }
}
