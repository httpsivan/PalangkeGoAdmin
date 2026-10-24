import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/mock_repository.dart';
import '../../../models/admin_models.dart';
import '../csv_exporter.dart';
import '../platform_file_saver.dart';
import 'admin_export_models.dart';
import 'excel_report_service.dart';
import 'export_filename_service.dart';
import 'pdf_report_service.dart';

enum ExportFormat { pdf, excel, csv }

class AdminExportService {
  AdminExportService._();

  static final DateFormat _dateFormat = DateFormat('MMMM d, yyyy, h:mm a');

  /// Formats an [ExportDocument] into structured tabular rows for CSV generation.
  /// Follows the uniform report layout:
  /// 1. Report title header
  /// 2. Export timestamp
  /// 3. Active filter criteria and date ranges
  /// 4. Summary card key-value pairs (if present)
  /// 5. Data table column headers followed by record rows
  static List<List<Object?>> buildCsvRows(ExportDocument doc) {
    final dateRangePart =
        doc.header.dateRange != null && doc.header.dateRange!.isNotEmpty
            ? 'Date Range: ${doc.header.dateRange} | '
            : '';
    final filterString = '$dateRangePart${doc.header.activeFilters}';

    return <List<Object?>>[
      ['PalengkeGo - ${doc.header.reportTitle}'],
      ['Export Date: ${_dateFormat.format(doc.header.exportDate)}'],
      ['Filters: $filterString'],
      const <Object?>[],
      if (doc.summary.items.isNotEmpty) ...[
        const ['SUMMARY', 'COUNT / VALUE'],
        ...doc.summary.items.map((item) {
          final numVal = num.tryParse(item.value.replaceAll(',', ''));
          return [item.label, numVal ?? item.value];
        }),
        const <Object?>[],
      ],
      doc.table.columns.map((c) => c.label).toList(),
      ...doc.table.rows.map((r) => r.cells),
    ];
  }

  static Future<void> export({
    required BuildContext context,
    required WidgetRef ref,
    required ExportDocument doc,
    required ExportFormat format,
  }) async {
    final Uint8List bytes;
    final String filename;
    final String mimeType;
    final AuditAction auditAction;

    if (format == ExportFormat.pdf) {
      bytes = PdfReportService.generatePdf(doc);
      filename = ExportFilenameService.generateFilename(
        prefix: doc.filenamePrefix,
        extension: 'pdf',
        timestamp: doc.header.exportDate,
      );
      mimeType = 'application/pdf';
      auditAction = AuditAction.exportPdf;
    } else if (format == ExportFormat.csv) {
      final csvRows = buildCsvRows(doc);
      final csvString = buildCsv(csvRows);
      bytes = Uint8List.fromList(utf8.encode(csvString));
      filename = ExportFilenameService.generateFilename(
        prefix: doc.filenamePrefix,
        extension: 'csv',
        timestamp: doc.header.exportDate,
      );
      mimeType = 'text/csv;charset=utf-8';
      auditAction = AuditAction.exportExcel;
    } else {
      bytes = ExcelReportService.generateExcel(doc);
      filename = ExportFilenameService.generateFilename(
        prefix: doc.filenamePrefix,
        extension: 'xlsx',
        timestamp: doc.header.exportDate,
      );
      mimeType =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      auditAction = AuditAction.exportExcel;
    }

    await saveFileBytes(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );

    // Record audit event in immutable audit log
    await ref.read(appDataProvider.notifier).recordAudit(
          action: auditAction,
          targetEntityType: doc.reportName,
          targetEntityId: doc.filenamePrefix,
          targetUserName: 'System',
          previousValue: '',
          newValue:
              '${doc.table.rows.length} records (${doc.header.activeFilters})',
        );

    if (context.mounted) {
      final formatLabel = switch (format) {
        ExportFormat.pdf => 'PDF',
        ExportFormat.csv => 'CSV',
        ExportFormat.excel => 'Excel',
      };
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${doc.reportName} $formatLabel report exported successfully.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
