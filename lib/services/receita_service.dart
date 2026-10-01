import 'dart:typed_data';

import '../models/receita.dart';
import 'api_service.dart';

/// Receitas do paciente logado (API: /api/receitas).
class ReceitaService {
  final ApiService _api = ApiService.instance;

  Future<List<Receita>> listar() async {
    final resposta = await _api.get('/api/receitas');

    final lista = resposta['data']['receitas'] as List<dynamic>;

    return lista
        .map((r) => Receita.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Receita com a lista de medicamentos dela.
  Future<Receita> buscar(int id) async {
    final resposta = await _api.get('/api/receitas/$id');

    return Receita.fromJson(resposta['data']['receita']);
  }

  /// Cria a receita; o arquivo (foto ou PDF) é opcional.
  Future<Receita> criar({
    required String dataReceitaIso,
    required String medico,
    required String especialidade,
    ArquivoParaEnvio? arquivo,
  }) async {
    final resposta = await _api.enviarArquivo(
      'POST',
      '/api/receitas',
      campos: {
        'data_receita': dataReceitaIso,
        'medico': medico,
        'especialidade': especialidade,
      },
      arquivo: arquivo,
    );

    return Receita.fromJson(resposta['data']['receita']);
  }

  /// Atualiza a receita. O arquivo é opcional: sem [arquivo] e sem
  /// [removerArquivo], o arquivo atual é mantido.
  Future<Receita> atualizar({
    required int id,
    required String dataReceitaIso,
    required String medico,
    required String especialidade,
    ArquivoParaEnvio? arquivo,
    bool removerArquivo = false,
  }) async {
    final resposta = await _api.enviarArquivo(
      'PUT',
      '/api/receitas/$id',
      campos: {
        'data_receita': dataReceitaIso,
        'medico': medico,
        'especialidade': especialidade,
        if (removerArquivo) 'remover_arquivo': 'true',
      },
      arquivo: arquivo,
    );

    return Receita.fromJson(resposta['data']['receita']);
  }

  Future<void> excluir(int id) async {
    await _api.delete('/api/receitas/$id');
  }

  /// Bytes do arquivo da receita (imagem ou PDF).
  Future<Uint8List> baixarArquivo(int id) {
    return _api.baixarBytes('/api/receitas/$id/arquivo');
  }
}
