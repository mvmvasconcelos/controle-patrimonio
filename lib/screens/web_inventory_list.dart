import 'dart:async';

import 'package:flutter/material.dart';

import '../services/web_inventory_repository.dart';
import 'web_patrimony_pages.dart';

class WebInventoryList extends StatefulWidget {
  const WebInventoryList({
    super.key,
    required this.repository,
    this.scanBarcode,
    this.pageSize = 50,
  });

  final WebInventoryRepository repository;
  final BarcodeScanner? scanBarcode;
  final int pageSize;

  @override
  State<WebInventoryList> createState() => _WebInventoryListState();
}

class _WebInventoryListState extends State<WebInventoryList> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;
  final List<InventoryEntry> _items = [];
  InventoryFilters _filters = const InventoryFilters(rooms: [], statuses: []);
  int _total = 0;
  String? _room;
  String? _status;
  bool? _checked;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFilters();
    _loadPage(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 400 &&
        !_loading &&
        _hasMore) {
      _loadPage();
    }
  }

  Future<void> _loadFilters() async {
    try {
      final filters = await widget.repository.fetchFilters();
      if (mounted) setState(() => _filters = filters);
    } catch (_) {
      // Filters are optional; list errors are reported by the page load.
    }
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      _generation++;
      _items.clear();
      _hasMore = true;
    }
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.fetchInventory(
        query: _search.text,
        room: _room,
        status: _status,
        checked: _checked,
        offset: _items.length,
        limit: widget.pageSize,
      );
      if (generation != _generation || !mounted) return;
      _items.addAll(page.items);
      _total = page.total;
      _hasMore = page.items.isNotEmpty && _items.length < page.total;
    } catch (error) {
      if (generation != _generation || !mounted) return;
      _error = errorMessage(error);
      _hasMore = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadPage(reset: true);
    });
  }

  void _applyFilters(void Function() change) {
    setState(change);
    _loadPage(reset: true);
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      _loadFilters();
      _loadPage(reset: true);
    }
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<T?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por número ou descrição',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _loadPage(reset: true);
                  },
                ),
              ),
              _dropdown<String>(
                label: 'Sala',
                value: _room,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas as salas')),
                  for (final room in _filters.rooms)
                    DropdownMenuItem(value: room, child: Text(room)),
                ],
                onChanged: (value) => _applyFilters(() => _room = value),
              ),
              _dropdown<String>(
                label: 'Situação',
                value: _status,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Todas as situações')),
                  for (final status in _filters.statuses)
                    DropdownMenuItem(value: status, child: Text(status)),
                ],
                onChanged: (value) => _applyFilters(() => _status = value),
              ),
              _dropdown<bool>(
                label: 'Conferência',
                value: _checked,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(value: true, child: Text('Conferidos')),
                  DropdownMenuItem(value: false, child: Text('Não conferidos')),
                ],
                onChanged: (value) => _applyFilters(() => _checked = value),
              ),
              FilledButton.icon(
                onPressed: () => _open(WebConferenciaPage(
                  repository: widget.repository,
                  scanBarcode: widget.scanBarcode,
                )),
                icon: const Icon(Icons.fact_check),
                label: const Text('Conferir'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _open(WebNewPatrimonyPage(repository: widget.repository)),
                icon: const Icon(Icons.add),
                label: const Text('Novo patrimônio'),
              ),
            ],
          ),
        ),
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(
                onPressed: () => _loadPage(reset: true),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('$_total patrimônios'),
          ),
        ),
        Expanded(
          child: _items.isEmpty && !_loading
              ? const Center(child: Text('Nenhum patrimônio encontrado.'))
              : ListView.separated(
                  controller: _scroll,
                  itemCount: _items.length + (_loading ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final entry = _items[index];
                    return ListTile(
                      title: Text(entry.description),
                      subtitle: Text(
                        '${entry.number} • ${entry.room} • ${entry.responsible}',
                      ),
                      leading: Icon(
                        entry.checked
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: entry.checked ? Colors.green : null,
                        semanticLabel:
                            entry.checked ? 'Conferido' : 'Não conferido',
                      ),
                      trailing: Text(entry.status),
                      onTap: () => _open(WebPatrimonyDetailPage(
                        repository: widget.repository,
                        entry: entry,
                      )),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
