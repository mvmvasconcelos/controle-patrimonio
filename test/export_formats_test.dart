import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:controle_patrimonio/services/export_formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseCsv lê BOM, aspas, vírgulas e quebras de linha em campos', () {
    final bytes = [
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('a,b\r\n1,"x, ""y""\nz"\r\n'),
    ];
    expect(parseCsv(bytes), [
      ['a', 'b'],
      ['1', 'x, "y"\nz'],
    ]);
  });

  test('encodeCsv escapa e faz round-trip com parseCsv', () {
    final rows = [
      ['n', 'd'],
      ['1', 'Mesa, "grande"'],
    ];
    expect(parseCsv(encodeCsv(rows)), rows);
  });

  test('encodeXlsx gera planilha com as células escapadas', () {
    final bytes = encodeXlsx([
      ['n', 'd'],
      ['1', 'A & B <c>'],
    ]);
    final archive = ZipDecoder().decodeBytes(bytes);
    final sheet = utf8.decode(
        archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(sheet, contains('A &amp; B &lt;c&gt;'));
    expect(sheet, contains('r="B2"'));
    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    expect(archive.findFile('xl/workbook.xml'), isNotNull);
  });

  test('withUpdatedAt preenche ATUALIZADO_EM só nos modificados', () {
    final rows = withUpdatedAt(
      [
        ['numero_patrimonio', 'descricao'],
        ['1', 'a'],
        ['2', 'b'],
      ],
      {'2'},
      '2026-01-02 03:04',
    );
    expect(rows, [
      ['numero_patrimonio', 'descricao', 'ATUALIZADO_EM'],
      ['1', 'a', ''],
      ['2', 'b', '2026-01-02 03:04'],
    ]);
  });
}
