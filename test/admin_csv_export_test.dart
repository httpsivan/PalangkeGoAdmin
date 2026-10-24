import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego_admin/core/utils/csv_exporter.dart';
import 'package:palengkego_admin/core/utils/export/admin_export_models.dart';
import 'package:palengkego_admin/core/utils/export/admin_export_service.dart';
import 'package:palengkego_admin/core/utils/export/excel_report_service.dart';

void main() {
  group('AdminExportService CSV Generation', () {
    test('buildCsvRows formats report with title, export date, filters, summary, and table matching design', () {
      final fixedDate = DateTime(2026, 10, 24, 21, 24);
      final doc = ExportDocument(
        filenamePrefix: 'palengkego_stall_holder_accounts_report',
        reportName: 'Stall Holder Accounts Report',
        header: ReportHeader(
          reportTitle: 'Stall Holder Accounts Report',
          exportDate: fixedDate,
          activeFilters: 'Stall Holders',
        ),
        summary: const ReportSummary(
          items: [
            ReportSummaryItem(label: 'Active Stall Holders', value: '12'),
            ReportSummaryItem(label: 'Suspended Accounts', value: '1'),
            ReportSummaryItem(label: 'Blocked Accounts', value: '2'),
            ReportSummaryItem(label: 'Total Stall Holders', value: '17'),
          ],
        ),
        table: const ReportTable(
          columns: [
            ReportColumn(label: 'Account ID'),
            ReportColumn(label: 'Stall Holder'),
            ReportColumn(label: 'Email'),
            ReportColumn(label: 'Stall Type'),
            ReportColumn(label: 'Registration Date'),
            ReportColumn(label: 'Account Status'),
          ],
          rows: [
            ReportRow(cells: [
              'VND-92858',
              'Omar Rivera',
              'omar.rivera@gmail.com',
              'SARI-SARI',
              '2024-04-21',
              'Active',
            ]),
          ],
        ),
      );

      final rows = AdminExportService.buildCsvRows(doc);

      // Row 1: Title
      expect(rows[0], ['PalengkeGo - Stall Holder Accounts Report']);
      // Row 2: Export Date
      expect(rows[1], ['Export Date: October 24, 2026, 9:24 PM']);
      // Row 3: Filters
      expect(rows[2], ['Filters: Stall Holders']);
      // Row 4: Spacer
      expect(rows[3], isEmpty);
      // Row 5: Summary Header
      expect(rows[4], ['SUMMARY', 'COUNT / VALUE']);
      // Summary Items
      expect(rows[5], ['Active Stall Holders', 12]);
      expect(rows[6], ['Suspended Accounts', 1]);
      expect(rows[7], ['Blocked Accounts', 2]);
      expect(rows[8], ['Total Stall Holders', 17]);
      // Spacer after summary
      expect(rows[9], isEmpty);
      // Table Header
      expect(rows[10], [
        'Account ID',
        'Stall Holder',
        'Email',
        'Stall Type',
        'Registration Date',
        'Account Status',
      ]);
      // Data row
      expect(rows[11], [
        'VND-92858',
        'Omar Rivera',
        'omar.rivera@gmail.com',
        'SARI-SARI',
        '2024-04-21',
        'Active',
      ]);

      // Verify buildCsv converts cleanly to string
      final csvString = buildCsv(rows);
      expect(csvString.contains('PalengkeGo - Stall Holder Accounts Report'), isTrue);
      expect(csvString.contains('Export Date: October 24, 2026, 9:24 PM'), isTrue);
      expect(csvString.contains('SUMMARY,COUNT / VALUE'), isTrue);
      expect(csvString.contains('VND-92858,Omar Rivera'), isTrue);
    });

    test('buildCsvRows handles empty summary without summary header', () {
      final fixedDate = DateTime(2026, 10, 24, 21, 24);
      final doc = ExportDocument(
        filenamePrefix: 'test_no_summary',
        reportName: 'No Summary Report',
        header: ReportHeader(
          reportTitle: 'No Summary Report',
          exportDate: fixedDate,
          activeFilters: 'All',
        ),
        summary: const ReportSummary(items: []),
        table: const ReportTable(
          columns: [ReportColumn(label: 'Col 1')],
          rows: [ReportRow(cells: ['Val 1'])],
        ),
      );

      final rows = AdminExportService.buildCsvRows(doc);
      expect(rows[0], ['PalengkeGo - No Summary Report']);
      expect(rows[1], ['Export Date: October 24, 2026, 9:24 PM']);
      expect(rows[2], ['Filters: All']);
      expect(rows[3], isEmpty);
      // Directly table header since summary is empty
      expect(rows[4], ['Col 1']);
      expect(rows[5], ['Val 1']);
    });

    test('ExcelReportService sanitizes sheet name to max 31 chars and valid characters', () {
      final doc = ExportDocument(
        filenamePrefix: 'palengkego_audit_omar_rivera',
        reportName: 'Stall Inventory Audit - Omar Rivera (Very Long Name That Exceeds)',
        header: ReportHeader(
          reportTitle: 'Stall Holder Product Listing & Price Audit Sheet',
          exportDate: DateTime.now(),
          activeFilters: 'All',
        ),
        summary: const ReportSummary(items: []),
        table: const ReportTable(
          columns: [ReportColumn(label: 'Col 1')],
          rows: [ReportRow(cells: ['Val 1'])],
        ),
      );

      final bytes = ExcelReportService.generateExcel(doc);
      expect(bytes, isNotEmpty);
      final xml = String.fromCharCodes(bytes);
      // Sheet name in workbook.xml must not exceed 31 chars
      final match = RegExp(r'<sheet name="([^"]+)"').firstMatch(xml);
      expect(match, isNotNull);
      final sheetName = match!.group(1)!;
      expect(sheetName.length, lessThanOrEqualTo(31));
    });
  });
}
