/// Paciente que usa o aplicativo.
class Usuario {
  final int id;
  final String nome;
  final String email;
  final String? telefone;

  /// Data de nascimento no formato da API: AAAA-MM-DD.
  final String? dataNascimento;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    this.telefone,
    this.dataNascimento,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nome: json['nome'] as String,
      email: json['email'] as String,
      telefone: json['telefone'] as String?,
      dataNascimento: json['data_nascimento'] as String?,
    );
  }

  /// Primeiro nome, para saudações ("Olá, Júlia!").
  String get primeiroNome {
    final partes = nome.trim().split(RegExp(r'\s+'));

    return partes.isEmpty ? nome : partes.first;
  }
}
