import '../models/historico.dart';
import '../utils/formatters.dart';
import 'api_service.dart';

/// Doses tomadas (API: /api/doses). Alimenta o status "Tomado" e o Histórico.
class DoseService {
  final ApiService _api = ApiService.instance;

  /// "2026-09-21 08:00:00" — horário local, sem fuso (o mesmo relógio do
  /// servidor).
  static String _formatar(DateTime d) {
    return '${Datas.paraIso(d)} '
        '${Datas.hora(d.hour, d.minute)}:00';
  }

  /// Marca uma dose como tomada agora.
  Future<RegistroDose> registrar({
    required int medicamentoId,
    required DateTime horarioPrevisto,
  }) async {
    final resposta = await _api.post('/api/doses', {
      'medicamento_id': medicamentoId,
      'horario_previsto': _formatar(horarioPrevisto),
    });

    return RegistroDose.fromJson(resposta['data']['registro']);
  }

  /// Desfaz o registro de uma dose (a dose volta a "A tomar"/"Atrasado").
  Future<void> desfazer(int registroId) async {
    await _api.delete('/api/doses/$registroId');
  }

  /// Doses tomadas cujo horário previsto está entre [inicio] e [fim]
  /// (dias inteiros, inclusive).
  Future<List<RegistroDose>> listar({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final resposta = await _api.get(
      '/api/doses',
      consulta: {
        'inicio': Datas.paraIso(inicio),
        'fim': Datas.paraIso(fim),
      },
    );

    final lista = resposta['data']['registros'] as List<dynamic>;

    return lista
        .map((r) => RegistroDose.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
