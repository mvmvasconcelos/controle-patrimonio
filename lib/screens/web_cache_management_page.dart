import 'package:flutter/material.dart';

import '../services/web_inventory_repository.dart';
import '../theme.dart';

class WebCacheManagementPage extends StatefulWidget {
  const WebCacheManagementPage({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final WebInventoryRepository repository;

  /// Chamado após resetar ou limpar, para a lista de Inventário recarregar.
  final VoidCallback? onChanged;

  @override
  State<WebCacheManagementPage> createState() => _WebCacheManagementPageState();
}

class _WebCacheManagementPageState extends State<WebCacheManagementPage> {
  LocalDataStats? _stats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await widget.repository.localDataStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    required Color color,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action),
              ),
            ],
          ),
    );
    return confirmed ?? false;
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
    required String failure,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      widget.onChanged?.call();
      messenger.showSnackBar(
        SnackBar(
          content: Text(success),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$failure: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    await _loadStats();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reset(int modified) async {
    final patrimonyLabel = modified == 1 ? 'patrimônio' : 'patrimônios';
    final ok = await _confirm(
      title: 'Resetar modificações?',
      message:
          'Isso descartará as alterações feitas em $modified $patrimonyLabel '
          'que ainda não foram enviadas ao servidor e restaurará o estado '
          'do servidor.',
      action: 'Resetar',
      color: Colors.orange,
    );
    if (!ok || !mounted) return;
    await _run(
      widget.repository.resetLocalChanges,
      success: 'Modificações resetadas com sucesso',
      failure: 'Erro ao resetar modificações',
    );
  }

  Future<void> _clearAll() async {
    final ok = await _confirm(
      title: 'Limpar tudo?',
      message:
          'Isso apagará o Inventário, as fotos e as alterações ainda '
          'não enviadas guardados neste dispositivo. O servidor não é '
          'alterado.',
      action: 'Limpar',
      color: Colors.red,
    );
    if (!ok || !mounted) return;
    await _run(
      widget.repository.clearLocalData,
      success: 'Todos os dados locais foram limpos',
      failure: 'Erro ao limpar dados',
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final modified = stats?.modified ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Dados e Cache')),
      body: CenteredColumn(
        child:
            stats == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatTile(
                              label: 'Total importado',
                              value: '${stats.total}',
                              icon: Icons.inventory_2,
                            ),
                            _StatTile(
                              label: 'Modificados',
                              value: '$modified',
                              icon: Icons.edit,
                              valueColor: modified > 0 ? Colors.orange : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Ações de risco',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Estas operações removem dados locais e devem ser usadas '
                      'com cuidado.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed:
                          _busy || modified == 0
                              ? null
                              : () => _reset(modified),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Resetar modificações'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _clearAll,
                      icon:
                          _busy
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.delete_sweep),
                      label: Text(_busy ? 'Processando...' : 'Limpar tudo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 28, color: valueColor ?? Colors.blueGrey),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: valueColor,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ],
  );
}
