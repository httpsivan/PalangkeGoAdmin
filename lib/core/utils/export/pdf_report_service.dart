import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'admin_export_models.dart';

class PdfReportService {
  PdfReportService._();

  static const double pageWidth = 842.0; // A4 Landscape
  static const double pageHeight = 595.0;
  static const double marginX = 36.0;
  static const double printableWidth = pageWidth - (marginX * 2); // 770.0
  static const double rowHeight = 20.0;
  static const double headerRowHeight = 22.0;

  static final DateFormat _dateFormat = DateFormat('MMMM d, yyyy, h:mm a');

  static Uint8List generatePdf(ExportDocument doc) {
    // 1. Calculate column widths
    final totalFlex = doc.table.columns.fold<double>(
      0.0,
      (sum, col) => sum + col.flex,
    );
    final colWidths = doc.table.columns
        .map((col) => (col.flex / totalFlex) * printableWidth)
        .toList();

    // 2. Paginate rows
    // Page 1 has Header Banner (80pt) + Summary Box (48pt) + Spacing
    // Available height on Page 1 for table: ~350pt -> ~16 rows
    // Subsequent pages have compact continuation banner (36pt) -> ~450pt -> ~21 rows
    const firstPageTableHeight = 330.0;
    const subsequentPageTableHeight = 440.0;

    final firstPageRowCount =
        (firstPageTableHeight / rowHeight).floor().clamp(1, 16);
    final subsequentPageRowCount =
        (subsequentPageTableHeight / rowHeight).floor().clamp(1, 21);

    final pagesRows = <List<ReportRow>>[];
    final allRows = doc.table.rows;

    if (allRows.isEmpty) {
      pagesRows.add([]);
    } else {
      var currentIndex = 0;
      // First page
      final firstBatch = allRows.take(firstPageRowCount).toList();
      pagesRows.add(firstBatch);
      currentIndex += firstBatch.length;

      // Remaining pages
      while (currentIndex < allRows.length) {
        final batch =
            allRows.skip(currentIndex).take(subsequentPageRowCount).toList();
        pagesRows.add(batch);
        currentIndex += batch.length;
      }
    }

    final totalPages = pagesRows.length;

    // 3. Render PDF Objects
    final objects = <String>[];
    final pageIds = <int>[];

    // Object 1: Catalog
    objects.add('<< /Type /Catalog /Pages 2 0 R >>');
    // Object 2: Pages (placeholder, updated later)
    objects.add('');
    // Object 3: Font Helvetica
    objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    // Object 4: Font Helvetica-Bold
    objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');

    for (var pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final pageNum = pageIndex + 1;
      final rowsForPage = pagesRows[pageIndex];
      final isFirstPage = pageIndex == 0;

      final pageId = objects.length + 1;
      final contentId = pageId + 1;
      pageIds.add(pageId);

      final stream = StringBuffer();

      if (isFirstPage) {
        _renderFirstPageHeader(stream, doc);
        _renderSummaryBox(stream, doc.summary);
      } else {
        _renderContinuationHeader(stream, doc);
      }

      // Render Table
      final double tableTopY = isFirstPage ? 385.0 : 520.0;
      _renderTable(
        stream: stream,
        topY: tableTopY,
        columns: doc.table.columns,
        widths: colWidths,
        rows: rowsForPage,
      );

      // Render Footer
      _renderFooter(stream, doc.reportName, pageNum, totalPages);

      final content = stream.toString();
      objects.add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageWidth $pageHeight] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents $contentId 0 R >>',
      );
      objects.add(
        '<< /Length ${utf8.encode(content).length} >>\nstream\n$content\nendstream',
      );
    }

    // Update Pages catalog
    final kids = pageIds.map((id) => '$id 0 R').join(' ');
    objects[1] = '<< /Type /Pages /Kids [$kids] /Count ${pageIds.length} >>';

    // 4. Build output bytes
    final output = BytesBuilder();
    output.add(utf8.encode('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n'));
    final offsets = <int>[];
    for (var index = 0; index < objects.length; index++) {
      offsets.add(output.length);
      output
          .add(utf8.encode('${index + 1} 0 obj\n${objects[index]}\nendobj\n'));
    }
    final xrefOffset = output.length;
    output.add(utf8.encode('xref\n0 ${objects.length + 1}\n'));
    output.add(utf8.encode('0000000000 65535 f \n'));
    for (final offset in offsets) {
      output
          .add(utf8.encode('${offset.toString().padLeft(10, '0')} 00000 n \n'));
    }
    output.add(utf8.encode(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF',
    ));

    return output.toBytes();
  }

  static void _renderFirstPageHeader(StringBuffer stream, ExportDocument doc) {
    // Banner background: #0B372B
    stream.writeln('0.043 0.216 0.169 rg');
    stream.writeln('$marginX 505.0 $printableWidth 62.0 re f');

    // Accent line at bottom of banner: #A7F3D0
    stream.writeln('0.655 0.953 0.816 rg');
    stream.writeln('$marginX 503.0 $printableWidth 2.0 re f');

    // Text inside banner
    stream.writeln('BT');
    // Organization title: PalengkeGo Market
    stream.writeln('1.0 1.0 1.0 rg');
    stream.writeln('/F2 15 Tf');
    stream.writeln('${marginX + 16} 542 Td');
    stream.writeln('(${_pdfText(doc.header.organization)}) Tj');

    // Report Title
    stream.writeln('/F2 11 Tf');
    stream.writeln('0 -16 Td');
    stream.writeln('(${_pdfText(doc.header.reportTitle.toUpperCase())}) Tj');
    stream.writeln('ET');

    // Right-aligned Metadata (Export Date, Date Range, Filters)
    stream.writeln('BT');
    stream.writeln('0.85 0.95 0.90 rg');
    stream.writeln('/F1 8 Tf');
    stream.writeln('${marginX + printableWidth - 280} 546 Td');
    stream.writeln(
        '(${_pdfText('Export Date: ${_dateFormat.format(doc.header.exportDate)}')}) Tj');
    if (doc.header.dateRange != null && doc.header.dateRange!.isNotEmpty) {
      stream.writeln('0 -11 Td');
      stream.writeln('(${_pdfText('Date Range: ${doc.header.dateRange}')}) Tj');
    }
    stream.writeln('0 -11 Td');
    final filterText = 'Export Filter: ${doc.header.activeFilters}';
    final truncatedFilters = filterText.length > 55
        ? '${filterText.substring(0, 52)}...'
        : filterText;
    stream.writeln('(${_pdfText(truncatedFilters)}) Tj');
    stream.writeln('ET');
  }

  static void _renderContinuationHeader(
      StringBuffer stream, ExportDocument doc) {
    // Compact Header Banner: #0B372B
    stream.writeln('0.043 0.216 0.169 rg');
    stream.writeln('$marginX 548.0 $printableWidth 28.0 re f');

    stream.writeln('BT');
    stream.writeln('1.0 1.0 1.0 rg');
    stream.writeln('/F2 10 Tf');
    stream.writeln('${marginX + 14} 558 Td');
    stream.writeln(
        '(${_pdfText('${doc.header.organization} - ${doc.header.reportTitle} (Continued)')}) Tj');
    stream.writeln('ET');
  }

  static void _renderSummaryBox(StringBuffer stream, ReportSummary summary) {
    const boxY = 442.0;
    const boxH = 46.0;

    // Background fill: #ECFDF5
    stream.writeln('0.925 0.992 0.961 rg');
    stream.writeln('$marginX $boxY $printableWidth $boxH re f');

    // Border: #A7F3D0
    stream.writeln('0.655 0.953 0.816 RG');
    stream.writeln('1.0 w');
    stream.writeln('$marginX $boxY $printableWidth $boxH re S');

    // Summary Title: #064E3B
    stream.writeln('BT');
    stream.writeln('0.024 0.306 0.231 rg');
    stream.writeln('/F2 9 Tf');
    stream.writeln('${marginX + 14} 472 Td');
    stream.writeln('(${_pdfText(summary.title)}) Tj');
    stream.writeln('ET');

    // Summary Items horizontally distributed
    if (summary.items.isNotEmpty) {
      final itemWidth = printableWidth / summary.items.length;
      for (var i = 0; i < summary.items.length; i++) {
        final item = summary.items[i];
        final itemX = marginX + 14 + (i * itemWidth);

        stream.writeln('BT');
        // Label
        stream.writeln('0.30 0.40 0.35 rg');
        stream.writeln('/F1 8 Tf');
        stream.writeln('$itemX 458 Td');
        stream.writeln('(${_pdfText(item.label)}:) Tj');

        // Value in bold #0B372B
        stream.writeln('0.043 0.216 0.169 rg');
        stream.writeln('/F2 9.5 Tf');
        stream.writeln('0 -12 Td');
        stream.writeln('(${_pdfText(item.value)}) Tj');
        stream.writeln('ET');
      }
    }
  }

  static void _renderTable({
    required StringBuffer stream,
    required double topY,
    required List<ReportColumn> columns,
    required List<double> widths,
    required List<ReportRow> rows,
  }) {
    // 1. Table Header Background: #0B372B
    final headerY = topY - headerRowHeight;
    stream.writeln('0.043 0.216 0.169 rg');
    stream.writeln('$marginX $headerY $printableWidth $headerRowHeight re f');

    // Header text: White bold
    var currentX = marginX;
    for (var i = 0; i < columns.length; i++) {
      final col = columns[i];
      final colW = widths[i];
      final textX = currentX + 8;
      final textY = headerY + 7;

      stream.writeln('BT');
      stream.writeln('1.0 1.0 1.0 rg');
      stream.writeln('/F2 8 Tf');
      stream.writeln('$textX $textY Td');
      stream.writeln('(${_pdfText(col.label.toUpperCase())}) Tj');
      stream.writeln('ET');

      currentX += colW;
    }

    // 2. Data Rows
    var currentY = headerY;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      currentY -= rowHeight;

      // Alternating background: #FFFFFF / #F8FAFC
      if (rowIndex % 2 == 1) {
        stream.writeln('0.973 0.980 0.988 rg');
        stream.writeln('$marginX $currentY $printableWidth $rowHeight re f');
      }

      // Bottom cell divider: #E2E8F0
      stream.writeln('0.886 0.910 0.941 RG');
      stream.writeln('0.5 w');
      stream.writeln(
          '$marginX $currentY m ${marginX + printableWidth} $currentY l S');

      // Cell text
      var cellX = marginX;
      for (var colIndex = 0; colIndex < columns.length; colIndex++) {
        final colW = widths[colIndex];
        final rawVal = colIndex < row.cells.length ? row.cells[colIndex] : '';
        final valStr = _formatCellValue(rawVal);

        // Truncate cell text if necessary based on column width
        final maxChars = (colW / 4.8).floor();
        final displayStr = valStr.length > maxChars
            ? '${valStr.substring(0, (maxChars - 3).clamp(1, valStr.length))}...'
            : valStr;

        final textX = cellX + 8;
        final textY = currentY + 6;

        stream.writeln('BT');
        // If status row color is present and this is the status column (last or labeled STATUS)
        final isStatusCol =
            columns[colIndex].label.toUpperCase().contains('STATUS') ||
                columns[colIndex].label.toUpperCase().contains('PRIORITY');
        if (isStatusCol && row.statusColor != null) {
          final r = (row.statusColor!.r).toStringAsFixed(3);
          final g = (row.statusColor!.g).toStringAsFixed(3);
          final b = (row.statusColor!.b).toStringAsFixed(3);
          stream.writeln('$r $g $b rg');
          stream.writeln('/F2 7.5 Tf');
        } else {
          stream.writeln('0.12 0.16 0.23 rg'); // #1E293B
          stream.writeln('/F1 7.5 Tf');
        }

        stream.writeln('$textX $textY Td');
        stream.writeln('(${_pdfText(displayStr)}) Tj');
        stream.writeln('ET');

        cellX += colW;
      }
    }
  }

  static void _renderFooter(
    StringBuffer stream,
    String reportName,
    int pageNum,
    int totalPages,
  ) {
    const footerY = 24.0;

    // Divider line: #E2E8F0
    stream.writeln('0.886 0.910 0.941 RG');
    stream.writeln('0.75 w');
    stream.writeln(
        '$marginX ${footerY + 12} m ${marginX + printableWidth} ${footerY + 12} l S');

    // Left: PalengkeGo Admin [Report Name]
    stream.writeln('BT');
    stream.writeln('0.392 0.455 0.545 rg'); // #64748B
    stream.writeln('/F1 8 Tf');
    stream.writeln('$marginX $footerY Td');
    stream.writeln('(${_pdfText('PalengkeGo Admin $reportName')}) Tj');
    stream.writeln('ET');

    // Right: Page X of Y
    stream.writeln('BT');
    stream.writeln('0.392 0.455 0.545 rg');
    stream.writeln('/F2 8 Tf');
    stream.writeln('${marginX + printableWidth - 70} $footerY Td');
    stream.writeln('(${_pdfText('Page $pageNum of $totalPages')}) Tj');
    stream.writeln('ET');
  }

  static String _formatCellValue(Object? value) {
    if (value == null) return '—';
    if (value is DateTime) {
      return DateFormat('yyyy-MM-dd HH:mm').format(value);
    }
    final str = value.toString().trim();
    return str.isEmpty ? '—' : str;
  }

  static String _pdfText(String value) => value
      .replaceAll('₱', 'PHP ')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('•', '-')
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');
}
