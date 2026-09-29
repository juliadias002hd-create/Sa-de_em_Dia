import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/bloqueio_controller.dart';
import 'services/configuracoes_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nomes de dias e meses em português (usados na tela inicial).
  await initializeDateFormatting('pt_BR');

  // Recupera o tema e o tamanho da letra que o usuário escolheu, antes de o
  // app aparecer (assim não pisca no tema errado).
  await ConfiguracoesController.instance.carregar();

  // Lê se a pessoa ligou o bloqueio por digital/rosto.
  await BloqueioController.instance.carregar();

  runApp(const SaudeEmDiaApp());
}
