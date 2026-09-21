import 'package:file_picker/file_picker.dart';

import 'api_service.dart';

/// Selecionar o PDF da receita.
class FileService {
  Future<ArquivoParaEnvio?> selecionarPdf() async {
    final PlatformFile? arquivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (arquivo == null) {
      return null;
    }

    return ArquivoParaEnvio(
      bytes: await arquivo.readAsBytes(),
      nome: arquivo.name,
    );
  }
}
