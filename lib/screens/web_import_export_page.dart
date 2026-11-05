import 'package:flutter/material.dart';

import '../services/web_inventory_repository.dart';
import '../theme.dart';
import 'web_data_management_page.dart';

class WebImportExportPage extends StatefulWidget {
  const WebImportExportPage({
    super.key,
    required this.repository,
    required this.pickFile,
    required this.saveDownload,
    this.onImported,
    this.onOpenInventory,
  });

  final WebInventoryRepository repository;
  final InventoryFilePicker pickFile;
  final DownloadSaver saveDownload;
  final Future<void> Function()? onImported;
  final VoidCallback? onOpenInventory;

  @override
  State<WebImportExportPage> createState() => _WebImportExportPageState();
}

class _WebImportExportPageState extends State<WebImportExportPage> {
  InventoryTotals? _totals;
  ImportSummary? _summary;
  ExportFormat _format = ExportFormat.xlsx;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run(() async => null);
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    String? message;
    try {
      message = await action();
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    }
    try {
      final totals = await widget.repository.fetchTotals();
      if (mounted) _totals = totals;
    } catch (error) {
      _error ??= error.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _message = message;
      });
    }
  }

  Future<bool> _confirmReplace() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Atenção'),
          content: const Text(
            'Importar uma nova planilha vai substituir os dados atuais.\n\n'
            'Modificações ainda não exportadas serão perdidas.\n\n'
            'Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _import() async {
    if (!await _confirmReplace()) return;
    final file = await widget.pickFile();
    if (file == null) return;
    await _run(() async {
      _summary = null;
      _summary = await widget.repository.importInventory(
        file.filename,
        file.bytes,
      );
      await widget.onImported?.call();
      return 'Planilha importada com sucesso.';
    });
  }

  Future<void> _export({required bool onlyModified}) => _run(() async {
        final file = await widget.repository.exportSpreadsheet(
          format: _format,
          onlyModified: onlyModified,
        );
        await widget.saveDownload(file);
        return 'Planilha exportada: ${file.filename}';
      });

  Future<void> _restorePhotos() => _run(() async {
        final count = await widget.repository.restoreSyncedPhotos();
        return count == 0
            ? 'Todas as fotos sincronizadas já estão neste dispositivo.'
            : '$count foto(s) restaurada(s).';
      });

  Future<void> _cleanOrphans() => _run(() async {
        final count = await widget.repository.cleanOrphanPhotos();
        return count == 0
            ? 'Nenhuma foto órfã encontrada.'
            : 'Limpeza concluída: $count foto(s) órfã(s) removida(s).';
      });

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    final total = totals?.total ?? 0;
    final modified = totals?.modified ?? 0;
    final summary = _summary;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / Exportar')),
      body: CenteredColumn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        icon: Icons.inventory_2,
                        label: 'Total importado',
                        value: '$total',
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        icon: Icons.edit_note,
                        label: 'Modificados',
                        value: '$modified',
                        color: modified > 0 ? Colors.orange : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (total > 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    widget.onOpenInventory ?? () => Navigator.of(context).pop(),
                icon: const Icon(Icons.list_alt),
                label: const Text('Ver inventário completo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: TextStyle(color: scheme.primary)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const _SectionHeader(
              icon: Icons.photo_library,
              label: 'Fotos e Sincronização',
            ),
            const SizedBox(height: 8),
            const _Hint(
              'Restaure as fotos sincronizadas neste dispositivo e mantenha '
              'o banco local sem registros órfãos.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || total == 0 ? null : _restorePhotos,
              icon: const Icon(Icons.cloud_download),
              label: const Text('Restaurar fotos sincronizadas'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _cleanOrphans,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Limpar fotos órfãs'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const _SectionHeader(
              icon: Icons.upload_file,
              label: 'Importar Planilha do SUAP',
            ),
            const SizedBox(height: 8),
            const _Hint(
              'Selecione o arquivo exportado do SUAP (.csv, .xls ou .xlsx). '
              'Os dados atuais serão substituídos.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.folder_open),
              label: const Text('Selecionar arquivo'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: 12),
              Text('Novos: ${summary.created}'),
              Text('Atualizados: ${summary.updated}'),
              Text('Sem alteração: ${summary.unchanged}'),
              Text('Com erro: ${summary.errors.length}'),
              for (final error in summary.errors)
                Text('Linha ${error.line}: ${error.message}'),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const _SectionHeader(
              icon: Icons.download,
              label: 'Exportar Planilha',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Formato:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('.xlsx'),
                  selected: _format == ExportFormat.xlsx,
                  onSelected: (_) =>
                      setState(() => _format = ExportFormat.xlsx),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('.csv'),
                  selected: _format == ExportFormat.csv,
                  onSelected: (_) => setState(() => _format = ExportFormat.csv),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ExportOption(
              icon: Icons.edit_note,
              title: 'Somente itens modificados',
              description: 'Exporta apenas os $modified item(ns) alterado(s), '
                  'conferido(s) ou com foto. Ideal para atualização pontual.',
              enabled: !_busy && modified > 0,
              onTap: () => _export(onlyModified: true),
            ),
            const SizedBox(height: 8),
            _ExportOption(
              icon: Icons.table_chart,
              title: 'Planilha completa',
              description: 'Exporta todos os $total item(ns) com a coluna '
                  '"ATUALIZADO_EM" preenchida apenas onde houve alteração.',
              enabled: !_busy && total > 0,
              onTap: () => _export(onlyModified: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Icon(icon, color: tint),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: tint,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13));
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          enabled: enabled,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(description),
          trailing: const Icon(Icons.download),
          onTap: enabled ? onTap : null,
        ),
      );
}
