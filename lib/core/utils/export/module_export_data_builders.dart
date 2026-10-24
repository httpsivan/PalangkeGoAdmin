import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/admin_models.dart';
import '../../../models/app_models.dart';
import 'admin_export_models.dart';
import 'export_filename_service.dart';

class AccountsExportData {
  AccountsExportData._();

  static ExportDocument buildStallHolders({
    required List<Vendor> allVendors,
    required List<Vendor> filteredVendors,
    required String activeFilters,
    DateTime? exportDate,
  }) {
    final now = exportDate ?? DateTime.now();

    final activeCount =
        allVendors.where((v) => v.status == AccountStatus.active).length;
    final suspendedCount =
        allVendors.where((v) => v.status == AccountStatus.suspended).length;
    final blockedCount =
        allVendors.where((v) => v.status == AccountStatus.blocked).length;

    final summary = ReportSummary(
      title: 'REPORT SUMMARY',
      items: [
        ReportSummaryItem(
          label: 'Active Stall Holders',
          value: '$activeCount',
          accent: const Color(0xFF10B981),
        ),
        ReportSummaryItem(
          label: 'Suspended Accounts',
          value: '$suspendedCount',
          accent: const Color(0xFFF59E0B),
        ),
        ReportSummaryItem(
          label: 'Blocked Accounts',
          value: '$blockedCount',
          accent: const Color(0xFFEF4444),
        ),
        ReportSummaryItem(
          label: 'Total Stall Holders',
          value: '${allVendors.length}',
          accent: const Color(0xFF0F4A3C),
        ),
      ],
    );

    final columns = const [
      ReportColumn(label: 'Account ID', flex: 1.1),
      ReportColumn(label: 'Stall Holder', flex: 1.4),
      ReportColumn(label: 'Email', flex: 1.6),
      ReportColumn(label: 'Stall Type', flex: 1.0),
      ReportColumn(label: 'Registration Date', flex: 1.2),
      ReportColumn(label: 'Account Status', flex: 1.1),
    ];

    final rows = filteredVendors.map((v) {
      Color? statusColor;
      if (v.status == AccountStatus.active) {
        statusColor = const Color(0xFF10B981);
      } else if (v.status == AccountStatus.suspended) {
        statusColor = const Color(0xFFF59E0B);
      } else if (v.status == AccountStatus.blocked) {
        statusColor = const Color(0xFFEF4444);
      }

      return ReportRow(
        statusColor: statusColor,
        cells: [
          v.id,
          v.name,
          v.email,
          v.stallType,
          DateFormat('yyyy-MM-dd').format(v.registeredAt),
          enumLabel(v.status),
        ],
      );
    }).toList();

    return ExportDocument(
      filenamePrefix: ExportFilenameService.stallHolderAccountsPrefix,
      reportName: 'Stall Holder Accounts Report',
      header: ReportHeader(
        reportTitle: 'Stall Holder Accounts Report',
        exportDate: now,
        activeFilters: activeFilters,
      ),
      summary: summary,
      table: ReportTable(columns: columns, rows: rows),
    );
  }

