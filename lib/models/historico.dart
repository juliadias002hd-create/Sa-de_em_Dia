/// Uma dose que o paciente marcou como tomada.
class RegistroDose {
  final int id;
  final int medicamentoId;
  final String medicamentoNome;
  final String medicamentoDosagem;

  /// Horário em que a dose estava programada.
  final DateTime horarioPrevisto;

  /// Horário em que o paciente realmente tomou.
  final DateTime horarioTomado;

  const RegistroDose({
    required this.id,
    required this.medicamentoId,
    required this.medicamentoNome,
    required this.medicamentoDosagem,
    required this.horarioPrevisto,
    required this.horarioTomado,
  });

  factory RegistroDose.fromJson(Map<String, dynamic> json) {
    return RegistroDose(
      id: json['id'] as int,
      medicamentoId: json['medicamento_id'] as int,
      medicamentoNome: json['medicamento_nome'] as String,
      medicamentoDosagem: json['medicamento_dosagem'] as String,
      horarioPrevisto: DateTime.parse(json['horario_previsto'] as String),
      horarioTomado: DateTime.parse(json['horario_tomado'] as String),
    );
  }
}
