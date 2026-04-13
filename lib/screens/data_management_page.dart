import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../database/hive_database.dart';
import '../providers/patrimonio_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool _isImporting = false;
  bool _isExporting = false;
  String _exportFormat = 'xlsx';

  // ── Importação ──────────────────────────────────────────
  Future<void> _pickAndImport() async {
    final provider = context.read<PatrimonioProvider>();
    final hasPending = HiveDatabase.hasPendingModifications();

    if (hasPending) {
      final confirmed = await _showOverwriteDialog();
      if (!confirmed) return;
    }

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx'],
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Erro ao abrir seletor de arquivo: $e');
      return;
    }

    if (result == null || result.files.single.path == null) return;

    setState(() => _isImporting = true);
    try {
      final file = File(result.files.single.path!);
      final importResult = await ImportService.importFile(file);

      await HiveDatabase.importData(
        importResult.patrimonios,
        importResult.rawRows,
      );

      await provider.loadLocalData();

      if (!mounted) return;
      final navigator = Navigator.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u2713 ${importResult.patrimonios.length} itens importados'
            '${importResult.skipped > 0 ? ' (${importResult.skipped} ignorados)' : ''}',
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Ver inventário',
            textColor: Colors.white,
            onPressed: () => navigator.pushNamed('/inventory'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Erro na importação: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // ── Exportação ──────────────────────────────────────────
  Future<void> _exportModified() async {
    final provider = context.read<PatrimonioProvider>();
    final modified = provider.patrimonios.where((p) => p.isModified).toList();
    if (modified.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum item modificado para exportar.')),
      );
      return;
    }
    await _runExport(() => ExportService.exportModifiedOnly(modified, _exportFormat));
  }

  Future<void> _exportFull() async {
    final provider = context.read<PatrimonioProvider>();
    if (provider.patrimonios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum dado carregado para exportar.')),
      );
      return;
    }
    await _runExport(
      () => ExportService.exportFull(provider.patrimonios, _exportFormat),
    );
  }

  Future<void> _runExport(Future<File> Function() fn) async {
    setState(() => _isExporting = true);
    try {
      final file = await fn();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final result = await OpenFilex.open(
        file.path,
        type: _exportFormat == 'xlsx'
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'text/csv',
      );
      if (!mounted) return;
      if (result.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Arquivo salvo em:\n${file.path}'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Erro ao exportar: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Dialogs ─────────────────────────────────────────────
  Future<bool> _showOverwriteDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Atenção'),
            content: const Text(
              'Existem modificações não exportadas.\n\n'
              'Importar uma nova planilha vai substituir todos os dados '
              'e as alterações pendentes serão perdidas.\n\n'
              'Deseja continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Substituir dados',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Dados'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer<PatrimonioProvider>(
        builder: (context, provider, _) {
          final totalItems = provider.patrimonios.length;
          final modifiedCount =
              provider.patrimonios.where((p) => p.isModified).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Status atual ────────────────────────────
              _StatusCard(
                totalItems: totalItems,
                modifiedCount: modifiedCount,
              ),

              if (totalItems > 0) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/inventory'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Ver inventário completo'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Importar ────────────────────────────────
              const _SectionHeader(
                icon: Icons.upload_file,
                label: 'Importar Planilha do SUAP',
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecione o arquivo exportado do SUAP (.csv, .xls ou .xlsx). '
                'Os dados atuais serão substituídos.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _pickAndImport,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),
                label: Text(
                  _isImporting ? 'Importando...' : 'Selecionar arquivo',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),

              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),

              // ── Exportar ────────────────────────────────
              const _SectionHeader(
                icon: Icons.download,
                label: 'Exportar Planilha',
                color: Colors.green,
              ),
              const SizedBox(height: 8),

              // Seletor de formato
              Row(
                children: [
                  const Text(
                    'Formato:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('.xlsx'),
                    selected: _exportFormat == 'xlsx',
                    onSelected: (_) => setState(() => _exportFormat = 'xlsx'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('.csv'),
                    selected: _exportFormat == 'csv',
                    onSelected: (_) => setState(() => _exportFormat = 'csv'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Opção 1: somente modificados
              _ExportOptionCard(
                icon: Icons.edit_note,
                title: 'Somente itens modificados',
                description:
                    'Exporta apenas os $modifiedCount item(ns) alterado(s), '
                    'no mesmo formato do SUAP. Ideal para atualização pontual.',
                badge: modifiedCount > 0 ? '$modifiedCount alterado(s)' : null,
                badgeColor: Colors.orange,
                disabled: _isExporting || modifiedCount == 0,
                onPressed: _exportModified,
              ),
              const SizedBox(height: 12),

              // Opção 2: planilha completa
              _ExportOptionCard(
                icon: Icons.table_chart,
                title: 'Planilha completa',
                description:
                    'Exporta todos os $totalItems item(ns) com uma coluna '
                    '"ATUALIZADO_EM" preenchida apenas onde houve alteração.',
                disabled: _isExporting || totalItems == 0,
                onPressed: _exportFull,
              ),

              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Widgets auxiliares ──────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final int totalItems;
  final int modifiedCount;
  const _StatusCard({required this.totalItems, required this.modifiedCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(label: 'Total importado', value: '$totalItems', icon: Icons.inventory_2),
            _Stat(
              label: 'Modificados',
              value: '$modifiedCount',
              icon: Icons.edit,
              valueColor: modifiedCount > 0 ? Colors.orange : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: valueColor ?? Colors.blueGrey),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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

class _ExportOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? badge;
  final Color? badgeColor;
  final bool disabled;
  final VoidCallback onPressed;

  const _ExportOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.disabled,
    required this.onPressed,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: disabled ? Colors.grey : Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: disabled ? Colors.grey : null,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor ?? Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: disabled ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: disabled ? Colors.grey.shade300 : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
