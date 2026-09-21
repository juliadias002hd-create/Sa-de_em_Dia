import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Máscara de telefone enquanto o usuário digita:
///  (11) 98888-7777   ou   (11) 3888-7777
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    var digitos = novo.text.replaceAll(RegExp(r'\D'), '');

    if (digitos.length > 11) {
      digitos = digitos.substring(0, 11);
    }

    final buffer = StringBuffer();

    for (var i = 0; i < digitos.length; i++) {
      if (i == 0) {
        buffer.write('(');
      }

      if (i == 2) {
        buffer.write(') ');
      }

      // 11 dígitos: hífen depois do 7º. 10 dígitos: depois do 6º.
      if (digitos.length > 10 && i == 7) {
        buffer.write('-');
      } else if (digitos.length <= 10 && i == 6) {
        buffer.write('-');
      }

      buffer.write(digitos[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}


/// Máscara de data dd/MM/aaaa enquanto o usuário digita.
class DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    var digitos = novo.text.replaceAll(RegExp(r'\D'), '');

    if (digitos.length > 8) {
      digitos = digitos.substring(0, 8);
    }

    final buffer = StringBuffer();

    for (var i = 0; i < digitos.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }

      buffer.write(digitos[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}


/// Conversões de data entre o formato brasileiro (tela) e o da API.
class Datas {
  Datas._();

  static final DateFormat _br = DateFormat('dd/MM/yyyy');
  static final DateFormat _iso = DateFormat('yyyy-MM-dd');

  /// DateTime -> "31/08/2026"
  static String paraBr(DateTime data) => _br.format(data);

  /// DateTime -> "2026-08-31" (formato enviado à API)
  static String paraIso(DateTime data) => _iso.format(data);

  /// "31/08/2026" -> "2026-08-31". Devolve null se não for uma data.
  static String? brParaIso(String texto) {
    final partes = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto.trim());

    if (partes == null) {
      return null;
    }

    return '${partes.group(3)}-${partes.group(2)}-${partes.group(1)}';
  }

  /// "1995-03-15" -> "15/03/1995"
  static String isoParaBr(String iso) {
    final partes = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);

    if (partes == null) {
      return iso;
    }

    return '${partes.group(3)}/${partes.group(2)}/${partes.group(1)}';
  }

  /// TimeOfDay-like -> "08:05"
  static String hora(int hora, int minuto) {
    return '${hora.toString().padLeft(2, '0')}:'
        '${minuto.toString().padLeft(2, '0')}';
  }
}
