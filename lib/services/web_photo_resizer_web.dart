// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'web_photo_picker.dart' show fitWithin;

const _jpegQuality = 0.85;

Future<Uint8List> resizeToJpeg(Uint8List original) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([original]));
  try {
    final image = html.ImageElement();
    final loaded = image.onLoad.first;
    final failed = image.onError.first;
    image.src = url;
    final ok = await Future.any([loaded.then((_) => true), failed.then((_) => false)]);
    if (!ok || image.naturalWidth == 0 || image.naturalHeight == 0) {
      throw Exception('Não foi possível ler a imagem selecionada');
    }
    final size = fitWithin(image.naturalWidth, image.naturalHeight);
    final canvas = html.CanvasElement(width: size.width, height: size.height);
    canvas.context2D.drawImageScaled(image, 0, 0, size.width, size.height);
    final blob = await canvas.toBlob('image/jpeg', _jpegQuality);
    final reader = html.FileReader()..readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;
    return Uint8List.fromList((reader.result as List<int>));
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