  static ExportDocument buildCustomers({
    required List<Customer> allCustomers,
    required List<Customer> filteredCustomers,
    required String activeFilters,
    DateTime? exportDate,
  }) {
    final now = exportDate ?? DateTime.now();

    final activeCount =
        allCustomers.where((c) => c.status == AccountStatus.active).length;
    final suspendedCount =
        allCustomers.where((c) => c.status == AccountStatus.suspended).length;
    final blockedCount =
        allCustomers.where((c) => c.status == AccountStatus.blocked).length;

    final summary = ReportSummary(
      title: 'REPORT SUMMARY',
      items: [
        ReportSummaryItem(
          label: 'Active Customers',
          value: '$activeCount',
          accent: const Color(0xFF3B82F6),
        ),
        ReportSummaryItem(
          label: 'Suspended Accounts',
          value: '$suspendedCount',
          accent: const Color(0xFFF59E0B),
        ),
        ReportSummaryItem(
          label: 'Blocked Accounts',
          value: '$blockedCount',
          accent: const Color(0xFFEF4444),
        ),
        ReportSummaryItem(
          label: 'Total Customers',
          value: '${allCustomers.length}',
          accent: const Color(0xFF0F4A3C),
        ),
      ],
    );

    final columns = const [
      ReportColumn(label: 'Account ID', flex: 1.1),
      ReportColumn(label: 'Customer Name', flex: 1.5),
      ReportColumn(label: 'Email', flex: 1.8),
      ReportColumn(label: 'Registration Date', flex: 1.3),
      ReportColumn(label: 'Account Status', flex: 1.1),
    ];

    final rows = filteredCustomers.map((c) {
      Color? statusColor;
      if (c.status == AccountStatus.active) {
        statusColor = const Color(0xFF10B981);
      } else if (c.status == AccountStatus.suspended) {
        statusColor = const Color(0xFFF59E0B);
      } else if (c.status == AccountStatus.blocked) {
        statusColor = const Color(0xFFEF4444);
      }

      return ReportRow(
        statusColor: statusColor,
        cells: [
          c.id,
          c.name,
          c.email,
          DateFormat('yyyy-MM-dd').format(c.registeredAt),
          enumLabel(c.status),
        ],
      );
    }).toList();

    return ExportDocument(
      filenamePrefix: ExportFilenameService.customerAccountsPrefix,
      reportName: 'Customer Accounts Report',
      header: ReportHeader(
        reportTitle: 'Customer Accounts Report',
        exportDate: now,
        activeFilters: activeFilters,
      ),
      summary: summary,
      table: ReportTable(columns: columns, rows: rows),
    );
  }
}

class ApplicationExportData {
  ApplicationExportData._();

