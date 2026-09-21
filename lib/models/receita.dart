import 'medicamento.dart';

/// Receita médica de um paciente.
///
/// O médico NÃO é um usuário do app: aqui ele é só um dado da receita.
class Receita {
  final int id;

  /// Data da receita como DateTime (sem hora).
  final DateTime dataReceita;
  final String medico;
  final String especialidade;
  final bool temArquivo;

  /// Endereço (na API) para baixar o arquivo. Exige login.
  final String? arquivoUrl;

  /// "imagem" ou "pdf".
  final String? tipoArquivo;
  final String? nomeArquivo;

  /// Só vem na listagem.
  final int? totalMedicamentos;

  /// Só vem no detalhe da receita.
  final List<Medicamento> medicamentos;

  const Receita({
    required this.id,
    required this.dataReceita,
    required this.medico,
    required this.especialidade,
    required this.temArquivo,
    this.arquivoUrl,
    this.tipoArquivo,
    this.nomeArquivo,
    this.totalMedicamentos,
    this.medicamentos = const [],
  });

  factory Receita.fromJson(Map<String, dynamic> json) {
    final lista = json['medicamentos'] as List<dynamic>?;

    return Receita(
      id: json['id'] as int,
      dataReceita: DateTime.parse(json['data_receita'] as String),
      medico: json['medico'] as String,
      especialidade: json['especialidade'] as String,
      temArquivo: json['tem_arquivo'] as bool,
      arquivoUrl: json['arquivo_url'] as String?,
      tipoArquivo: json['tipo_arquivo'] as String?,
      nomeArquivo: json['nome_arquivo'] as String?,
      totalMedicamentos: json['total_medicamentos'] as int?,
      medicamentos: lista == null
          ? const []
          : lista
              .map((m) => Medicamento.fromJson(m as Map<String, dynamic>))
              .toList(),
    );
  }

  bool get ehPdf => tipoArquivo == 'pdf';

  bool get ehImagem => tipoArquivo == 'imagem';
}
