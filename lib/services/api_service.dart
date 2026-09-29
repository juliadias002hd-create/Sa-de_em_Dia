import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Erro já com mensagem pronta para mostrar ao usuário.
class ApiException implements Exception {
  final String mensagem;
  final int? statusCode;

  const ApiException(this.mensagem, {this.statusCode});

  @override
  String toString() => mensagem;
}


/// Arquivo escolhido pelo usuário (foto ou PDF), pronto para envio.
class ArquivoParaEnvio {
  final Uint8List bytes;
  final String nome;

  const ArquivoParaEnvio({required this.bytes, required this.nome});
}


/// Único ponto do app que fala HTTP com a API.
///
/// Cuida de: endereço, token JWT, JSON, envio de arquivos, tempo limite
/// e tradução de qualquer falha em [ApiException] com texto amigável.
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const String mensagemSemConexao =
      'Não foi possível conectar ao servidor.';

  final http.Client _cliente = http.Client();

  String? _token;

  /// Chamado quando a API recusa o token (sessão expirada).
  void Function()? aoSessaoExpirar;

  void definirToken(String? token) => _token = token;

  bool get temToken => _token != null;

  Map<String, String> get _cabecalhos => {
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String caminho) => Uri.parse('${ApiConfig.baseUrl}$caminho');


  // ---------- JSON ----------

  Future<Map<String, dynamic>> get(
    String caminho, {
    Map<String, String>? consulta,
  }) {
    final uri = _uri(caminho).replace(queryParameters: consulta);

    return _executar(
      () => _cliente.get(uri, headers: _cabecalhos),
      ApiConfig.tempoLimite,
    );
  }

  /// [expirarSessao] em false: um 401 aqui não derruba a sessão (usado ao
  /// conferir a senha de quem já está logado).
  Future<Map<String, dynamic>> post(
    String caminho,
    Map<String, dynamic> corpo, {
    bool expirarSessao = true,
  }) {
    return _executar(
      () => _cliente.post(
        _uri(caminho),
        headers: {..._cabecalhos, 'Content-Type': 'application/json'},
        body: jsonEncode(corpo),
      ),
      ApiConfig.tempoLimite,
      expirarSessao: expirarSessao,
    );
  }

  Future<Map<String, dynamic>> put(String caminho, Map<String, dynamic> corpo) {
    return _executar(
      () => _cliente.put(
        _uri(caminho),
        headers: {..._cabecalhos, 'Content-Type': 'application/json'},
        body: jsonEncode(corpo),
      ),
      ApiConfig.tempoLimite,
    );
  }

  Future<Map<String, dynamic>> delete(String caminho) {
    return _executar(
      () => _cliente.delete(_uri(caminho), headers: _cabecalhos),
      ApiConfig.tempoLimite,
    );
  }


  // ---------- Arquivos ----------

  /// Envia campos de texto + (opcionalmente) um arquivo no campo "arquivo".
  Future<Map<String, dynamic>> enviarArquivo(
    String metodo,
    String caminho, {
    required Map<String, String> campos,
    ArquivoParaEnvio? arquivo,
  }) {
    return _executar(() async {
      final requisicao = http.MultipartRequest(metodo, _uri(caminho))
        ..headers.addAll(_cabecalhos)
        ..fields.addAll(campos);

      if (arquivo != null) {
        requisicao.files.add(
          http.MultipartFile.fromBytes(
            'arquivo',
            arquivo.bytes,
            filename: arquivo.nome,
          ),
        );
      }

      final resposta = await _cliente.send(requisicao);

      return http.Response.fromStream(resposta);
    }, ApiConfig.tempoLimiteUpload);
  }

  /// Baixa um arquivo protegido (ex.: imagem da receita).
  Future<Uint8List> baixarBytes(String caminho) async {
    try {
      final resposta = await _cliente
          .get(_uri(caminho), headers: _cabecalhos)
          .timeout(ApiConfig.tempoLimiteUpload);

      if (resposta.statusCode == 200) {
        return resposta.bodyBytes;
      }

      _tratar(resposta);

      throw const ApiException('Não foi possível abrir o arquivo.');
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'O servidor demorou para responder. Tente novamente.',
      );
    } catch (_) {
      throw const ApiException(mensagemSemConexao);
    }
  }


  // ---------- Núcleo ----------

  Future<Map<String, dynamic>> _executar(
    Future<http.Response> Function() requisicao,
    Duration tempoLimite, {
    bool expirarSessao = true,
  }) async {
    try {
      final resposta = await requisicao().timeout(tempoLimite);

      return _tratar(resposta, expirarSessao: expirarSessao);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'O servidor demorou para responder. Tente novamente.',
      );
    } catch (_) {
      // Sem internet, servidor desligado, endereço errado etc.
      // O detalhe técnico não é mostrado ao usuário.
      throw const ApiException(mensagemSemConexao);
    }
  }

  Map<String, dynamic> _tratar(http.Response resposta, {bool expirarSessao = true}) {
    Object? corpo;

    try {
      corpo = jsonDecode(utf8.decode(resposta.bodyBytes, allowMalformed: true));
    } catch (_) {
      corpo = null;
    }

    if (corpo is! Map<String, dynamic>) {
      throw ApiException(
        'Resposta inesperada do servidor. Tente novamente.',
        statusCode: resposta.statusCode,
      );
    }

    final sucesso = corpo['success'] == true &&
        resposta.statusCode >= 200 &&
        resposta.statusCode < 300;

    if (sucesso) {
      return corpo;
    }

    // Token recusado: a sessão acabou, volta para o login.
    if (resposta.statusCode == 401 && _token != null && expirarSessao) {
      _token = null;
      aoSessaoExpirar?.call();
    }

    final mensagem = corpo['message'];

    throw ApiException(
      mensagem is String && mensagem.isNotEmpty
          ? mensagem
          : 'Ocorreu um erro. Tente novamente.',
      statusCode: resposta.statusCode,
    );
  }
}