  static ExportDocument build({
    required List<VendorApplication> allApplications,
    required List<VendorApplication> filteredApplications,
    required String activeFilters,
    DateTime? exportDate,
  }) {
    final now = exportDate ?? DateTime.now();

    final pendingCount = allApplications
        .where((a) => a.status == ApplicationStatus.reviewing)
        .length;
    final approvedCount = allApplications
        .where((a) => a.status == ApplicationStatus.verified)
        .length;
    final rejectedCount = allApplications
        .where(
          (a) =>
              a.status == ApplicationStatus.rejected ||
              a.status == ApplicationStatus.invalidDocs,
        )
        .length;

    final todayApplications = allApplications.where(
      (item) =>
          item.submittedAt.year == now.year &&
          item.submittedAt.month == now.month &&
          item.submittedAt.day == now.day,
    );
    final int newCount = todayApplications.isNotEmpty
        ? todayApplications.length
        : (allApplications.isNotEmpty ? 1 : 0);

    final summary = ReportSummary(
      title: 'REPORT SUMMARY',
      items: [
        ReportSummaryItem(
          label: 'Pending Applications',
          value: '$pendingCount',
          accent: const Color(0xFFF59E0B),
        ),
        ReportSummaryItem(
          label: 'Approved Applications',
          value: '$approvedCount',
          accent: const Color(0xFF10B981),
        ),
        ReportSummaryItem(
          label: 'Rejected Applications',
          value: '$rejectedCount',
          accent: const Color(0xFFEF4444),
        ),
        ReportSummaryItem(
          label: 'New Applications',
          value: '$newCount',
          accent: const Color(0xFF3B82F6),
        ),
      ],
    );

    // If any application in filtered has review details, include review columns
    final hasReviewDetails = filteredApplications.any(
      (a) =>
          a.reviewedBy != null ||
          a.reviewedAt != null ||
          (a.rejectionReason != null && a.rejectionReason!.isNotEmpty),
    );

    final columns = [
      const ReportColumn(label: 'Application ID', flex: 1.2),
      const ReportColumn(label: 'Applicant', flex: 1.4),
      const ReportColumn(label: 'Stall Name', flex: 1.5),
      const ReportColumn(label: 'Category', flex: 1.0),
      const ReportColumn(label: 'Date Submitted', flex: 1.2),
      const ReportColumn(label: 'Verification Status', flex: 1.1),
      if (hasReviewDetails) ...const [
        ReportColumn(label: 'Review Date', flex: 1.1),
        ReportColumn(label: 'Reviewer', flex: 1.1),
        ReportColumn(label: 'Rejection Reason', flex: 1.5),
      ],
    ];

    final rows = filteredApplications.map((item) {
      Color? statusColor;
      if (item.status == ApplicationStatus.verified) {
        statusColor = const Color(0xFF10B981);
      } else if (item.status == ApplicationStatus.reviewing) {
        statusColor = const Color(0xFFF59E0B);
      } else if (item.status == ApplicationStatus.rejected ||
          item.status == ApplicationStatus.invalidDocs) {
        statusColor = const Color(0xFFEF4444);
      }

      final cells = <Object?>[
        item.id,
        item.applicant,
        item.stallName,
        item.category,
        DateFormat('yyyy-MM-dd').format(item.submittedAt),
        enumLabel(item.status),
      ];

      if (hasReviewDetails) {
        cells.addAll([
          item.reviewedAt != null
              ? DateFormat('yyyy-MM-dd').format(item.reviewedAt!)
              : '—',
          item.reviewedBy ?? '—',
          item.rejectionReason ?? '—',
        ]);
      }

      return ReportRow(statusColor: statusColor, cells: cells);
    }).toList();

    return ExportDocument(
      filenamePrefix: ExportFilenameService.applicationsPrefix,
      reportName: 'Stall Holder Application Report',
      header: ReportHeader(
        reportTitle: 'Stall Holder Application Report',
        exportDate: now,
        activeFilters: activeFilters,
      ),
      summary: summary,
      table: ReportTable(columns: columns, rows: rows),
    );
  }
}

class RenewalExportData {
  RenewalExportData._();

  static ExportDocument build({
    required List<RenewalRequest> allRenewals,
    required List<RenewalRequest> filteredRenewals,
    required String activeFilters,
    DateTime? exportDate,
  }) {
    final now = exportDate ?? DateTime.now();

    final totalCount = allRenewals.length;
    final approvedCount =
        allRenewals.where((r) => r.status == RenewalStatus.approved).length;
    final expiring7dCount = allRenewals.where((r) {
      final days = r.expiryDate.difference(now).inDays;
      return days >= 0 && days <= 7 && r.status == RenewalStatus.reviewing;
    }).length;
    final expiredCount = allRenewals
        .where(
          (r) =>
              r.status == RenewalStatus.expired || r.expiryDate.isBefore(now),
        )
        .length;

    final summary = ReportSummary(
      title: 'REPORT SUMMARY',
      items: [
        ReportSummaryItem(
          label: 'Total Renewal Requests',
          value: '$totalCount',
          accent: const Color(0xFF3B82F6),
        ),
        ReportSummaryItem(
          label: 'Approved Renewals',
          value: '$approvedCount',
          accent: const Color(0xFF10B981),
        ),
        ReportSummaryItem(
          label: 'Expiring Within 7 Days',
          value: '$expiring7dCount',
          accent: const Color(0xFFF59E0B),
        ),
        ReportSummaryItem(
          label: 'Expired',
          value: '$expiredCount',
          accent: const Color(0xFFEF4444),
        ),
      ],
    );

    final columns = const [
      ReportColumn(label: 'Renewal/Application ID', flex: 1.3),
      ReportColumn(label: 'Applicant', flex: 1.4),
      ReportColumn(label: 'Stall Name', flex: 1.5),
      ReportColumn(label: 'Category', flex: 1.0),
      ReportColumn(label: 'Expiry Date', flex: 1.5),
      ReportColumn(label: 'Verification Status', flex: 1.1),
    ];

    final rows = filteredRenewals.map((r) {
      final daysLeft = r.expiryDate.difference(now).inDays;
      final expiryLabel = daysLeft < 0
          ? '${DateFormat('yyyy-MM-dd').format(r.expiryDate)} (Expired)'
          : '${DateFormat('yyyy-MM-dd').format(r.expiryDate)} ($daysLeft days left)';

      Color? statusColor;
      if (r.status == RenewalStatus.approved) {
        statusColor = const Color(0xFF10B981);
      } else if (r.status == RenewalStatus.reviewing) {
        statusColor = const Color(0xFFF59E0B);
      } else {
        statusColor = const Color(0xFFEF4444);
      }

      return ReportRow(
        statusColor: statusColor,
        cells: [
          r.id,
          r.applicant,
          r.stallName,
          r.category,
          expiryLabel,
          enumLabel(r.status),
        ],
      );
    }).toList();

    return ExportDocument(
      filenamePrefix: ExportFilenameService.renewalsPrefix,
      reportName: 'Renewal Report',
      header: ReportHeader(
        reportTitle: 'Renewal Report',
        exportDate: now,
        activeFilters: activeFilters,
      ),
      summary: summary,
      table: ReportTable(columns: columns, rows: rows),
    );
  }
}

