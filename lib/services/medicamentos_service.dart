import '../models/medicamento.dart';
import 'api_service.dart';

/// Medicamentos do paciente logado (API: /api/medicamentos).
class MedicamentoService {
  final ApiService _api = ApiService.instance;

  List<Medicamento> _lista(Map<String, dynamic> resposta) {
    final lista = resposta['data']['medicamentos'] as List<dynamic>;

    return lista
        .map((m) => Medicamento.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Todos os medicamentos. Com [somenteAtivos], só os que estão em uso.
  Future<List<Medicamento>> listar({bool somenteAtivos = false}) async {
    final resposta = await _api.get(
      '/api/medicamentos',
      consulta: somenteAtivos ? {'ativo': 'true'} : null,
    );

    return _lista(resposta);
  }

  Future<List<Medicamento>> listarPorReceita(int receitaId) async {
    final resposta = await _api.get('/api/receitas/$receitaId/medicamentos');

    return _lista(resposta);
  }

  Future<Medicamento> criar({
    required int receitaId,
    required String nome,
    required String dosagem,
    required int intervaloHoras,
    required String horarioInicio,
    required int duracaoDias,
    String? observacoes,
  }) async {
    final resposta = await _api.post('/api/medicamentos', {
      'receita_id': receitaId,
      'nome': nome,
      'dosagem': dosagem,
      'intervalo_horas': intervaloHoras,
      'horario_inicio': horarioInicio,
      'duracao_dias': duracaoDias,
      'observacoes': observacoes,
    });

    return Medicamento.fromJson(resposta['data']['medicamento']);
  }

  Future<Medicamento> atualizar({
    required int id,
    required String nome,
    required String dosagem,
    required int intervaloHoras,
    required String horarioInicio,
    required int duracaoDias,
    String? observacoes,
    bool? ativo,
  }) async {
    final resposta = await _api.put('/api/medicamentos/$id', {
      'nome': nome,
      'dosagem': dosagem,
      'intervalo_horas': intervaloHoras,
      'horario_inicio': horarioInicio,
      'duracao_dias': duracaoDias,
      'observacoes': observacoes,
      'ativo': ?ativo,
    });

    return Medicamento.fromJson(resposta['data']['medicamento']);
  }

  Future<void> excluir(int id) async {
    await _api.delete('/api/medicamentos/$id');
  }
}
