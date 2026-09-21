/// Validações dos formulários. Cada função devolve a mensagem de erro
/// para mostrar ao usuário, ou null quando o valor está correto.
class Validators {
  Validators._();

  static String? obrigatorio(String? valor, [String mensagem = 'Preencha este campo.']) {
    if (valor == null || valor.trim().isEmpty) {
      return mensagem;
    }

    return null;
  }

  static String? nome(String? valor) {
    final texto = (valor ?? '').trim();

    if (texto.isEmpty) {
      return 'Informe seu nome.';
    }

    if (texto.length < 2) {
      return 'Informe um nome válido.';
    }

    return null;
  }

  static String? email(String? valor) {
    final texto = (valor ?? '').trim();

    if (texto.isEmpty) {
      return 'Informe seu e-mail.';
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(texto)) {
      return 'Informe um e-mail válido.';
    }

    return null;
  }

  static String? senha(String? valor) {
    final texto = valor ?? '';

    if (texto.isEmpty) {
      return 'Informe a senha.';
    }

    if (texto.length < 8) {
      return 'A senha deve ter no mínimo 8 caracteres.';
    }

    return null;
  }

  static String? Function(String?) confirmarSenha(String Function() senhaAtual) {
    return (valor) {
      if (valor == null || valor.isEmpty) {
        return 'Confirme a senha.';
      }

      if (valor != senhaAtual()) {
        return 'As senhas não são iguais.';
      }

      return null;
    };
  }

  /// Telefone opcional: se preenchido, precisa ter DDD + 8 ou 9 dígitos.
  static String? telefoneOpcional(String? valor) {
    final texto = (valor ?? '').trim();

    if (texto.isEmpty) {
      return null;
    }

    final digitos = texto.replaceAll(RegExp(r'\D'), '');

    if (digitos.length != 10 && digitos.length != 11) {
      return 'Informe o telefone com DDD. Ex.: (11) 98888-7777.';
    }

    return null;
  }

  /// Data no formato dd/MM/aaaa. Se [opcional], vazio é aceito.
  static String? Function(String?) data({
    bool opcional = false,
    bool naoFutura = false,
    String mensagemVazio = 'Informe a data.',
  }) {
    return (valor) {
      final texto = (valor ?? '').trim();

      if (texto.isEmpty) {
        return opcional ? null : mensagemVazio;
      }

      final data = _lerDataBr(texto);

      if (data == null) {
        return 'Informe uma data válida. Ex.: 31/08/2026.';
      }

      if (naoFutura && data.isAfter(DateTime.now())) {
        return 'A data não pode estar no futuro.';
      }

      if (data.year < 1900) {
        return 'Informe uma data válida.';
      }

      return null;
    };
  }

  /// Número inteiro entre [minimo] e [maximo].
  static String? Function(String?) inteiro({
    required String campo,
    required int minimo,
    required int maximo,
  }) {
    return (valor) {
      final texto = (valor ?? '').trim();

      if (texto.isEmpty) {
        return 'Informe $campo.';
      }

      final numero = int.tryParse(texto);

      if (numero == null || numero < minimo || numero > maximo) {
        return 'Use um número inteiro de $minimo a $maximo.';
      }

      return null;
    };
  }

  static DateTime? _lerDataBr(String texto) {
    final partes = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto);

    if (partes == null) {
      return null;
    }

    final dia = int.parse(partes.group(1)!);
    final mes = int.parse(partes.group(2)!);
    final ano = int.parse(partes.group(3)!);

    final data = DateTime(ano, mes, dia);

    // DateTime aceita 31/02 e "rola" para março; aqui isso é inválido.
    if (data.year != ano || data.month != mes || data.day != dia) {
      return null;
    }

    return data;
  }
}
