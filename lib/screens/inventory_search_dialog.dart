import 'package:flutter/material.dart';

import '../services/web_inventory_repository.dart';

Future<InventoryEntry?> showInventorySearchDialog({
  required BuildContext context,
  required WebInventoryRepository repository,
  String initialQuery = '',
}) =>
    showDialog<InventoryEntry>(
      context: context,
      builder: (_) => _InventorySearchDialog(
        repository: repository,
        initialQuery: initialQuery,
      ),
    );

class _InventorySearchDialog extends StatefulWidget {
  const _InventorySearchDialog({
    required this.repository,
    required this.initialQuery,
  });

  final WebInventoryRepository repository;
  final String initialQuery;

  @override
  State<_InventorySearchDialog> createState() => _InventorySearchDialogState();
}

class _InventorySearchDialogState extends State<_InventorySearchDialog> {
  late final _query = TextEditingController(text: widget.initialQuery);
  List<InventoryEntry> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _error = 'Informe um número ou descrição para buscar.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
    });
    try {
      final page = await widget.repository.fetchInventory(
        query: query,
        limit: 50,
      );
      if (mounted) setState(() => _results = page.items);
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Buscar Patrimônio'),
        content: SizedBox(
          width: 520,
          height: 360,
          child: Column(
            children: [
              TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Número ou descrição',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? const Center(
                            child: Text('Nenhum Patrimônio encontrado.'),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final entry = _results[index];
                              return ListTile(
                                title: Text(
                                    '${entry.number} · ${entry.description}'),
                                subtitle: Text(entry.room.isEmpty
                                    ? 'Sala não informada'
                                    : 'Sala: ${entry.room}'),
                                onTap: () => Navigator.of(context).pop(entry),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      );
}
