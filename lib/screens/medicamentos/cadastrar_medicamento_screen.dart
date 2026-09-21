import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/medicamento.dart';
import '../../services/api_service.dart';
import '../../services/dados_notifier.dart';
import '../../services/medicamentos_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Cadastra (ou edita) um medicamento de uma receita.
///
/// Sem [medicamento]: cadastro novo na receita [receitaId].
/// Com [medicamento]: edição dele.
class CadastrarMedicamentoScreen extends StatefulWidget {
  final int receitaId;
  final Medicamento? medicamento;

  const CadastrarMedicamentoScreen({
    super.key,
    required this.receitaId,
    this.medicamento,
  });

  @override
  State<CadastrarMedicamentoScreen> createState() =>
      _CadastrarMedicamentoScreenState();
}

class _CadastrarMedicamentoScreenState
    extends State<CadastrarMedicamentoScreen> {
  final _formulario = GlobalKey<FormState>();
  final _servico = MedicamentoService();

  final _nomeController = TextEditingController();
  final _dosagemController = TextEditingController();
  final _intervaloController = TextEditingController();
  final _duracaoController = TextEditingController();
  final _horarioController = TextEditingController();
  final _observacoesController = TextEditingController();

  TimeOfDay _horario = const TimeOfDay(hour: 8, minute: 0);
  bool _carregando = false;

  bool get _editando => widget.medicamento != null;

  @override
  void initState() {
    super.initState();

    final m = widget.medicamento;

    if (m != null) {
      _nomeController.text = m.nome;
      _dosagemController.text = m.dosagem;
      _intervaloController.text = m.intervaloHoras.toString();
      _duracaoController.text = m.duracaoDias.toString();
      _observacoesController.text = m.observacoes ?? '';
      _horario = m.horario;
    }

    _horarioController.text = _formatar(_horario);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _dosagemController.dispose();
    _intervaloController.dispose();
    _duracaoController.dispose();
    _horarioController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  String _formatar(TimeOfDay h) => Datas.hora(h.hour, h.minute);

  void _mostrarMensagem(String texto) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _escolherHorario() async {
    final escolhido = await showTimePicker(
      context: context,
      initialTime: _horario,
      helpText: 'Horário da primeira dose',
      builder: (contexto, filho) {
        // Relógio de 24 horas, como no dia a dia do medicamento.
        return MediaQuery(
          data: MediaQuery.of(contexto).copyWith(alwaysUse24HourFormat: true),
          child: filho!,
        );
      },
    );

    if (escolhido != null) {
      setState(() {
        _horario = escolhido;
        _horarioController.text = _formatar(escolhido);
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formulario.currentState!.validate()) {
      return;
    }

    setState(() => _carregando = true);

    final observacoes = _observacoesController.text.trim();

    try {
      if (_editando) {
        await _servico.atualizar(
          id: widget.medicamento!.id,
          nome: _nomeController.text.trim(),
          dosagem: _dosagemController.text.trim(),
          intervaloHoras: int.parse(_intervaloController.text.trim()),
          horarioInicio: _formatar(_horario),
          duracaoDias: int.parse(_duracaoController.text.trim()),
          observacoes: observacoes.isEmpty ? null : observacoes,
        );
      } else {
        await _servico.criar(
          receitaId: widget.receitaId,
          nome: _nomeController.text.trim(),
          dosagem: _dosagemController.text.trim(),
          intervaloHoras: int.parse(_intervaloController.text.trim()),
          horarioInicio: _formatar(_horario),
          duracaoDias: int.parse(_duracaoController.text.trim()),
          observacoes: observacoes.isEmpty ? null : observacoes,
        );
      }

      DadosApp.mudou();

      if (!mounted) {
        return;
      }

      // O aviso aparece na tela anterior (o Scaffold da receita).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editando
                ? 'Medicamento atualizado com sucesso!'
                : 'Medicamento cadastrado com sucesso!',
          ),
        ),
      );

      Navigator.of(context).pop(true);
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
        title: Text(_editando ? 'Editar medicamento' : 'Adicionar Medicamento'),
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
                    AppTextField(
                      controller: _nomeController,
                      rotulo: 'Nome do medicamento',
                      dica: 'Ex.: Paracetamol',
                      icone: Icons.medication_rounded,
                      capitalizacao: TextCapitalization.sentences,
                      acaoTeclado: TextInputAction.next,
                      limiteCaracteres: 150,
                      validador: (v) {
                        final t = (v ?? '').trim();

                        if (t.isEmpty) {
                          return 'Informe o nome do medicamento.';
                        }

                        return t.length < 2 ? 'Informe um nome válido.' : null;
                      },
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _dosagemController,
                      rotulo: 'Dosagem',
                      dica: 'Ex.: 500 mg',
                      icone: Icons.science_outlined,
                      acaoTeclado: TextInputAction.next,
                      limiteCaracteres: 50,
                      validador: (v) =>
                          Validators.obrigatorio(v, 'Informe a dosagem.'),
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _intervaloController,
                      rotulo: 'Intervalo (em horas)',
                      dica: 'Ex.: 8  →  de 8 em 8 horas',
                      icone: Icons.repeat_rounded,
                      teclado: TextInputType.number,
                      acaoTeclado: TextInputAction.next,
                      formatadores: [FilteringTextInputFormatter.digitsOnly],
                      validador: Validators.inteiro(
                        campo: 'o intervalo em horas',
                        minimo: 1,
                        maximo: 168,
                      ),
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _duracaoController,
                      rotulo: 'Duração (em dias)',
                      dica: 'Ex.: 5',
                      icone: Icons.event_rounded,
                      teclado: TextInputType.number,
                      acaoTeclado: TextInputAction.next,
                      formatadores: [FilteringTextInputFormatter.digitsOnly],
                      validador: Validators.inteiro(
                        campo: 'a duração em dias',
                        minimo: 1,
                        maximo: 730,
                      ),
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _horarioController,
                      rotulo: 'Horário inicial',
                      icone: Icons.schedule_rounded,
                      somenteLeitura: true,
                      aoTocar: _carregando ? null : _escolherHorario,
                      desativado: _carregando,
                      sufixo: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _observacoesController,
                      rotulo: 'Observações (opcional)',
                      dica: 'Ex.: Tomar após as refeições',
                      icone: Icons.notes_rounded,
                      linhasMaximas: 3,
                      limiteCaracteres: 255,
                      capitalizacao: TextCapitalization.sentences,
                      desativado: _carregando,
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      texto: _editando ? 'SALVAR ALTERAÇÕES' : 'SALVAR MEDICAMENTO',
                      carregando: _carregando,
                      onPressed: _salvar,
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
