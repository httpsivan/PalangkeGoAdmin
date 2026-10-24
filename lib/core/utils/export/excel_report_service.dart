import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'admin_export_models.dart';

class ExcelReportService {
  ExcelReportService._();

  static final DateFormat _dateFormat = DateFormat('MMMM d, yyyy, h:mm a');

  static Uint8List generateExcel(ExportDocument doc) {
    final sheetXml = _buildWorksheetXml(doc);
    final stylesXml = _buildStylesXml();

    final entries = <_ZipEntry>[
      _ZipEntry(
        '[Content_Types].xml',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''',
      ),
      _ZipEntry(
        '_rels/.rels',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''',
      ),
      _ZipEntry(
        'xl/workbook.xml',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${_xml(_sanitizeSheetName(doc.reportName))}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''',
      ),
      _ZipEntry(
        'xl/_rels/workbook.xml.rels',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''',
      ),
      _ZipEntry('xl/styles.xml', stylesXml),
      _ZipEntry('xl/worksheets/sheet1.xml', sheetXml),
    ];

    return _zip(entries);
  }

  static String _buildStylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="5">
    <font><name val="Calibri"/><sz val="11"/></font>
    <font><b/><name val="Calibri"/><sz val="11"/></font>
    <font><b/><color rgb="FFFFFFFF"/><name val="Calibri"/><sz val="11"/></font>
    <font><b/><color rgb="FF0B372B"/><name val="Calibri"/><sz val="14"/></font>
    <font><b/><color rgb="FF064E3B"/><name val="Calibri"/><sz val="11"/></font>
  </fonts>
  <fills count="6">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF0B372B"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFECFDF5"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFA7F3D0"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFF8FAFC"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/></border>
    <border>
      <left style="thin"><color rgb="FFCBD5E1"/></left>
      <right style="thin"><color rgb="FFCBD5E1"/></right>
      <top style="thin"><color rgb="FFCBD5E1"/></top>
      <bottom style="thin"><color rgb="FFCBD5E1"/></bottom>
    </border>
  </borders>
  <cellXfs count="9">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    <xf numFmtId="0" fontId="4" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
    <xf numFmtId="0" fontId="0" fillId="5" borderId="1" xfId="0" applyFill="1" applyBorder="1"/>
    <xf numFmtId="1" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>
  </cellXfs>
</styleSheet>''';
  }

  static String _buildWorksheetXml(ExportDocument doc) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );

    // Dynamic row index tracking
    var currentRow = 1;

    // We will freeze header row once we know its row index
    // Header section:
    // Row 1: PalengkeGo - [Report Name]
    // Row 2: Export Date: [date]
    // Row 3: Date Range / Filters: ...
    // Row 4: empty
    // Row 5: SUMMARY header
    // Row 6..X: Summary items
    // Row X+1: empty
    // Row X+2: Table header (Frozen row)

    final summaryStartRow = 5;
    final summaryEndRow = summaryStartRow + doc.summary.items.length;
    final tableHeaderRow = summaryEndRow + 2;

    // Frozen pane at table header
    buffer.writeln('<sheetViews>');
    buffer.writeln(
      '<sheetView workbookViewId="0">'
      '<pane ySplit="$tableHeaderRow" topLeftCell="A${tableHeaderRow + 1}" activePane="bottomLeft" state="frozen"/>'
      '</sheetView>',
    );
    buffer.writeln('</sheetViews>');

    // Column widths
    buffer.writeln('<cols>');
    for (var colIdx = 0; colIdx < doc.table.columns.length; colIdx++) {
      final col = doc.table.columns[colIdx];
      final colWidth = (col.flex * 20.0).clamp(16.0, 42.0);
      final colNum = colIdx + 1;
      buffer.writeln(
        '<col min="$colNum" max="$colNum" width="$colWidth" customWidth="1"/>',
      );
    }
    buffer.writeln('</cols>');

    buffer.writeln('<sheetData>');

    // Row 1: Title
    buffer.writeln('<row r="1">');
    buffer.writeln(
      '<c r="A1" s="1" t="inlineStr"><is><t>${_xml('PalengkeGo - ${doc.header.reportTitle}')}</t></is></c>',
    );
    buffer.writeln('</row>');

    // Row 2: Export Date
    buffer.writeln('<row r="2">');
    buffer.writeln(
      '<c r="A2" s="2" t="inlineStr"><is><t>${_xml('Export Date: ${_dateFormat.format(doc.header.exportDate)}')}</t></is></c>',
    );
    buffer.writeln('</row>');

    // Row 3: Date Range / Filters
    final dateRangePart =
        doc.header.dateRange != null && doc.header.dateRange!.isNotEmpty
            ? 'Date Range: ${doc.header.dateRange} | '
            : '';
    final filterString = '$dateRangePart${doc.header.activeFilters}';
    buffer.writeln('<row r="3">');
    buffer.writeln(
      '<c r="A3" s="2" t="inlineStr"><is><t>${_xml('Filters: $filterString')}</t></is></c>',
    );
    buffer.writeln('</row>');

    // Row 4: Empty spacer
    buffer.writeln('<row r="4"/>');

    // Row 5: SUMMARY Header
    buffer.writeln('<row r="5">');
    buffer.writeln(
      '<c r="A5" s="3" t="inlineStr"><is><t>SUMMARY</t></is></c>',
    );
    buffer.writeln(
      '<c r="B5" s="3" t="inlineStr"><is><t>COUNT / VALUE</t></is></c>',
    );
    buffer.writeln('</row>');

    // Summary items
    currentRow = 6;
    for (final item in doc.summary.items) {
      buffer.writeln('<row r="$currentRow">');
      buffer.writeln(
        '<c r="A$currentRow" s="4" t="inlineStr"><is><t>${_xml(item.label)}</t></is></c>',
      );
      final numVal = num.tryParse(item.value.replaceAll(',', ''));
      if (numVal != null) {
        buffer.writeln('<c r="B$currentRow" s="4"><v>$numVal</v></c>');
      } else {
        buffer.writeln(
          '<c r="B$currentRow" s="4" t="inlineStr"><is><t>${_xml(item.value)}</t></is></c>',
        );
      }
      buffer.writeln('</row>');
      currentRow++;
    }

    // Spacer row
    buffer.writeln('<row r="$currentRow"/>');
    currentRow++;

    // Table Header Row
    buffer.writeln('<row r="$currentRow">');
    for (var colIdx = 0; colIdx < doc.table.columns.length; colIdx++) {
      final col = doc.table.columns[colIdx];
      final cellRef = '${_columnName(colIdx)}$currentRow';
      buffer.writeln(
        '<c r="$cellRef" s="5" t="inlineStr"><is><t>${_xml(col.label)}</t></is></c>',
      );
    }
    buffer.writeln('</row>');
    currentRow++;

    // Data Rows
    for (var rowIdx = 0; rowIdx < doc.table.rows.length; rowIdx++) {
      final row = doc.table.rows[rowIdx];
      final styleId = rowIdx % 2 == 1 ? 7 : 6;

      buffer.writeln('<row r="$currentRow">');
      for (var colIdx = 0; colIdx < doc.table.columns.length; colIdx++) {
        final col = doc.table.columns[colIdx];
        final cellRef = '${_columnName(colIdx)}$currentRow';
        final val = colIdx < row.cells.length ? row.cells[colIdx] : null;

        if (val == null) {
          buffer.writeln(
            '<c r="$cellRef" s="$styleId" t="inlineStr"><is><t>—</t></is></c>',
          );
        } else if (val is num && col.isNumeric) {
          buffer.writeln('<c r="$cellRef" s="8"><v>$val</v></c>');
        } else if (val is DateTime) {
          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(val);
          buffer.writeln(
            '<c r="$cellRef" s="$styleId" t="inlineStr"><is><t>${_xml(dateStr)}</t></is></c>',
          );
        } else {
          buffer.writeln(
            '<c r="$cellRef" s="$styleId" t="inlineStr"><is><t>${_xml('$val')}</t></is></c>',
          );
        }
      }
      buffer.writeln('</row>');
      currentRow++;
    }

    buffer.writeln('</sheetData>');
    buffer.writeln('</worksheet>');
    return buffer.toString();
  }

  /// Sanitizes sheet names to satisfy Microsoft Excel / OpenXML constraints:
  /// - Maximum length of 31 characters.
  /// - Forbidden characters `\ / ? * : [ ]` replaced with spaces.
  /// - Leading/trailing apostrophes stripped.
  /// - Falls back to `'Sheet1'` if sanitized string is empty.
  /// Prevents the "We found a problem with some content..." recovery error in Excel.
  static String _sanitizeSheetName(String name) {
    var s = name.replaceAll(RegExp(r'[\\/?*:[\]]'), ' ').trim();
    if (s.length > 31) {
      s = s.substring(0, 31).trim();
    }
    s = s.replaceAll(RegExp(r"^'+|'+$"), '').trim();
    return s.isEmpty ? 'Sheet1' : s;
  }

  static String _xml(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value);

  static String _columnName(int index) {
    var value = index + 1;
    var result = '';
    while (value > 0) {
      final remainder = (value - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      value = (value - remainder - 1) ~/ 26;
    }
    return result;
  }

  static Uint8List _zip(List<_ZipEntry> entries) {
    final output = BytesBuilder();
    final central = BytesBuilder();
    var offset = 0;

    for (final entry in entries) {
      final name = utf8.encode(entry.name);
      final data = Uint8List.fromList(utf8.encode(entry.content));
      final crc = _crc32(data);
      final localOffset = offset;
      final local = BytesBuilder();

      _u32(local, 0x04034b50);
      _u16(local, 20);
      _u16(local, 0);
      _u16(local, 0);
      _u16(local, 0);
      _u16(local, 0);
      _u32(local, crc);
      _u32(local, data.length);
      _u32(local, data.length);
      _u16(local, name.length);
      _u16(local, 0);
      local.add(name);
      local.add(data);
      final localBytes = local.takeBytes();
      output.add(localBytes);
      offset += localBytes.length;

      _u32(central, 0x02014b50);
      _u16(central, 20);
      _u16(central, 20);
      _u16(central, 0);
      _u16(central, 0);
      _u16(central, 0);
      _u16(central, 0);
      _u32(central, crc);
      _u32(central, data.length);
      _u32(central, data.length);
      _u16(central, name.length);
      _u16(central, 0);
      _u16(central, 0);
      _u16(central, 0);
      _u16(central, 0);
      _u32(central, 0);
      _u32(central, localOffset);
      central.add(name);
    }

    final centralBytes = central.takeBytes();
    output.add(centralBytes);
    _u32(output, 0x06054b50);
    _u16(output, 0);
    _u16(output, 0);
    _u16(output, entries.length);
    _u16(output, entries.length);
    _u32(output, centralBytes.length);
    _u32(output, offset);
    _u16(output, 0);
    return output.toBytes();
  }

  static void _u16(BytesBuilder builder, int value) {
    builder.add(Uint8List.fromList([value & 0xff, (value >> 8) & 0xff]));
  }

  static void _u32(BytesBuilder builder, int value) {
    builder.add(Uint8List.fromList([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]));
  }

  static int _crc32(Uint8List data) {
    var crc = 0xffffffff;
    for (final byte in data) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}

class _ZipEntry {
  const _ZipEntry(this.name, this.content);
  final String name;
  final String content;
}
