import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as implementation;

class DownloadedFile {
  const DownloadedFile(this.filename, this.bytes);

  final String filename;
  final List<int> bytes;
}

/// Entrega o arquivo ao usuário pelo download do navegador.
Future<void> saveDownloadedFile(DownloadedFile file) =>
    implementation.saveFile(file.filename, file.bytes);
