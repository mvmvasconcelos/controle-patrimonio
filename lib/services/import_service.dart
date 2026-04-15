import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import '../models/patrimonio.dart';

/// Resultado da importação de planilha SUAP.
class ImportResult {
  final List<Patrimonio> patrimonios;
  final List<Map<String, String>> rawRows;
  final int total;
  final int skipped;

  const ImportResult({
    required this.patrimonios,
    required this.rawRows,
    required this.total,
    required this.skipped,
  });
}

class ImportService {
  static Future<ImportResult> importFile(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'csv':
        return _importCsv(file);
      case 'xls':
      case 'xlsx':
        return _importExcel(file);
      default:
        throw UnsupportedError('Formato não suportado: .$ext');
    }
  }

  // ── CSV ────────────────────────────────────────────────
  static Future<ImportResult> _importCsv(File file) async {
    final raw = await file.readAsBytes();
    final content = _decodeBytes(raw);

    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);

    if (rows.isEmpty) throw const FormatException('Arquivo CSV vazio');

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    return _parseRows(headers, rows.skip(1).toList());
  }

  // ── XLS / XLSX ─────────────────────────────────────────
  static Future<ImportResult> _importExcel(File file) async {
    final bytes = await file.readAsBytes();

    // Tentativa 1: pacote excel (suporta XLSX e alguns XLS)
    try {
      final workbook = Excel.decodeBytes(bytes);
      final sheetName = workbook.tables.keys.first;
      final sheet = workbook.tables[sheetName]!;

      if (sheet.rows.isEmpty) throw const FormatException('Planilha vazia');

      final headers = sheet.rows.first
          .map((c) => c?.value?.toString().trim() ?? '')
          .toList();

      final dataRows = sheet.rows.skip(1).map((row) {
        return row.map((c) => c?.value?.toString() ?? '').toList();
      }).toList();

      return _parseRows(headers, dataRows);
    } catch (e) {
      debugPrint('[ImportService] excel falhou: $e — tentando spreadsheet_decoder');
    }

    // Tentativa 2: spreadsheet_decoder (XLSX / ODS)
    try {
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);
      final sheetName = decoder.tables.keys.first;
      final table = decoder.tables[sheetName]!;

      if (table.rows.isEmpty) throw const FormatException('Planilha vazia');

      final headers = table.rows.first
          .map((c) => c?.toString().trim() ?? '')
          .toList();

      final dataRows = table.rows.skip(1).map((row) {
        return row.map((c) => c?.toString() ?? '').toList();
      }).toList();

      return _parseRows(headers, dataRows);
    } catch (e) {
      debugPrint('[ImportService] spreadsheet_decoder falhou: $e — tentando CSV');
    }

    // Tentativa 3: CSV (arquivo .xls que é na verdade texto delimitado)
    try {
      return await _importCsv(file);
    } catch (_) {
      throw const FormatException(
        'Não foi possível ler o arquivo.\n'
        'O formato XLS binário (Excel 97-2003) não é suportado.\n'
        'Salve o arquivo como .xlsx e tente novamente.',
      );
    }
  }

  // ── Parser compartilhado ───────────────────────────────
  static ImportResult _parseRows(
    List<String> headers,
    List<List<dynamic>> rows,
  ) {
    final numeroIdx = _findIndex(headers, 'NUMERO');
    if (numeroIdx == -1) {
      throw const FormatException(
        'Coluna NUMERO não encontrada. Verifique se o arquivo é da exportação do SUAP.',
      );
    }

    final patrimonios = <Patrimonio>[];
    final rawRows = <Map<String, String>>[];
    int skipped = 0;

    for (final row in rows) {
      if (row.length <= 1) {
        skipped++;
        continue;
      }

      final rawRow = <String, String>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        rawRow[headers[i]] = row[i].toString().trim();
      }

      final numero = rawRow['NUMERO'] ?? '';
      if (numero.isEmpty) {
        skipped++;
        continue;
      }

      String getField(String col) =>
          rawRow[col]?.trim() ?? rawRow[_altKey(col)]?.trim() ?? '';

      final patrimonio = Patrimonio(
        numeroPatrimonio: numero,
        descricao: getField('DESCRICAO'),
        sala: getField('SALA'),
        responsavel: getField('CARGA ATUAL'),
        situacao: getField('ESTADO DE CONSERVAÇÃO'),
      );

      patrimonios.add(patrimonio);
      rawRows.add(rawRow);
    }

    debugPrint(
      '[ImportService] Importados: ${patrimonios.length}, ignorados: $skipped',
    );

    return ImportResult(
      patrimonios: patrimonios,
      rawRows: rawRows,
      total: patrimonios.length + skipped,
      skipped: skipped,
    );
  }

  // ── Utilitários ────────────────────────────────────────

  static int _findIndex(List<String> headers, String target) {
    final tNorm = _normalize(target);
    for (int i = 0; i < headers.length; i++) {
      if (_normalize(headers[i]) == tNorm) return i;
    }
    return -1;
  }

  static String _altKey(String col) {
    const alts = {
      'ESTADO DE CONSERVAÇÃO': 'ESTADO DE CONSERVACAO',
      'ESTADO DE CONSERVACAO': 'ESTADO DE CONSERVAÇÃO',
      'NÚMERO DE SÉRIE': 'NUMERO DE SERIE',
    };
    return alts[col] ?? col;
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .trim();

  /// Tenta decodificar em UTF-8, fallback Latin-1 (Windows-1252 compat.).
  static String _decodeBytes(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }
}
