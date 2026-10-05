// Script de desenvolvimento (não faz parte do app): recorta a logo original
// e prepara as imagens usadas pelo flutter_launcher_icons. Rodar de novo só
// é necessário se a logo (assets/icone/app_icon_original.jpg) mudar.
//
//   dart run tool/crop_icon.dart
//   dart run flutter_launcher_icons
// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/icone/app_icon_original.jpg').readAsBytesSync();
  final original = img.decodeImage(bytes)!;

  // Acha a caixa que envolve tudo que não é "quase branco" (a margem).
  const limiar = 250; // 0-255: acima disso conta como fundo branco
  int minX = original.width, minY = original.height, maxX = 0, maxY = 0;

  for (int y = 0; y < original.height; y++) {
    for (int x = 0; x < original.width; x++) {
      final p = original.getPixel(x, y);
      if (p.r < limiar || p.g < limiar || p.b < limiar) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Conteúdo real: x=$minX..$maxX  y=$minY..$maxY (imagem ${original.width}x${original.height})');

  final contentW = maxX - minX;
  final contentH = maxY - minY;
  final contentSize = contentW > contentH ? contentW : contentH;

  img.Image recortarCentralizado(double folgaFracao) {
    final folga = (contentSize * folgaFracao).round();
    final size = contentSize + folga * 2;

    final cx = (minX + maxX) ~/ 2;
    final cy = (minY + maxY) ~/ 2;

    var left = cx - size ~/ 2;
    var top = cy - size ~/ 2;

    if (left < 0) left = 0;
    if (top < 0) top = 0;
    if (left + size > original.width) left = original.width - size;
    if (top + size > original.height) top = original.height - size;

    return img.copyCrop(original, x: left, y: top, width: size, height: size);
  }

  // 1) Ícone "cheio" (fundo branco), usado em iOS/web/Windows/macOS e como
  //    retrato de segurança no Android antigo (< 8.0). Pouca folga: o logo
  //    ocupa quase todo o quadrado.
  final cheio = img.copyResize(recortarCentralizado(0.10), width: 1024, height: 1024);
  File('assets/icone/app_icon.png').writeAsBytesSync(img.encodePng(cheio));
  print('Salvo assets/icone/app_icon.png (${cheio.width}x${cheio.height})');

  // 2) Camada de frente do ícone adaptável do Android: fundo TRANSPARENTE
  //    (o branco quase-puro vira alpha 0) e bastante folga, porque o
  //    Android pode recortar em círculo/quadrado arredondado e corta as
  //    bordas da camada de frente.
  //
  //    O JPEG de origem não tem canal alfa, então a cópia recortada
  //    também não tem: é preciso criar uma imagem nova com 4 canais
  //    (RGBA) e copiar os pixels manualmente para poder apagar o fundo.
  final paraFrente = recortarCentralizado(0.12);

  final comAlfa = img.Image(
    width: paraFrente.width,
    height: paraFrente.height,
    numChannels: 4,
  );

  for (var y = 0; y < paraFrente.height; y++) {
    for (var x = 0; x < paraFrente.width; x++) {
      final p = paraFrente.getPixel(x, y);

      // Quão "branco" o pixel é (0 = colorido, 255 = branco puro).
      final brancura = [p.r, p.g, p.b].reduce((a, b) => a < b ? a : b);

      final alfa = brancura <= 235
          ? 255
          : (255 - (brancura - 235) / (255 - 235) * 255).clamp(0, 255).round();

      comAlfa.setPixelRgba(x, y, p.r, p.g, p.b, alfa);
    }
  }

  final frente = img.copyResize(comAlfa, width: 1024, height: 1024);
  File('assets/icone/app_icon_foreground.png').writeAsBytesSync(img.encodePng(frente));
  print('Salvo assets/icone/app_icon_foreground.png (${frente.width}x${frente.height})');
}
