import 'dart:async';

import 'package:flutter/material.dart';

import '../services/offline/sync_status.dart';
import '../services/web_inventory_repository.dart';
import 'web_batch_conferencia_page.dart';
import 'web_patrimony_pages.dart';

/// Tela inicial após o login: resumo da Sincronização e atalhos.
class WebHomePage extends StatefulWidget {
  const WebHomePage({
    super.key,
    required this.repository,
    required this.onOpenInventory,
    this.scanBarcode,
  });

  final WebInventoryRepository repository;
  final VoidCallback onOpenInventory;
  final BarcodeScanner? scanBarcode;

  @override
  State<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends State<WebHomePage> {
  late SyncStatus _status = widget.repository.syncStatus;
  StreamSubscription<SyncStatus>? _subscription;
  int? _itemCount;
  String? _dismissedError;

  @override
  void initState() {
    super.initState();
    _subscription = widget.repository.syncStatusChanges.listen(_onStatus);
    _loadCount();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onStatus(SyncStatus status) {
    final synced = status.lastSyncAt != _status.lastSyncAt;
    setState(() => _status = status);
    if (synced) _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final page = await widget.repository.fetchInventory(limit: 1);
      if (mounted) setState(() => _itemCount = page.total);
    } catch (_) {
      // Sem contagem, o cartão mostra apenas a data.
    }
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  void _open(Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final lastSync = _status.lastSyncAt;
    final count = _itemCount;
    final error = _status.lastError;
    final showError = error != null && error != _dismissedError;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.sync),
                  const SizedBox(width: 8),
                  Text('Última sincronização',
                      style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 8),
                Text(lastSync == null
                    ? 'Nunca sincronizado'
                    : _formatDate(lastSync)),
                if (count != null)
                  Text(count == 1
                      ? '1 item carregado'
                      : '$count itens carregados'),
              ],
            ),
          ),
        ),
        if (showError) _buildFailure(error),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _open(WebConferenciaPage(
            repository: widget.repository,
            scanBarcode: widget.scanBarcode,
          )),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escaneamento Individual'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _open(WebBatchConferenciaPage(
            repository: widget.repository,
            scanBarcode: widget.scanBarcode,
          )),
          icon: const Icon(Icons.view_list),
          label: const Text('Escaneamento em Lotes'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onOpenInventory,
          icon: const Icon(Icons.list_alt),
          label: const Text('Ver Inventário'),
        ),
      ],
    );
  }

  Widget _buildFailure(String error) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Falha na sincronização',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(error),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              TextButton(
                onPressed: () => setState(() => _dismissedError = error),
                child: const Text('Descartar'),
              ),
              FilledButton(
                onPressed: _status.syncing ? null : widget.repository.synchronize,
                child: const Text('Tentar Novamente'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
