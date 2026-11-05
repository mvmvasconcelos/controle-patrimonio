import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

enum ExportFormat { xlsx, csv }

/// Lê o CSV do servidor (UTF-8, com ou sem BOM) em linhas de células.
List<List<String>> parseCsv(List<int> bytes) {
  var data = bytes;
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    data = data.sublist(3);
  }
  final text = utf8.decode(data);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var touched = false;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
    touched = false;
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(char);
      }
    } else if (char == '"') {
      quoted = true;
      touched = true;
    } else if (char == ',') {
      endCell();
      touched = true;
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(char);
      touched = true;
    }
  }
  if (touched) endRow();
  return rows;
}

Uint8List encodeCsv(List<List<String>> rows) {
  String escape(String value) => value.contains(RegExp('[",\r\n]'))
      ? '"${value.replaceAll('"', '""')}"'
      : value;
  final text = rows.map((row) => row.map(escape).join(',')).join('\r\n');
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$text\r\n')]);
}

/// Acrescenta ATUALIZADO_EM, preenchida só nas linhas cujo número consta em
/// [modified]. A primeira coluna é o número do patrimônio.
List<List<String>> withUpdatedAt(
  List<List<String>> rows,
  Set<String> modified,
  String stamp,
) {
  if (rows.isEmpty) return rows;
  return [
    [...rows.first, 'ATUALIZADO_EM'],
    for (final row in rows.skip(1))
      [...row, modified.contains(row.first) ? stamp : ''],
  ];
}

String _columnName(int index) {
  var name = '';
  for (var n = index + 1; n > 0; n = (n - 1) ~/ 26) {
    name = String.fromCharCode(65 + (n - 1) % 26) + name;
  }
  return name;
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');

/// Gera um .xlsx mínimo (uma aba, todas as células como texto).
Uint8List encodeXlsx(List<List<String>> rows) {
  final sheet = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<sheetData>',
  );
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      sheet.write('<c r="${_columnName(c)}${r + 1}" t="inlineStr">'
          '<is><t xml:space="preserve">${_xml(rows[r][c])}</t></is></c>');
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');

  const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '</Types>';
  const rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';
  const workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Inventario" sheetId="1" r:id="rId1"/></sheets></workbook>';
  const workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '</Relationships>';

  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', contentTypes);
  add('_rels/.rels', rootRels);
  add('xl/workbook.xml', workbook);
  add('xl/_rels/workbook.xml.rels', workbookRels);
  add('xl/worksheets/sheet1.xml', sheet.toString());
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
