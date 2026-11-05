import 'package:flutter/material.dart';

import '../services/web_inventory_repository.dart';
import '../theme.dart';

class WebConferenceReportPage extends StatefulWidget {
  const WebConferenceReportPage({
    super.key,
    required this.repository,
  });

  final WebInventoryRepository repository;

  @override
  State<WebConferenceReportPage> createState() =>
      _WebConferenceReportPageState();
}

class _WebConferenceReportPageState extends State<WebConferenceReportPage> {
  InventoryFilters _filters = const InventoryFilters(rooms: [], statuses: []);
  ConferenceReport? _report;
  String? _room;
  String? _situation;
  String? _error;
  bool _loading = true;
  List<ChangedItem>? _changeItems;
  String? _changesError;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadReport();
    _loadChanges();
  }

  Future<void> _loadChanges() async {
    try {
      final changes = await widget.repository.fetchChanges();
      if (mounted) setState(() => _changeItems = changes);
    } catch (error) {
      if (mounted) setState(() => _changesError = _message(error));
    }
  }

  Future<void> _loadFilters() async {
    try {
      final filters = await widget.repository.fetchFilters();
      if (mounted) setState(() => _filters = filters);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _loadReport() async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.repository.fetchConferenceReport(
        room: _room,
        situation: _situation,
      );
      if (generation == _requestGeneration && mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (error) {
      if (generation == _requestGeneration && mounted) {
        setState(() {
          _error = _message(error);
          _loading = false;
        });
      }
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Widget _roomFilter() => SizedBox(
        width: 240,
        child: DropdownButtonFormField<String?>(
          value: _room,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Sala',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todas as salas'),
            ),
            for (final room in _filters.rooms)
              DropdownMenuItem<String?>(value: room, child: Text(room)),
          ],
          onChanged: (value) {
            setState(() => _room = value);
            _loadReport();
          },
        ),
      );

  Widget _situationFilter() => SizedBox(
        width: 240,
        child: DropdownButtonFormField<String?>(
          value: _situation,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Situação patrimonial',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todas as situações'),
            ),
            for (final situation in _filters.statuses)
              DropdownMenuItem<String?>(
                value: situation,
                child: Text(situation),
              ),
          ],
          onChanged: (value) {
            setState(() => _situation = value);
            _loadReport();
          },
        ),
      );

  Widget _totals(ConferenceReport report) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _ReportStat(
                  icon: Icons.inventory_2,
                  label: 'Total',
                  value: report.total,
                ),
              ),
              Expanded(
                child: _ReportStat(
                  icon: Icons.check_circle,
                  label: 'Conferidos',
                  value: report.checked,
                ),
              ),
              Expanded(
                child: _ReportStat(
                  icon: Icons.pending_actions,
                  label: 'Pendentes',
                  value: report.pending,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _changes() {
    final changes = _changeItems;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_note, color: primary),
            const SizedBox(width: 8),
            Text(
              'Patrimônios modificados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_changesError != null)
          Text(
            _changesError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (changes == null)
          const LinearProgressIndicator()
        else if (changes.isEmpty)
          const Text('Nenhum patrimônio modificado.')
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final item in changes)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber.shade100,
                      child:
                          const Icon(Icons.edit, color: Colors.amber, size: 18),
                    ),
                    title: Text('${item.number} · ${item.description}'),
                    subtitle: Text(item.room),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        if (item.checked)
                          Icon(Icons.check_circle, color: primary, size: 20),
                        if (item.photos > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_camera, size: 18),
                              Text(' ${item.photos}'),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _groups(ConferenceReport report) {
    if (report.groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child:
            Text('Nenhum patrimônio encontrado para os filtros selecionados.'),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Sala')),
            DataColumn(label: Text('Situação patrimonial')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Conferidos')),
            DataColumn(label: Text('Pendentes')),
          ],
          rows: [
            for (final group in report.groups)
              DataRow(
                cells: [
                  DataCell(Text(group.room)),
                  DataCell(Text(group.situation)),
                  DataCell(Text('${group.total}')),
                  DataCell(Text('${group.checked}')),
                  DataCell(Text('${group.pending}')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de alterações')),
      body: CenteredColumn(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [_roomFilter(), _situationFilter()],
              ),
              const SizedBox(height: 20),
              if (_error != null)
                MaterialBanner(
                  content: Text(_error!),
                  actions: [
                    TextButton(
                      onPressed: _loadReport,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              if (_loading && report == null)
                const Center(child: CircularProgressIndicator())
              else if (report != null) ...[
                _totals(report),
                const SizedBox(height: 12),
                if (_loading) const LinearProgressIndicator(),
                _groups(report),
              ],
              const SizedBox(height: 24),
              _changes(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Icon(icon, color: tint),
        const SizedBox(height: 4),
        Text(
          '$value',
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
