import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Tela mostrada enquanto o app confere se já existe um login guardado.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.gradiente),
        child: const SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.medication_rounded,
                  size: 56,
                  color: AppColors.roxo,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Saúde em Dia',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}


/// Mostrada quando o app abre, mas o servidor não responde.
class SemConexaoScreen extends StatefulWidget {
  final Future<void> Function() aoTentarNovamente;

  const SemConexaoScreen({super.key, required this.aoTentarNovamente});

  @override
  State<SemConexaoScreen> createState() => _SemConexaoScreenState();
}

class _SemConexaoScreenState extends State<SemConexaoScreen> {
  bool _tentando = false;

  Future<void> _tentar() async {
    setState(() => _tentando = true);

    await widget.aoTentarNovamente();

    if (mounted) {
      setState(() => _tentando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 64,
                  color: AppColors.roxo,
                ),
                const SizedBox(height: 20),
                const Text(
                  ApiService.mensagemSemConexao,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Confira sua conexão e tente novamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textoSuave),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _tentando ? null : _tentar,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(220, 52),
                  ),
                  child: _tentando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('TENTAR NOVAMENTE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
