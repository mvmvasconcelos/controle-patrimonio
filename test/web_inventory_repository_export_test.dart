import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:controle_patrimonio/services/export_formats.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _header = 'numero_patrimonio,descricao,sala,responsavel,situacao,'
    'observacoes,conferido,fotos';

WebInventoryRepository _repository() => WebInventoryRepository(
      apiBaseUrl: Uri.parse('https://host/api/v1/'),
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/patrimonio')) {
          return http.Response(jsonEncode({'total': 3, 'items': []}), 200);
        }
        if (path.endsWith('/exportar/alteracoes')) {
          return http.Response(
              '$_header\r\n101,Mesa,Sala A,Ana,Ativo,,Sim,0\r\n', 200);
        }
        if (path.endsWith('/exportar/relatorio')) {
          return http.Response.bytes(
              utf8.encode('$_header\r\n100,Mesa,Sala A,Ana,Ativo,,Não,0\r\n'
                  '101,Mesa,Sala A,Ana,Ativo,,Sim,0\r\n'),
              200);
        }
        return http.Response('', 404);
      }),
    );

void main() {
  test('fetchTotals conta o importado e os modificados', () async {
    final totals = await _repository().fetchTotals();
    expect(totals.total, 3);
    expect(totals.modified, 1);
  });

  test('exportSpreadsheet em csv só com modificados', () async {
    final file = await _repository().exportSpreadsheet(
      format: ExportFormat.csv,
      onlyModified: true,
    );
    expect(file.filename, 'alteracoes.csv');
    expect(parseCsv(file.bytes).length, 2);
  });

  test('exportSpreadsheet completa traz ATUALIZADO_EM só nos modificados',
      () async {
    final file = await _repository().exportSpreadsheet(
      format: ExportFormat.csv,
      onlyModified: false,
      now: DateTime(2026, 1, 2, 3, 4),
    );
    expect(file.filename, 'planilha_completa.csv');
    final rows = parseCsv(file.bytes);
    expect(rows.first.last, 'ATUALIZADO_EM');
    expect(rows[1].last, '');
    expect(rows[2].last, '2026-01-02 03:04');
  });

  test('exportSpreadsheet em xlsx gera um arquivo zip válido', () async {
    final file = await _repository().exportSpreadsheet(
      format: ExportFormat.xlsx,
      onlyModified: true,
    );
    expect(file.filename, 'alteracoes.xlsx');
    final archive = ZipDecoder().decodeBytes(file.bytes);
    expect(archive.findFile('xl/worksheets/sheet1.xml'), isNotNull);
  });
}
