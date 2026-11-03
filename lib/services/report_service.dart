import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/patrimonio.dart';

class ReportService {
  static const _defaultFileName = 'relatorio_patrimonio.xlsx';

  // Colunas da planilha de alterações e suas chaves em modifiedFields
  static const _columns = [
    ('Nº Patrimônio', null),
    ('Descrição', 'descricao'),
    ('Sala', 'sala'),
    ('Responsável', 'responsavel'),
    ('Situação', 'situacao'),
    ('Observações', 'observacoes'),
  ];

  /// Gera o relatório padrão de itens alterados
  static Future<File> generateReport(List<Patrimonio> items) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final sheet = excel['Relatório Alterações'];

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

    return _saveExcelFile(excel, _defaultFileName);
  }

  /// Gera relatório agrupado por Sala ou por Responsável
  static Future<File> generateGroupedReport(
    List<Patrimonio> items, {
    required bool isByRoom,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final groupTitle = isByRoom ? 'Por Sala' : 'Por Responsável';
    final sheet = excel[groupTitle];

    final headers = [
      isByRoom ? 'Sala' : 'Responsável',
      'Nº Patrimônio',
      'Descrição',
      isByRoom ? 'Responsável' : 'Sala',
      'Situação',
      'Observações',
    ];

    // Cabeçalho
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2E7D32'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Ordenar itens pelo grupo
    final sortedItems = List<Patrimonio>.from(items)..sort((a, b) {
      final groupA = isByRoom ? a.sala : a.responsavel;
      final groupB = isByRoom ? b.sala : b.responsavel;
      return groupA.compareTo(groupB);
    });

    for (int rowIdx = 0; rowIdx < sortedItems.length; rowIdx++) {
      final p = sortedItems[rowIdx];
      final row = rowIdx + 1;

      final values = [
        isByRoom ? p.sala : p.responsavel,
        p.numeroPatrimonio,
        p.descricao,
        isByRoom ? p.responsavel : p.sala,
        p.situacao,
        p.observacoes ?? '',
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(values[col]);
      }
    }

    final fileName = isByRoom
        ? 'relatorio_por_sala.xlsx'
        : 'relatorio_por_responsavel.xlsx';
    return _saveExcelFile(excel, fileName);
  }

  /// Gera relatório de itens ausentes/faltantes em uma determinada sala
  static Future<File> generateMissingReport({
    required String sala,
    required List<Patrimonio> missingItems,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final sheet = excel['Faltantes - $sala'];

    final headers = [
      'Nº Patrimônio',
      'Descrição',
      'Sala Cadastrada',
      'Responsável',
      'Situação',
      'Status da Conferência',
    ];

    // Cabeçalho vermelho/alerta
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#C62828'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    for (int rowIdx = 0; rowIdx < missingItems.length; rowIdx++) {
      final p = missingItems[rowIdx];
      final row = rowIdx + 1;

      final values = [
        p.numeroPatrimonio,
        p.descricao,
        p.sala,
        p.responsavel,
        p.situacao,
        'NÃO ENCONTRADO NA CONFERÊNCIA',
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        cell.value = TextCellValue(values[col]);
        if (col == 5) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FFCDD2'),
            fontColorHex: ExcelColor.fromHexString('#B71C1C'),
            bold: true,
          );
        }
      }
    }

    final safeSala = sala.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'relatorio_ausentes_$safeSala.xlsx';
    return _saveExcelFile(excel, fileName);
  }

  /// Helper privado para gravação de arquivos Excel no armazenamento do dispositivo
  static Future<File> _saveExcelFile(Excel excel, String fileName) async {
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

    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    debugPrint('[ReportService] Relatório salvo em: ${file.path}');
    return file;
  }
}