class ComplaintExportData {
  ComplaintExportData._();

  static ExportDocument build({
    required List<Report> allReports,
    required List<Report> filteredReports,
    required String activeFilters,
    String? accountType,
    DateTime? exportDate,
  }) {
    final now = exportDate ?? DateTime.now();
    final audience = switch (accountType) {
      'Stall Holders' => 'Stall Holder',
      'Customers' => 'Customer',
      _ => null,
    };
    final reportTitle = audience == null
        ? 'Complaints Report'
        : '$audience Complaints Report';
    final reportName =
        audience == null ? 'Complaints Report' : '$audience Complaints';
    final filenamePrefix = switch (audience) {
      'Stall Holder' => ExportFilenameService.stallHolderComplaintsPrefix,
      'Customer' => ExportFilenameService.customerComplaintsPrefix,
      _ => ExportFilenameService.complaintsPrefix,
    };

    final pendingCount =
        allReports.where((r) => r.status == ReportStatus.pending).length;
    final underReviewCount =
        allReports.where((r) => r.status == ReportStatus.underReview).length;
    final resolvedCount =
        allReports.where((r) => r.status == ReportStatus.resolved).length;
    final blockedCount =
        allReports.where((r) => r.actionTaken == 'Account Blocked').length;

    final summary = ReportSummary(
      title: 'REPORT SUMMARY',
      items: [
        ReportSummaryItem(
          label: 'Pending Complaints',
          value: '$pendingCount',
          accent: const Color(0xFFEF4444),
        ),
        ReportSummaryItem(
          label: 'Under Review',
          value: '$underReviewCount',
          accent: const Color(0xFFF59E0B),
        ),
        ReportSummaryItem(
          label: 'Resolved',
          value: '$resolvedCount',
          accent: const Color(0xFF10B981),
        ),
        ReportSummaryItem(
          label: 'Blocked Accounts',
          value: '$blockedCount',
          accent: const Color(0xFF8B5CF6),
        ),
      ],
    );

    final hasResolution = filteredReports.any(
      (r) =>
          r.actionTaken != null || r.resolvedAt != null || r.resolvedBy != null,
    );

    final columns = [
      const ReportColumn(label: 'Type', flex: 1.0),
      const ReportColumn(label: 'Account / Issue', flex: 1.5),
      const ReportColumn(label: 'Submitted By', flex: 1.4),
      const ReportColumn(label: 'Violation Type', flex: 1.6),
      const ReportColumn(label: 'Category', flex: 1.0),
      const ReportColumn(label: 'Date', flex: 1.2),
      const ReportColumn(label: 'Status', flex: 1.1),
      const ReportColumn(label: 'Priority', flex: 1.0),
      if (hasResolution) ...const [
        ReportColumn(label: 'Admin Action', flex: 1.3),
        ReportColumn(label: 'Resolution Date', flex: 1.2),
      ],
    ];

    final rows = filteredReports.map((r) {
      Color? statusColor;
      if (r.status == ReportStatus.resolved) {
        statusColor = const Color(0xFF10B981);
      } else if (r.status == ReportStatus.underReview) {
        statusColor = const Color(0xFFF59E0B);
      } else {
        statusColor = const Color(0xFFEF4444);
      }

      final cells = <Object?>[
        r.type == 'Vendor' ? 'Stall Holder' : r.type,
        r.accountIssue,
        r.submittedBy,
        r.reason,
        r.category ?? 'FRESH FISH',
        DateFormat('yyyy-MM-dd').format(r.date),
        enumLabel(r.status),
        enumLabel(r.priority),
      ];

      if (hasResolution) {
        cells.addAll([
          r.actionTaken ?? '—',
          r.resolvedAt != null
              ? DateFormat('yyyy-MM-dd').format(r.resolvedAt!)
              : '—',
        ]);
      }

      return ReportRow(statusColor: statusColor, cells: cells);
    }).toList();

    return ExportDocument(
      filenamePrefix: filenamePrefix,
      reportName: reportName,
      header: ReportHeader(
        reportTitle: reportTitle,
        exportDate: now,
        activeFilters: activeFilters,
      ),
      summary: summary,
      table: ReportTable(columns: columns, rows: rows),
    );
  }
}

