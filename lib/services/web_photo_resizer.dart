import 'dart:typed_data';

import 'web_photo_resizer_stub.dart'
    if (dart.library.html) 'web_photo_resizer_web.dart' as implementation;

Future<Uint8List> resizeToJpeg(Uint8List original) =>
    implementation.resizeToJpeg(original);
