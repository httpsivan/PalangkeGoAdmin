import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego_admin/core/utils/export/admin_export_models.dart';
import 'package:palengkego_admin/core/utils/export/excel_report_service.dart';
import 'package:palengkego_admin/core/utils/export/export_filename_service.dart';
import 'package:palengkego_admin/core/utils/export/module_export_data_builders.dart';
import 'package:palengkego_admin/core/utils/export/pdf_report_service.dart';
import 'package:palengkego_admin/core/widgets/admin_widgets.dart';
import 'package:palengkego_admin/data/mock_data.dart';
import 'package:palengkego_admin/core/theme/app_theme.dart';
import 'package:palengkego_admin/models/admin_models.dart';
import 'package:palengkego_admin/models/app_models.dart';

void main() {
  group('ExportFilenameService', () {
    test('generates expected format with timestamp and extension', () {
      final fixedDate = DateTime(2026, 9, 13, 14, 30, 45);
      final pdfFilename = ExportFilenameService.generateFilename(
        prefix: ExportFilenameService.accountsPrefix,
        extension: 'pdf',
        timestamp: fixedDate,
      );
      expect(pdfFilename, 'palengkego_accounts_report_2026-09-13_143045.pdf');

      final xlsxFilename = ExportFilenameService.generateFilename(
        prefix: ExportFilenameService.applicationsPrefix,
        extension: '.xlsx',
        timestamp: fixedDate,
      );
      expect(
        xlsxFilename,
        'palengkego_stall_holder_application_report_2026-09-13_143045.xlsx',
      );
    });
  });

  group('PdfReportService', () {
    test('generates valid PDF 1.4 binary with headers, summary, and table', () {
      final fixedDate = DateTime(2026, 9, 13, 14, 0);
      final doc = ExportDocument(
        filenamePrefix: 'test_report',
        reportName: 'Test Report',
        header: ReportHeader(
          reportTitle: 'Test Accounts Report',
          exportDate: fixedDate,
          activeFilters: 'Stall Holders | Active | Vegetables',
        ),
        summary: const ReportSummary(
          items: [
            ReportSummaryItem(label: 'Active', value: '12'),
            ReportSummaryItem(label: 'Suspended', value: '2'),
            ReportSummaryItem(label: 'Total', value: '14'),
          ],
        ),
        table: ReportTable(
          columns: const [
            ReportColumn(label: 'ID', flex: 1.0),
            ReportColumn(label: 'Name', flex: 2.0),
            ReportColumn(label: 'Status', flex: 1.0),
          ],
          rows: [
            const ReportRow(
                cells: ['STALL-001', 'Naga Fresh Produce', 'Active']),
            const ReportRow(
                cells: ['STALL-002', 'Bicol Organics', 'Suspended']),
          ],
        ),
      );

      final pdfBytes = PdfReportService.generatePdf(doc);
      expect(pdfBytes, isNotEmpty);

      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);
      // Valid PDF-1.4 header
      expect(pdfContent.startsWith('%PDF-1.4'), isTrue);
      // Catalog and page tree
      expect(pdfContent.contains('/Type /Catalog'), isTrue);
      expect(pdfContent.contains('/Type /Pages'), isTrue);
      // Header branding
      expect(pdfContent.contains('PalengkeGo Market'), isTrue);
      expect(pdfContent.contains('TEST ACCOUNTS REPORT'), isTrue);
      // Active filters
      expect(
          pdfContent.contains('Stall Holders | Active | Vegetables'), isTrue);
      // Summary
      expect(pdfContent.contains('REPORT SUMMARY'), isTrue);
      // Data cells
      expect(pdfContent.contains('Naga Fresh Produce'), isTrue);
      expect(pdfContent.contains('Bicol Organics'), isTrue);
      // Footer page count
      expect(pdfContent.contains('PalengkeGo Admin Test Report'), isTrue);
      expect(pdfContent.contains('Page 1 of 1'), isTrue);
      // EOF trailer
      expect(pdfContent.contains('%%EOF'), isTrue);
    });

    test('generates multi-page pagination when rows exceed single page limit',
        () {
      final rows = List.generate(
        35,
        (i) => ReportRow(cells: ['ID-$i', 'Vendor Name $i', 'Active']),
      );

      final doc = ExportDocument(
        filenamePrefix: 'multi_page_report',
        reportName: 'Multi-Page Test',
        header: ReportHeader(
          reportTitle: 'Multi-Page Report',
          exportDate: DateTime.now(),
          activeFilters: 'All',
        ),
        summary: const ReportSummary(
          items: [ReportSummaryItem(label: 'Count', value: '35')],
        ),
        table: ReportTable(
          columns: const [
            ReportColumn(label: 'ID', flex: 1.0),
            ReportColumn(label: 'Name', flex: 2.0),
            ReportColumn(label: 'Status', flex: 1.0),
          ],
          rows: rows,
        ),
      );

      final pdfBytes = PdfReportService.generatePdf(doc);
      final pdfContent = utf8.decode(pdfBytes, allowMalformed: true);

      // Should have at least 2 pages
      expect(pdfContent.contains('/Count 2'), isTrue);
      expect(pdfContent.contains('Page 1 of 2'), isTrue);
      expect(pdfContent.contains('Page 2 of 2'), isTrue);
      expect(pdfContent.contains('Continued'), isTrue);
    });
  });

  group('ExcelReportService', () {
    test(
        'generates valid OpenXML .xlsx ZIP workbook with frozen pane and no autoFilter',
        () {
      final fixedDate = DateTime(2026, 9, 13, 14, 0);
      final doc = ExportDocument(
        filenamePrefix: 'test_excel',
        reportName: 'Accounts Report',
        header: ReportHeader(
          reportTitle: 'Accounts Report',
          exportDate: fixedDate,
          activeFilters: 'All Statuses | All Categories',
        ),
        summary: const ReportSummary(
          items: [
            ReportSummaryItem(label: 'Active Stall Holders', value: '25'),
            ReportSummaryItem(label: 'Suspended Accounts', value: '3'),
          ],
        ),
        table: ReportTable(
          columns: const [
            ReportColumn(label: 'Account ID', flex: 1.0),
            ReportColumn(label: 'Stall Holder', flex: 1.5),
            ReportColumn(label: 'Category', flex: 1.0),
            ReportColumn(label: 'Status', flex: 1.0),
          ],
          rows: [
            const ReportRow(
                cells: ['ACC-01', 'Elena Vega', 'Fruits', 'Active']),
            const ReportRow(cells: ['ACC-02', 'Ramon Diaz', 'Fish', 'Active']),
          ],
        ),
      );

      final excelBytes = ExcelReportService.generateExcel(doc);
      expect(excelBytes, isNotEmpty);
      // Valid ZIP magic bytes (PK\x03\x04)
      expect(excelBytes[0], 0x50);
      expect(excelBytes[1], 0x4B);
      expect(excelBytes[2], 0x03);
      expect(excelBytes[3], 0x04);

      final content = utf8.decode(excelBytes, allowMalformed: true);
      // Contains OpenXML parts
      expect(content.contains('[Content_Types].xml'), isTrue);
      expect(content.contains('xl/workbook.xml'), isTrue);
      expect(content.contains('xl/styles.xml'), isTrue);
      expect(content.contains('xl/worksheets/sheet1.xml'), isTrue);
      // Sheet content contains header rows, summary, and cells
      expect(content.contains('PalengkeGo - Accounts Report'), isTrue);
      expect(content.contains('SUMMARY'), isTrue);
      expect(content.contains('Active Stall Holders'), isTrue);
      expect(content.contains('Elena Vega'), isTrue);
      expect(content.contains('Ramon Diaz'), isTrue);
      // autoFilter tag should not be present (sort/filter removed per requirement)
      expect(content.contains('autoFilter'), isFalse);
      // frozen pane
      expect(content.contains('state="frozen"'), isTrue);
    });
  });

  group('Module Export Data Builders (Filter-Aware)', () {
    test('AccountsExportData filters vendors correctly and updates summary',
        () {
      final allVendors = seedVendors();
      final filteredVegetableVendors = allVendors
          .where((v) =>
              v.stallType == 'Vegetables' && v.status == AccountStatus.active)
          .toList();

      final doc = AccountsExportData.buildStallHolders(
        allVendors: allVendors,
        filteredVendors: filteredVegetableVendors,
        activeFilters: 'Stall Holders | Active | Vegetables',
      );

      expect(doc.reportName, 'Stall Holder Accounts Report');
      expect(doc.filenamePrefix, 'palengkego_stall_holder_accounts_report');
      expect(doc.header.activeFilters, 'Stall Holders | Active | Vegetables');

      // Table rows should strictly contain only filtered vendors
      expect(doc.table.rows.length, filteredVegetableVendors.length);
      for (final row in doc.table.rows) {
        expect(row.cells[3], 'Vegetables');
        expect(row.cells[5], 'Active');
      }

      // Summary contains total and status breakdown
      expect(
          doc.summary.items.any((item) => item.label == 'Active Stall Holders'),
          isTrue);
      expect(
          doc.summary.items.any((item) => item.label == 'Total Stall Holders'),
          isTrue);
    });

    test(
        'ApplicationExportData extracts KYC details and respects filtered subset',
        () {
      final allApps = seedApplications();
      final reviewingApps = allApps
          .where((a) => a.status == ApplicationStatus.reviewing)
          .toList();

      final doc = ApplicationExportData.build(
        allApplications: allApps,
        filteredApplications: reviewingApps,
        activeFilters: 'Reviewing | All Categories',
      );

      expect(doc.reportName, 'Stall Holder Application Report');
      expect(doc.filenamePrefix, 'palengkego_stall_holder_application_report');
      expect(doc.table.rows.length, reviewingApps.length);
      for (final row in doc.table.rows) {
        expect(row.cells[5], 'Reviewing');
      }

      expect(
          doc.summary.items.any((item) => item.label == 'Pending Applications'),
          isTrue);
      expect(
          doc.summary.items
              .any((item) => item.label == 'Approved Applications'),
          isTrue);
    });

    test('RenewalExportData calculates days left and reflects renewal statuses',
        () {
      final allRenewals = seedRenewals();
      final doc = RenewalExportData.build(
        allRenewals: allRenewals,
        filteredRenewals: allRenewals,
        activeFilters: 'All Statuses | All Categories',
      );

      expect(doc.reportName, 'Renewal Report');
      expect(doc.filenamePrefix, 'palengkego_renewal_report');
      expect(doc.table.rows.length, allRenewals.length);

      // Expiry column format check: should have remaining days or expired
      for (final row in doc.table.rows) {
        final expiryCell = row.cells[4] as String;
        expect(
          expiryCell.contains('days left') || expiryCell.contains('Expired'),
          isTrue,
        );
      }
    });

    test('ComplaintExportData tracks priority and resolution state', () {
      final allReports = seedReports();
      final doc = ComplaintExportData.build(
        allReports: allReports,
        filteredReports: allReports,
        activeFilters: 'All Types | All Statuses',
      );

      expect(doc.reportName, 'Complaints Report');
      expect(doc.filenamePrefix, 'palengkego_complaints_report');
      expect(doc.table.rows.length, allReports.length);
      expect(
          doc.summary.items.any((item) => item.label == 'Pending Complaints'),
          isTrue);
      expect(doc.summary.items.any((item) => item.label == 'Resolved'), isTrue);
    });

    test('AnnouncementExportData computes metrics and status values', () {
      final allAnnouncements = seedAnnouncements();
      final doc = AnnouncementExportData.build(
        allAnnouncements: allAnnouncements,
        filteredAnnouncements: allAnnouncements,
        activeFilters: 'All Audiences | All Statuses',
      );

      expect(doc.reportName, 'Announcement History Report');
      expect(doc.filenamePrefix, 'palengkego_announcements_report');
      expect(doc.table.rows.length, allAnnouncements.length);
      expect(
          doc.summary.items.any((item) => item.label == 'Total Announcements'),
          isTrue);
      expect(doc.summary.items.any((item) => item.label == 'Delivered Notices'),
          isTrue);
    });

    test('AuditExportData maintains chronological order and action logging',
        () {
      final sampleLogs = [
        AuditLog(
          id: 'AUD-001',
          administratorId: 'ADM-01',
          administratorName: 'Admin Kirren',
          action: AuditAction.approveKyc,
          targetEntityType: 'Application',
          targetEntityId: 'APP-101',
          targetUserName: 'Stall Applicant',
          previousValue: 'Reviewing',
          newValue: 'Verified',
          reason: 'Valid DTI & Permit',
          metadata: {},
          timestamp: DateTime(2026, 9, 13, 10, 0),
        ),
        AuditLog(
          id: 'AUD-002',
          administratorId: 'ADM-01',
          administratorName: 'Admin Kirren',
          action: AuditAction.blockAccount,
          targetEntityType: 'Account',
          targetEntityId: 'ACC-202',
          targetUserName: 'Offending Vendor',
          previousValue: 'Active',
          newValue: 'Blocked',
          reason: 'Severe sanitary violation',
          metadata: {},
          timestamp: DateTime(2026, 9, 13, 11, 0),
        ),
      ];

      final doc = AuditExportData.build(
        allLogs: sampleLogs,
        filteredLogs: sampleLogs,
        activeFilters: 'All Actions | All entities',
      );

      expect(doc.reportName, 'Admin Audit Log Report');
      expect(doc.filenamePrefix, 'palengkego_admin_audit_log');
      expect(doc.table.rows.length, sampleLogs.length);
      expect(doc.summary.items.any((item) => item.label == 'Recorded Actions'),
          isTrue);
      expect(
          doc.summary.items.any((item) => item.label == 'KYC Actions'), isTrue);
      expect(doc.summary.items.any((item) => item.label == 'Account Controls'),
          isTrue);
    });

    test(
        'SalesExportData extracts sales details, revenue metrics, and order rows',
        () {
      final sampleOrders = seedOrders();
      final summary = SalesSummary.fromOrders(sampleOrders);
      final doc = SalesExportData.build(
        allOrders: sampleOrders,
        filteredOrders: sampleOrders,
        summary: summary,
        activeFilters: 'Period: This Month • All Categories',
      );

      expect(doc.reportName, 'Sales Report');
      expect(doc.filenamePrefix, 'palengkego_sales_report');
      expect(doc.table.rows.length, sampleOrders.length);
      expect(
          doc.summary.items.any((item) => item.label == 'Gross Sales'), isTrue);
      expect(
          doc.summary.items.any((item) => item.label == 'Net Revenue'), isTrue);
      expect(doc.summary.items.any((item) => item.label == 'Total Orders'),
          isTrue);
      expect(doc.summary.items.any((item) => item.label == 'Completed Orders'),
          isTrue);
      expect(doc.summary.items.any((item) => item.label == 'Refunds'), isTrue);

      final pdfBytes = PdfReportService.generatePdf(doc);
      expect(pdfBytes, isNotEmpty);
      final excelBytes = ExcelReportService.generateExcel(doc);
      expect(excelBytes, isNotEmpty);
    });
  });

  group('ExportButton Widget', () {
    testWidgets('renders format dropdown menu and invokes callbacks',
        (tester) async {
      var pdfCalled = false;
      var excelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Center(
              child: ExportButton(
                onExportPdf: () => pdfCalled = true,
                onExportExcel: () => excelCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Export'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Tap Export button to open menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Export PDF'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);

      // Tap Export PDF
      await tester.tap(find.text('Export PDF'));
      await tester.pumpAndSettle();
      expect(pdfCalled, isTrue);
      expect(excelCalled, isFalse);

      // Tap Export button again
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Export Excel
      await tester.tap(find.text('Export Excel'));
      await tester.pumpAndSettle();
      expect(excelCalled, isTrue);
    });
  });
}
