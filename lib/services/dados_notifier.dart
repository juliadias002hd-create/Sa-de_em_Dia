import 'package:flutter/foundation.dart';

/// Aviso simples de "os dados mudaram".
///
/// Quando uma tela cadastra, edita ou exclui uma receita/medicamento, chama
/// [DadosApp.mudou]. As abas que mostram listas escutam [DadosApp.versao] e
/// recarregam sozinhas, então tudo fica sempre atualizado.
class DadosApp {
  DadosApp._();

  static final ValueNotifier<int> versao = ValueNotifier<int>(0);

  static void mudou() => versao.value++;
}
