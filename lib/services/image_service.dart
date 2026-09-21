import 'package:image_picker/image_picker.dart';

import 'api_service.dart';

/// Tirar foto ou escolher da galeria.
///
/// As fotos são reduzidas (lado maior de 2200 px, qualidade 85) para caber
/// com folga no limite de 10 MB da API e enviar mais rápido, sem perder a
/// legibilidade da receita.
class ImageService {
  final ImagePicker picker = ImagePicker();

  Future<ArquivoParaEnvio?> tirarFoto() {
    return _escolher(ImageSource.camera);
  }

  Future<ArquivoParaEnvio?> escolherDaGaleria() {
    return _escolher(ImageSource.gallery);
  }

  Future<ArquivoParaEnvio?> _escolher(ImageSource origem) async {
    final XFile? foto = await picker.pickImage(
      source: origem,
      maxWidth: 2200,
      maxHeight: 2200,
      imageQuality: 85,
    );

    if (foto == null) {
      return null;
    }

    return ArquivoParaEnvio(
      bytes: await foto.readAsBytes(),
      nome: foto.name,
    );
  }
}
