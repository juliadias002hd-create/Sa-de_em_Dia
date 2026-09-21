import 'package:flutter/material.dart';

/// Medicamento de uma receita.
class Medicamento {
  final int id;
  final int receitaId;
  final String nome;
  final String dosagem;
  final int intervaloHoras;

  /// Horário inicial como a API envia: "08:00:00".
  final String horarioInicio;
  final int duracaoDias;
  final String? observacoes;
  final bool ativo;

  /// Momento do cadastro (horário do servidor). O tratamento começa a
  /// partir dele; veja `lib/utils/agenda.dart`.
  final DateTime criadoEm;

  const Medicamento({
    required this.id,
    required this.receitaId,
    required this.nome,
    required this.dosagem,
    required this.intervaloHoras,
    required this.horarioInicio,
    required this.duracaoDias,
    required this.ativo,
    required this.criadoEm,
    this.observacoes,
  });

  factory Medicamento.fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: json['id'] as int,
      receitaId: json['receita_id'] as int,
      nome: json['nome'] as String,
      dosagem: json['dosagem'] as String,
      intervaloHoras: json['intervalo_horas'] as int,
      horarioInicio: json['horario_inicio'] as String,
      duracaoDias: json['duracao_dias'] as int,
      observacoes: json['observacoes'] as String?,
      ativo: json['ativo'] as bool,
      criadoEm: DateTime.parse(json['criado_em'] as String),
    );
  }

  /// Horário inicial como TimeOfDay.
  TimeOfDay get horario {
    final partes = horarioInicio.split(':');

    return TimeOfDay(
      hour: int.parse(partes[0]),
      minute: int.parse(partes[1]),
    );
  }

  /// "08:00"
  String get horarioFormatado {
    final h = horario;

    return '${h.hour.toString().padLeft(2, '0')}:'
        '${h.minute.toString().padLeft(2, '0')}';
  }

  /// "8 em 8 horas" / "a cada 1 hora"
  String get intervaloTexto {
    if (intervaloHoras == 1) {
      return 'a cada 1 hora';
    }

    return '$intervaloHoras em $intervaloHoras horas';
  }

  String get duracaoTexto {
    return duracaoDias == 1 ? '1 dia' : '$duracaoDias dias';
  }
}
