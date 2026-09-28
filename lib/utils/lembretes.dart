import 'dart:convert';

import '../models/medicamento.dart';
import 'agenda.dart';
import 'formatters.dart';

/// Os dados de uma dose que "toca" (viajam dentro da notificação).
class AlertaDose {
  final int medicamentoId;
  final String nome;
  final String dosagem;

  /// Horário programado da dose (não muda se o lembrete for adiado).
  final DateTime horario;

  /// De qual receita é o medicamento. Serve para diferenciar dois
  /// medicamentos iguais, de receitas ou médicos diferentes, que tocam
  /// no mesmo horário.
  final String? medico;
  final String? especialidade;
  final DateTime? dataReceita;

  /// Número da notificação que está tocando para esta dose (quando o
  /// alerta veio de uma notificação). Serve para silenciar o alarme.
  final int? notificacaoId;

  const AlertaDose({
    required this.medicamentoId,
    required this.nome,
    required this.dosagem,
    required this.horario,
    this.medico,
    this.especialidade,
    this.dataReceita,
    this.notificacaoId,
  });

  /// A dose de um medicamento em um horário.
  factory AlertaDose.deMedicamento(Medicamento m, DateTime horario) {
    return AlertaDose(
      medicamentoId: m.id,
      nome: m.nome,
      dosagem: m.dosagem,
      horario: horario,
      medico: m.medico,
      especialidade: m.especialidade,
      dataReceita: m.dataReceita,
    );
  }

  /// Mesma dose, agora sabendo qual notificação a disparou.
  AlertaDose comNotificacao(int? id) {
    return AlertaDose(
      medicamentoId: medicamentoId,
      nome: nome,
      dosagem: dosagem,
      horario: horario,
      medico: medico,
      especialidade: especialidade,
      dataReceita: dataReceita,
      notificacaoId: id,
    );
  }

  /// Identifica a dose (mesma chave usada nos registros de "tomado").
  String get chave => Agenda.chave(medicamentoId, horario);

  /// Texto guardado dentro da notificação.
  String get payload {
    return jsonEncode({
      'm': medicamentoId,
      'h': chave.split('|')[1],
      'n': nome,
      'd': dosagem,
      if (medico != null) 'r': medico,
      if (especialidade != null) 'e': especialidade,
      if (dataReceita != null) 'p': Datas.paraIso(dataReceita!),
    });
  }

  /// Lê o texto de uma notificação. Devolve null se estiver inválido.
  static AlertaDose? doPayload(String? texto) {
    if (texto == null || texto.isEmpty) {
      return null;
    }

    try {
      final mapa = jsonDecode(texto);

      if (mapa is! Map<String, dynamic>) {
        return null;
      }

      final dataReceita = mapa['p'] as String?;

      return AlertaDose(
        medicamentoId: mapa['m'] as int,
        nome: mapa['n'] as String,
        dosagem: mapa['d'] as String,
        horario: DateTime.parse(mapa['h'] as String),
        medico: mapa['r'] as String?,
        especialidade: mapa['e'] as String?,
        dataReceita: dataReceita == null ? null : DateTime.parse(dataReceita),
      );
    } catch (_) {
      return null;
    }
  }
}


/// Um lembrete que será agendado no aparelho.
class LembretePlanejado {
  /// Número da notificação (veja [Lembretes.idLembrete]). Fica abaixo de
  /// [Lembretes.primeiroIdAdiado].
  final int id;
  final AlertaDose alerta;

  const LembretePlanejado({required this.id, required this.alerta});

  DateTime get horario => alerta.horario;
}


/// Decide quais lembretes agendar.
class Lembretes {
  Lembretes._();

  /// Quantos lembretes ficam agendados de cada vez. (O iOS aceita no
  /// máximo 64 notificações agendadas por app.)
  static const int limite = 60;

  /// Até quantos dias à frente se agenda.
  static const int janelaDias = 7;

  /// Lembretes adiados usam números a partir daqui, para não se misturarem
  /// com os lembretes normais (que são reagendados do zero).
  static const int primeiroIdAdiado = 1000000;

  /// Escolhe os próximos lembretes: doses ativas, futuras, dentro da janela
  /// e que ainda não foram tomadas. Os mais próximos primeiro, até o limite.
  static List<LembretePlanejado> planejar({
    required List<Medicamento> medicamentos,
    required Set<String> tomadas,
    required DateTime agora,
  }) {
    final fim = agora.add(const Duration(days: janelaDias));

    final doses = <AlertaDose>[];

    for (final m in medicamentos.where((m) => m.ativo)) {
      for (final h in Agenda.horariosDoTratamento(m)) {
        if (!h.isAfter(agora) || h.isAfter(fim)) {
          continue;
        }

        if (tomadas.contains(Agenda.chave(m.id, h))) {
          continue;
        }

        doses.add(AlertaDose.deMedicamento(m, h));
      }
    }

    doses.sort((a, b) => a.horario.compareTo(b.horario));

    final plano = <LembretePlanejado>[];
    final usados = <int>{};

    for (final dose in doses.take(limite)) {
      var id = idLembrete(dose.chave);

      // Duas doses raramente caem no mesmo número: pula para o próximo livre.
      while (!usados.add(id)) {
        id = id % _maiorIdLembrete + 1;
      }

      plano.add(LembretePlanejado(id: id, alerta: dose));
    }

    return plano;
  }

  static const int _maiorIdLembrete = 999000;

  /// Número FIXO da notificação de uma dose (o mesmo em qualquer execução).
  /// Assim é possível cancelar o alarme exato de uma dose sem confundi-lo
  /// com o de outra, mesmo quando a fila de lembretes é refeita.
  /// Fica entre 1 e 999.000, abaixo dos números dos lembretes adiados.
  static int idLembrete(String chave) => _fnv(chave) % _maiorIdLembrete + 1;

  static int _fnv(String texto) {
    // FNV-1a de 32 bits: simples e igual em todas as execuções.
    var hash = 0x811c9dc5;

    for (final unidade in texto.codeUnits) {
      hash ^= unidade;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash;
  }

  /// Número fixo do lembrete adiado de uma dose (sempre o mesmo para a
  /// mesma dose, para poder cancelá-lo depois).
  static int idAdiado(String chave) {
    return primeiroIdAdiado + (_fnv('adiado|$chave') % 1000000000);
  }

  static String titulo(AlertaDose alerta) => 'Hora do ${alerta.nome}!';

  /// Texto da notificação. Com o médico, dois medicamentos iguais de
  /// receitas diferentes ficam distinguíveis já na barra de notificações.
  static String corpo(AlertaDose alerta) {
    final medico = alerta.medico;

    if (medico == null || medico.isEmpty) {
      return '${alerta.dosagem} • toque para marcar como tomado';
    }

    return '${alerta.dosagem} • $medico';
  }

  /// Segunda linha de identificação da receita, para a tela do alerta:
  /// "Clínico Geral • Receita de 18/09/2026". Vazia se não houver dados.
  static String detalheDaReceita(AlertaDose alerta) {
    final partes = <String>[
      if (alerta.especialidade != null && alerta.especialidade!.isNotEmpty)
        alerta.especialidade!,
      if (alerta.dataReceita != null)
        'Receita de ${Datas.paraBr(alerta.dataReceita!)}',
    ];

    return partes.join(' • ');
  }
}
