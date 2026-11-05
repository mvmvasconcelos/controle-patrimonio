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
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadReport();
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

  Widget _totals(ConferenceReport report) => Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          Text('Total: ${report.total}'),
          Text('Conferidos: ${report.checked}'),
          Text('Pendentes: ${report.pending}'),
        ],
      );

  Widget _groups(ConferenceReport report) {
    if (report.groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child:
            Text('Nenhum patrimônio encontrado para os filtros selecionados.'),
      );
    }
    return SingleChildScrollView(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de conferência')),
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
            ],
          ),
        ),
      ),
    );
  }
}
