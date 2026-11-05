import 'package:file_picker/file_picker.dart';

import '../services/web_inventory_repository.dart';

class PickedInventoryFile {
  const PickedInventoryFile(this.filename, this.bytes);

  final String filename;
  final List<int> bytes;
}

typedef InventoryFilePicker = Future<PickedInventoryFile?> Function();
typedef DownloadSaver = Future<void> Function(DownloadedFile file);

Future<PickedInventoryFile?> pickInventoryFileFromBrowser() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'xls', 'xlsx'],
    withData: true,
  );
  final file = result?.files.single;
  if (file == null || file.bytes == null) return null;
  return PickedInventoryFile(file.name, file.bytes!);
}