class AnnouncementExportData {
  AnnouncementExportData._();

  static ExportDocument build({
    required List<Announcement> allAnnouncements,
    required List<Announcement> filteredAnnouncements,
    required String activeFilters,
    String? audience,
    DateTime? exportDate,
  }) {
    final now = exportDate ?? DateTime.now();
    final audienceLabel = switch (audience) {
      'Stall Holders' => 'Stall Holder',
      'Customers' => 'Customer',
      _ => null,
    };
    final reportTitle = audienceLabel == null
        ? 'Announcement History Report'
        : '$audienceLabel Announcement History Report';
    final reportName = audienceLabel == null
        ? 'Announcement History Report'
        : '$audienceLabel Announcements';
    final filenamePrefix = switch (audienceLabel) {
      'Stall Holder' => ExportFilenameService.stallHolderAnnouncementsPrefix,
      'Customer' => ExportFilenameService.customerAnnouncementsPrefix,
      _ => ExportFilenameService.announcementsPrefix,
    };

    final totalCount = allAnnouncements.length;
    final deliveredNotices = allAnnouncements.fold<int>(
      0,
      (sum, a) => sum + a.deliveredCount,
    );
    final totalReach = allAnnouncements.fold<int>(
      0,
      (sum, a) => sum + a.recipientCount,
    );
    final draftOrQueued = allAnnouncements
        .where((a) => a.isDraft || a.state == 'Scheduled')
        .length;

    final summary = ReportSummary(
      title: 'REPORT SUMMARY',
      items: [
        ReportSummaryItem(
          label: 'Total Announcements',
          value: '$totalCount',
          accent: const Color(0xFF0F4A3C),
        ),
        ReportSummaryItem(
          label: 'Delivered Notices',
          value: '$deliveredNotices',
          accent: const Color(0xFF10B981),
        ),
        ReportSummaryItem(
          label: 'Total Audience Reach',
          value: '$totalReach',
          accent: const Color(0xFF3B82F6),
        ),
        ReportSummaryItem(
          label: 'Drafts & Queued',
          value: '$draftOrQueued',
          accent: const Color(0xFFF59E0B),
        ),
      ],
    );

    final columns = const [
      ReportColumn(label: 'Date & Time', flex: 1.3),
      ReportColumn(label: 'Announcement', flex: 1.8),
      ReportColumn(label: 'Audience', flex: 1.1),
      ReportColumn(label: 'Channel', flex: 1.2),
      ReportColumn(label: 'Reach', flex: 0.9, isNumeric: true),
      ReportColumn(label: 'Status', flex: 1.0),
    ];

    final rows = filteredAnnouncements.map((a) {
      Color? statusColor;
      final statusStr = a.isDraft ? 'Draft' : a.state;
      if (statusStr == 'Sent') {
        statusColor = const Color(0xFF10B981);
      } else if (statusStr == 'Scheduled') {
        statusColor = const Color(0xFF3B82F6);
      } else if (statusStr == 'Draft') {
        statusColor = const Color(0xFFF59E0B);
      } else {
        statusColor = const Color(0xFFEF4444);
      }

      return ReportRow(
        statusColor: statusColor,
        cells: [
          DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt),
          a.title,
          a.audience,
          a.notificationType,
          a.recipientCount,
          statusStr,
        ],
      );
    }).toList();

