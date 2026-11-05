import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

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

class WebDataManagementPage extends StatefulWidget {
  const WebDataManagementPage({
    super.key,
    required this.repository,
    required this.pickFile,
    required this.saveDownload,
    this.onImported,
  });

  final WebInventoryRepository repository;
  final InventoryFilePicker pickFile;
  final DownloadSaver saveDownload;
  final Future<void> Function()? onImported;

  @override
  State<WebDataManagementPage> createState() => _WebDataManagementPageState();
}

class _WebDataManagementPageState extends State<WebDataManagementPage> {
  bool _busy = false;
  String? _error;
  ImportSummary? _summary;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _import() => _run(() async {
        final file = await widget.pickFile();
        if (file == null) return;
        _summary = null;
        _summary = await widget.repository.importInventory(
          file.filename,
          file.bytes,
        );
        await widget.onImported?.call();
      });

  Future<void> _export(Future<DownloadedFile> Function() load) =>
      _run(() async {
        await widget.saveDownload(await load());
      });

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de dados')),
      body: CenteredColumn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Inventário', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Envie o Inventário do SUAP (CSV, XLS ou XLSX). Conferências e '
              'fotos existentes são preservadas.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar Inventário'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _export(widget.repository.exportChanges),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar alterações'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _export(widget.repository.exportReport),
                  icon: const Icon(Icons.assessment),
                  label: const Text('Exportar relatório'),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (summary != null) ...[
              const SizedBox(height: 24),
              Text('Resumo da importação',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Novos: ${summary.created}'),
              Text('Atualizados: ${summary.updated}'),
              Text('Sem alteração: ${summary.unchanged}'),
              Text('Com erro: ${summary.errors.length}'),
              for (final error in summary.errors)
                Text('Linha ${error.line}: ${error.message}'),
            ],
          ],
        ),
      ),
    );
  }
}
