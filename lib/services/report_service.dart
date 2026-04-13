import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/patrimonio.dart';

class ReportService {
  static const _fileName = 'relatorio_patrimonio.xlsx';

  // Colunas da planilha e suas chaves em modifiedFields
  static const _columns = [
    ('Nº Patrimônio', null),
    ('Descrição', 'descricao'),
    ('Sala', 'sala'),
    ('Responsável', 'responsavel'),
    ('Situação', 'situacao'),
    ('Observações', 'observacoes'),
  ];

  static Future<File> generateReport(List<Patrimonio> items) async {
    final excel = Excel.createExcel();

    // Remover a aba padrão criada automaticamente
    excel.delete('Sheet1');

    final sheet = excel['Relatório'];

    // --- Linha de cabeçalho ---
    for (int col = 0; col < _columns.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(_columns[col].$1);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // --- Linhas de dados ---
    for (int rowIdx = 0; rowIdx < items.length; rowIdx++) {
      final p = items[rowIdx];
      final row = rowIdx + 1;

      final values = [
        p.numeroPatrimonio,
        p.descricao,
        p.sala,
        p.responsavel,
        p.situacao,
        p.observacoes ?? '',
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(values[col]);

        final fieldKey = _columns[col].$2;
        final wasModified =
            fieldKey != null &&
            (p.modifiedFields?.containsKey(fieldKey) ?? false);

        if (wasModified) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FFF176'),
          );
        }
      }
    }

    // --- Salvar arquivo ---
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Falha ao codificar a planilha');
    }

    Directory? dir;
    try {
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      }
    } catch (e) {
      debugPrint('[ReportService] Erro ao obter diretório externo: $e');
    }
    dir ??= await getTemporaryDirectory();

    final file = File('${dir.path}/$_fileName');
    await file.writeAsBytes(bytes);

    debugPrint('[ReportService] Relatório salvo em: ${file.path}');
    return file;
  }
}