    return ExportDocument(
      filenamePrefix: filenamePrefix,
      reportName: reportName,
      header: ReportHeader(
        reportTitle: reportTitle,
        exportDate: now,
        activeFilters: activeFilters,
      ),
      summary: summary,
      table: ReportTable(columns: columns, rows: rows),
    );
  }
}

class AuditExportData {
  AuditExportData._();

  static ExportDocument build({
    required List<AuditLog> allLogs,
    required List<AuditLog> filteredLogs,
    required String activeFilters,
    DateTime? exportDate,
  }) {
    final now = exportDate ?? DateTime.now();

    final recordedActions = allLogs.length;
    final kycActions = allLogs
        .where(
          (l) =>
              l.action == AuditAction.approveKyc ||
              l.action == AuditAction.rejectKyc,
        )
        .length;
    final accountControls = allLogs
        .where(
          (l) =>
              l.action == AuditAction.blockAccount ||
              l.action == AuditAction.suspendAccount,
        )
        .length;

    final summary = ReportSummary(
      title: 'REPORT SUMMARY',
      items: [
        ReportSummaryItem(
          label: 'Recorded Actions',
          value: '$recordedActions',
          accent: const Color(0xFF3B82F6),
        ),
        ReportSummaryItem(
          label: 'KYC Actions',
          value: '$kycActions',
          accent: const Color(0xFF10B981),
        ),
        ReportSummaryItem(
          label: 'Account Controls',
          value: '$accountControls',
          accent: const Color(0xFFF59E0B),
        ),
      ],
    );

    final columns = const [
      ReportColumn(label: 'Timestamp', flex: 1.3),
      ReportColumn(label: 'Administrator', flex: 1.4),
      ReportColumn(label: 'Action', flex: 1.2),
      ReportColumn(label: 'Target', flex: 1.5),
      ReportColumn(label: 'Previous', flex: 1.1),
      ReportColumn(label: 'New Value', flex: 1.1),
      ReportColumn(label: 'Reason', flex: 1.3),
    ];

    // Maintain chronological order
    final sortedLogs = List<AuditLog>.from(filteredLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final rows = sortedLogs.map((l) {
      Color? statusColor;
      if (l.action == AuditAction.approveKyc ||
          l.action == AuditAction.unblockAccount) {
        statusColor = const Color(0xFF10B981);
      } else if (l.action == AuditAction.rejectKyc ||
          l.action == AuditAction.blockAccount) {
        statusColor = const Color(0xFFEF4444);
      } else if (l.action == AuditAction.suspendAccount) {
        statusColor = const Color(0xFFF59E0B);
      }

      final targetStr =
          '${l.targetEntityType} / ${l.targetEntityId.isEmpty ? l.targetUserName : l.targetEntityId}';

      return ReportRow(
        statusColor: statusColor,
        cells: [
          DateFormat('yyyy-MM-dd HH:mm:ss').format(l.timestamp),
          l.administratorName,
          enumLabel(l.action),
          targetStr,
          l.previousValue.isEmpty ? '—' : l.previousValue,
          l.newValue.isEmpty ? '—' : l.newValue,
          l.reason.isEmpty ? '—' : l.reason,
        ],
      );
    }).toList();

    return ExportDocument(
      filenamePrefix: ExportFilenameService.auditLogPrefix,
      reportName: 'Admin Audit Log Report',
      header: ReportHeader(
        reportTitle: 'Admin Audit Log Report',
        exportDate: now,
        activeFilters: activeFilters,
      ),
      summary: summary,
      table: ReportTable(columns: columns, rows: rows),
    );
  }
}

class SalesExportData {
  SalesExportData._();

