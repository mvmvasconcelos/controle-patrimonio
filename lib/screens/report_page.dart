import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../models/patrimonio.dart';
import '../providers/patrimonio_provider.dart';
import '../services/report_service.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  bool _isGenerating = false;
  String? _selectedRoomForMissing;

  Future<void> _generateAndOpen(Future<dynamic> Function() generateFn) async {
    setState(() => _isGenerating = true);
    try {
      final file = await generateFn();
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar relatório: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relatórios Patrimoniais'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Alterações'),
              Tab(icon: Icon(Icons.corporate_fare), text: 'Agrupados'),
              Tab(icon: Icon(Icons.running_with_errors), text: 'Ausentes'),
            ],
          ),
        ),
        body: Consumer<PatrimonioProvider>(
          builder: (context, provider, _) {
            final allItems = provider.patrimonios;
            final modified = allItems.where((p) => p.isModified).toList();
            final rooms = provider.getSalasUnicas();

            return TabBarView(
              children: [
                // --- ABA 1: ALTERAÇÕES ---
                _buildModifiedTab(context, modified),

                // --- ABA 2: AGRUPADOS (SALA / RESPONSÁVEL) ---
                _buildGroupedTab(context, allItems),

                // --- ABA 3: ITENS AUSENTES ---
                _buildMissingTab(context, allItems, rooms),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Aba 1: Exibe os itens alterados no inventário
  Widget _buildModifiedTab(BuildContext context, List<Patrimonio> modified) {
    if (modified.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Nenhuma alteração registrada.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Escaneie e edite itens para que\napareçam no relatório de alterações.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.edit_note,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                '${modified.length} ${modified.length == 1 ? 'item alterado' : 'itens alterados'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: modified.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = modified[index];
              final fields = p.modifiedFields ?? {};
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: const Icon(Icons.edit, color: Colors.amber, size: 18),
                ),
                title: Text(
                  p.numeroPatrimonio,
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                    if (fields.isNotEmpty)
                      Text(
                        'Campos: ${fields.keys.join(', ')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
                isThreeLine: fields.isNotEmpty,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isGenerating
                ? null
                : () => _generateAndOpen(() => ReportService.generateReport(modified)),
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart),
            label: Text(
              _isGenerating ? 'Gerando planilha...' : 'Gerar Planilha SUAP (.xlsx)',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Aba 2: Exibe relatórios agrupados por Sala e por Responsável
  Widget _buildGroupedTab(BuildContext context, List<Patrimonio> allItems) {
    if (allItems.isEmpty) {
      return const Center(child: Text('Nenhum patrimônio cadastrado.'));
    }

    final salasMap = <String, int>{};
    final respMap = <String, int>{};

    for (final item in allItems) {
      salasMap[item.sala] = (salasMap[item.sala] ?? 0) + 1;
      respMap[item.responsavel] = (respMap[item.responsavel] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Informativo
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.analytics_outlined, size: 40, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    'Consolidação de Inventário',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricTile('Salas', '${salasMap.length}', Icons.meeting_room),
                      _buildMetricTile('Responsáveis', '${respMap.length}', Icons.person),
                      _buildMetricTile('Total Itens', '${allItems.length}', Icons.inventory_2),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Botões de Exportação
          ElevatedButton.icon(
            onPressed: _isGenerating
                ? null
                : () => _generateAndOpen(
                      () => ReportService.generateGroupedReport(allItems, isByRoom: true),
                    ),
            icon: const Icon(Icons.meeting_room),
            label: const Text('Exportar Relatório por Sala (.xlsx)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isGenerating
                ? null
                : () => _generateAndOpen(
                      () => ReportService.generateGroupedReport(allItems, isByRoom: false),
                    ),
            icon: const Icon(Icons.person_pin),
            label: const Text('Exportar Relatório por Responsável (.xlsx)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Aba 3: Exibe relatório de itens faltantes / ausentes por sala
  Widget _buildMissingTab(
    BuildContext context,
    List<Patrimonio> allItems,
    List<String> rooms,
  ) {
    if (rooms.isEmpty) {
      return const Center(child: Text('Nenhuma sala disponível no inventário.'));
    }

    _selectedRoomForMissing ??= rooms.first;

    final salaItems = allItems.where((p) => p.sala == _selectedRoomForMissing).toList();
    final missingItems = salaItems.where((p) => !p.isModified).toList();

    return Column(
      children: [
        // Seletor de Sala
        Container(
          color: Colors.red.shade50,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecione a Sala para verificar pendências:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedRoomForMissing,
                    items: rooms
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text('Sala: $r'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRoomForMissing = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Resumo de ausentes
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.red.shade100,
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${missingItems.length} de ${salaItems.length} itens não conferidos nesta sala.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista de ausentes
        Expanded(
          child: missingItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, size: 64, color: Colors.green),
                      SizedBox(height: 12),
                      Text(
                        'Todos os itens desta sala foram conferidos!',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: missingItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = missingItems[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.question_mark, color: Colors.white, size: 18),
                      ),
                      title: Text(
                        item.numeroPatrimonio,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item.descricao}\nResp: ${item.responsavel}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),

        // Botão Exportar Faltantes
        if (missingItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isGenerating
                  ? null
                  : () => _generateAndOpen(
                        () => ReportService.generateMissingReport(
                          sala: _selectedRoomForMissing!,
                          missingItems: missingItems,
                        ),
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exportar Relatório de Ausentes (.xlsx)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
