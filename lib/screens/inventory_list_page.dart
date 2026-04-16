import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patrimonio.dart';
import '../providers/patrimonio_provider.dart';
import '../widgets/scanned_item_modal.dart';

class InventoryListPage extends StatefulWidget {
  final bool initialOnlyModified;

  const InventoryListPage({super.key, this.initialOnlyModified = false});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _filterSala;
  bool _onlyModified = false;

  @override
  void initState() {
    super.initState();
    _onlyModified = widget.initialOnlyModified;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Patrimonio> _apply(List<Patrimonio> all) {
    var result = all;

    if (_onlyModified) {
      result = result.where((p) => p.isModified).toList();
    }

    if (_filterSala != null) {
      result = result.where((p) => p.sala == _filterSala).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result
          .where(
            (p) =>
                p.numeroPatrimonio.toLowerCase().contains(q) ||
                p.descricao.toLowerCase().contains(q) ||
                p.sala.toLowerCase().contains(q) ||
                p.responsavel.toLowerCase().contains(q),
          )
          .toList();
    }

    return result;
  }

  void _showFilterSheet(BuildContext context, List<String> salas) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtros',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Apenas modificados'),
                value: _onlyModified,
                onChanged: (v) {
                  setLocal(() {});
                  setState(() => _onlyModified = v);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Sala:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('Todas'),
                    selected: _filterSala == null,
                    onSelected: (_) {
                      setLocal(() {});
                      setState(() => _filterSala = null);
                    },
                  ),
                  ...salas.map(
                    (s) => FilterChip(
                      label: Text(s, overflow: TextOverflow.ellipsis),
                      selected: _filterSala == s,
                      onSelected: (_) {
                        setLocal(() {});
                        setState(() => _filterSala = _filterSala == s ? null : s);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _editItem(BuildContext context, Patrimonio patrimonio) {
    final provider = context.read<PatrimonioProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScannedItemModal(
        patrimonio: patrimonio,
        selectedSala: null,
        onSave: (updated) {
          final changes = <String, dynamic>{};
          if (patrimonio.descricao != updated.descricao)
            changes['descricao'] = updated.descricao;
          if (patrimonio.sala != updated.sala) changes['sala'] = updated.sala;
          if (patrimonio.responsavel != updated.responsavel)
            changes['responsavel'] = updated.responsavel;
          if (patrimonio.situacao != updated.situacao)
            changes['situacao'] = updated.situacao;
          if (patrimonio.observacoes != updated.observacoes)
            changes['observacoes'] = updated.observacoes;
          if (changes.isNotEmpty)
            provider.updatePatrimonio(patrimonio, changes);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventário'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          Consumer<PatrimonioProvider>(
            builder: (context, provider, _) {
              final salas = provider.patrimonios
                  .map((p) => p.sala)
                  .where((sala) => sala.trim().isNotEmpty)
                  .toSet()
                  .toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              final hasFilter = _onlyModified || _filterSala != null;
              return IconButton(
                icon: Badge(
                  isLabelVisible: hasFilter,
                  child: const Icon(Icons.filter_list),
                ),
                tooltip: 'Filtros',
                onPressed: () => _showFilterSheet(context, salas),
              );
            },
          ),
        ],
      ),
      body: Consumer<PatrimonioProvider>(
        builder: (context, provider, _) {
          final all = provider.patrimonios;

          if (all.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum dado importado.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Importe uma planilha do SUAP\npara ver o inventário aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final filtered = _apply(all);

          return Column(
            children: [
              // Barra de busca
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nº, descrição, sala ou responsável...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),

              // Linha de resumo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} de ${all.length} itens',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (_onlyModified || _filterSala != null) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '• filtros ativos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Lista
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nenhum item encontrado.'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          return _ItemTile(
                            patrimonio: p,
                            onTap: () => _editItem(context, p),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Patrimonio patrimonio;
  final VoidCallback? onTap;

  const _ItemTile({required this.patrimonio, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = patrimonio;
    final modifiedFields = p.modifiedFields?.keys.toList() ?? [];

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: p.isModified
            ? Colors.amber.shade100
            : Colors.blue.shade50,
        child: Icon(
          p.isModified ? Icons.edit : Icons.inventory_2,
          size: 18,
          color: p.isModified ? Colors.orange : Colors.blue,
        ),
      ),
      title: Text(
        p.numeroPatrimonio,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.descricao,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            p.sala,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (modifiedFields.isNotEmpty)
            Text(
              'Modificado: ${modifiedFields.join(', ')}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      isThreeLine: modifiedFields.isNotEmpty,
      trailing: Text(
        p.situacao,
        style: TextStyle(
          fontSize: 11,
          color: p.situacao.toLowerCase() == 'bom' ||
                  p.situacao.toLowerCase() == 'ativo'
              ? Colors.green
              : Colors.grey,
        ),
      ),
    );
  }
}