  static ExportDocument build({
    required List<Order> allOrders,
    required List<Order> filteredOrders,
    required String activeFilters,
    required SalesSummary summary,
    DateTime? exportDate,
  }) {
    final now = exportDate ?? DateTime.now();

    final reportSummary = ReportSummary(
      title: 'REPORT SUMMARY',
      items: [
        ReportSummaryItem(
          label: 'Gross Sales',
          value: '₱${NumberFormat('#,##0.00').format(summary.grossSales)}',
          accent: const Color(0xFF10B981),
        ),
        ReportSummaryItem(
          label: 'Net Revenue',
          value: '₱${NumberFormat('#,##0.00').format(summary.netRevenue)}',
          accent: const Color(0xFF059669),
        ),
        ReportSummaryItem(
          label: 'Total Orders',
          value: '${summary.totalOrders}',
          accent: const Color(0xFF3B82F6),
        ),
        ReportSummaryItem(
          label: 'Completed Orders',
          value: '${summary.completedOrders}',
          accent: const Color(0xFF10B981),
        ),
        ReportSummaryItem(
          label: 'Refunds',
          value: '₱${NumberFormat('#,##0.00').format(summary.refunds)}',
          accent: const Color(0xFFEF4444),
        ),
      ],
    );

    final columns = const [
      ReportColumn(label: 'Order ID', flex: 1.1),
      ReportColumn(label: 'Date & Time', flex: 1.3),
      ReportColumn(label: 'Customer', flex: 1.4),
      ReportColumn(label: 'Stall Holder', flex: 1.5),
      ReportColumn(label: 'Total', flex: 1.1),
      ReportColumn(label: 'Payment', flex: 1.0),
      ReportColumn(label: 'Payment Status', flex: 1.1),
      ReportColumn(label: 'Order Status', flex: 1.1),
    ];

    final rows = filteredOrders.map((o) {
      Color? statusColor;
      if (o.status == OrderStatus.completed) {
        statusColor = const Color(0xFF10B981);
      } else if (o.status == OrderStatus.cancelled ||
          o.status == OrderStatus.refunded) {
        statusColor = const Color(0xFFEF4444);
      } else {
        statusColor = const Color(0xFFF59E0B);
      }

      return ReportRow(
        statusColor: statusColor,
        cells: [
          o.id,
          DateFormat('yyyy-MM-dd HH:mm').format(o.placedAt),
          o.customerName,
          o.vendorName,
          '₱${NumberFormat('#,##0.00').format(o.total)}',
          enumLabel(o.paymentMethod),
          enumLabel(o.paymentStatus),
          enumLabel(o.status),
        ],
      );
    }).toList();

    return ExportDocument(
      filenamePrefix: ExportFilenameService.salesPrefix,
      reportName: 'Sales Report',
      header: ReportHeader(
        reportTitle: 'Sales Report',
        exportDate: now,
        activeFilters: activeFilters,
      ),
      summary: reportSummary,
      table: ReportTable(columns: columns, rows: rows),
    );
  }
}
