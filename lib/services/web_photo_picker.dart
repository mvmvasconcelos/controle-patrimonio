import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'web_photo_resizer.dart';

enum PhotoSource { camera, file }

const maxPhotoDimension = 1280;

({int width, int height}) fitWithin(int width, int height,
    {int max = maxPhotoDimension}) {
  final longest = width > height ? width : height;
  if (longest <= max) return (width: width, height: height);
  final scale = max / longest;
  return (
    width: (width * scale).round().clamp(1, max),
    height: (height * scale).round().clamp(1, max),
  );
}

abstract class WebPhotoPicker {
  /// Returns JPEG bytes already resized, or null when the user cancels.
  Future<Uint8List?> pick(PhotoSource source);
}

class BrowserPhotoPicker implements WebPhotoPicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (file == null) return null;
    return resizeToJpeg(await file.readAsBytes());
  }
}
