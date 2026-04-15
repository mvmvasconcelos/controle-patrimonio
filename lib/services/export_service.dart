import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../database/hive_database.dart';
import '../models/patrimonio.dart';

/// Colunas originais do SUAP, na ordem correta.
const _suapHeaders = [
  '#',
  'NUMERO',
  'STATUS',
  'ED',
  'DESCRICAO',
  'RÓTULOS',
  'CARGA ATUAL',
  'SETOR DO RESPONSÁVEL',
  'CAMPUS DA CARGA',
  'VALOR AQUISIÇÃO',
  'VALOR DEPRECIADO',
  'NUMERO NOTA FISCAL',
  'NÚMERO DE SÉRIE',
  'DATA DA ENTRADA',
  'DATA DA CARGA',
  'FORNECEDOR',
  'SALA',
  'ESTADO DE CONSERVAÇÃO',
];

/// Mapeamento: coluna SUAP → campo editável no app.
const _editableColMap = {
  'DESCRICAO': 'descricao',
  'SALA': 'sala',
  'CARGA ATUAL': 'responsavel',
  'ESTADO DE CONSERVAÇÃO': 'situacao',
};

class ExportService {
  static final _dateFormatter = DateFormat('dd-MM-yyyy');

  // ── Exportação 1: apenas itens modificados ─────────────
  static Future<File> exportModifiedOnly(
    List<Patrimonio> modified,
    String format, // 'xlsx' | 'csv'
  ) async {
    final rows = _buildRows(modified, includeUpdatedAt: false);
    return _save(rows, _suapHeaders, 'modificados', format);
  }

  // ── Exportação 2: todos os itens + coluna atualizado_em ─
  static Future<File> exportFull(
    List<Patrimonio> all,
    String format, // 'xlsx' | 'csv'
  ) async {
    final headers = [..._suapHeaders, 'ATUALIZADO_EM'];
    final rows = _buildRows(all, includeUpdatedAt: true);
    return _save(rows, headers, 'completo', format);
  }

  // ── Builder de linhas ──────────────────────────────────
  static List<Map<String, String>> _buildRows(
    List<Patrimonio> items, {
    required bool includeUpdatedAt,
  }) {
    return items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final p = entry.value;
      final raw = HiveDatabase.getRawRow(p.numeroPatrimonio) ?? {};

      // Começar com dados brutos originais
      final row = Map<String, String>.from(raw);

      // Garantir que o campo # tenha a sequência correta
      row['#'] = '$idx';

      // Sobrescrever com valores atuais do app (editáveis)
      row['NUMERO'] = p.numeroPatrimonio;
      row['DESCRICAO'] = p.descricao;
      row['SALA'] = p.sala;
      row['CARGA ATUAL'] = p.responsavel;
      row['ESTADO DE CONSERVAÇÃO'] = p.situacao;

      // Marcar colunas modificadas para highlight no xlsx
      _editableColMap.forEach((suapCol, fieldKey) {
        if (p.modifiedFields?.containsKey(fieldKey) == true) {
          row['__modified_$suapCol'] = 'true';
        }
      });

      if (includeUpdatedAt) {
        row['ATUALIZADO_EM'] = p.isModified
            ? _dateFormatter.format(DateTime.now())
            : '';
      }

      return row;
    }).toList();
  }

  // ── Salvar arquivo ─────────────────────────────────────
  static Future<File> _save(
    List<Map<String, String>> rows,
    List<String> headers,
    String suffix,
    String format,
  ) async {
    final dir = await _getDir();
    if (format == 'csv') {
      return _saveCsv(rows, headers, dir, suffix);
    } else {
      return _saveXlsx(rows, headers, dir, suffix);
    }
  }

  static Future<File> _saveCsv(
    List<Map<String, String>> rows,
    List<String> headers,
    Directory dir,
    String suffix,
  ) async {
    final data = <List<String>>[
      headers,
      ...rows.map((r) => headers.map((h) => r[h] ?? '').toList()),
    ];
    final content = const ListToCsvConverter().convert(data);
    final file = File('${dir.path}/relatorio_$suffix.csv');
    await file.writeAsString(content, encoding: utf8);
    debugPrint('[ExportService] CSV salvo: ${file.path}');
    return file;
  }

  static Future<File> _saveXlsx(
    List<Map<String, String>> rows,
    List<String> headers,
    Directory dir,
    String suffix,
  ) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'Relatório') {
      excel.rename(defaultSheet, 'Relatório');
    }

    // Garante que o arquivo final tenha somente uma aba.
    final extraSheets = List<String>.from(excel.tables.keys)
        .where((name) => name != 'Relatório')
        .toList();
    for (final name in extraSheets) {
      excel.delete(name);
    }

    final sheet = excel['Relatório'];

    // Cabeçalho
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Dados
    for (int rowIdx = 0; rowIdx < rows.length; rowIdx++) {
      final r = rows[rowIdx];
      for (int col = 0; col < headers.length; col++) {
        final h = headers[col];
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx + 1),
        );
        final value = r[h] ?? '';
        cell.value = TextCellValue(value);

        // Destacar células com campos modificados
        final isHighlighted = r['__modified_$h'] == 'true';
        if (isHighlighted) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FFF176'),
          );
        }
      }
    }

    final bytes = excel.encode()!;
    final file = File('${dir.path}/relatorio_$suffix.xlsx');
    await file.writeAsBytes(bytes);
    debugPrint('[ExportService] XLSX salvo: ${file.path}');
    return file;
  }

  static Future<Directory> _getDir() async {
    Directory? dir;
    try {
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      }
    } catch (e) {
      debugPrint('[ExportService] Erro ao obter dir externo: $e');
    }
    return dir ?? await getTemporaryDirectory();
  }
}
