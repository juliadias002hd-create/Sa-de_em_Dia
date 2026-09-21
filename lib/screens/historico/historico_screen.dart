import 'package:flutter/material.dart';

import '../../widgets/estado_vazio.dart';

/// Histórico de doses. (Será completado na etapa do histórico, quando o
/// app passar a registrar cada dose tomada.)
class HistoricoScreen extends StatelessWidget {
  const HistoricoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: const EstadoVazio(
        icone: Icons.history_rounded,
        titulo: 'Em breve',
        mensagem:
            'Aqui você verá quais medicamentos tomou e em que horário.',
      ),
    );
  }
}
