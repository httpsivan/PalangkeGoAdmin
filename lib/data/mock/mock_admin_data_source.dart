import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/admin_models.dart';
import '../../models/app_models.dart';
import '../mock_data.dart';

/// Pure mock data persistence and seeding for local / offline demo mode.
/// Completely decoupled from Firebase services.
class MockAdminDataSource {
  const MockAdminDataSource(this._preferences);

  final SharedPreferences _preferences;

  static const defaultAdminName = 'Kirren Michael Fraginal';

  /// Initial seed state when no local modifications have occurred.
  static AppDataSeed initialSeeds() => AppDataSeed(
        vendors: seedVendors(),
        customers: seedCustomers(),
        applications: seedApplications(),
        renewals: seedRenewals(),
        reports: seedReports(),
        announcements: seedAnnouncements(),
        orders: seedOrders(),
        auditLogs: seedAuditLogs(),
        suspensions: seedSuspensions(),
      );

  /// Restores local overrides, status changes, and audits from SharedPreferences.
  AppDataSeed restore(AppDataSeed initial) {
    final blockedVendorIds =
        _preferences.getStringList('blocked_vendors')?.toSet() ??
            initial.vendors
                .where((vendor) => vendor.status == AccountStatus.blocked)
                .map((vendor) => vendor.id)
                .toSet();

    final unblockedVendorIds =
        _preferences.getStringList('unblocked_vendors')?.toSet() ?? <String>{};

    final blockedCustomerIds =
        _preferences.getStringList('blocked_customers')?.toSet() ??
            initial.customers
                .where((customer) => customer.status == AccountStatus.blocked)
                .map((customer) => customer.id)
                .toSet();

    final unblockedCustomerIds =
        _preferences.getStringList('unblocked_customers')?.toSet() ?? <String>{};

    final blockedDetails = readBlockedDetails();

    final restoredApplications = initial.applications
        .map((app) => restoreApplication(app))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final restoredRenewals =
        initial.renewals.map((r) => restoreRenewal(r)).toList();

    final storedSuspensions = readSuspensions();
    final effectiveSuspensions =
        storedSuspensions.isEmpty ? initial.suspensions : storedSuspensions;

    final activeSuspensionIds = effectiveSuspensions
        .where((s) => s.isActive)
        .map((s) => s.accountId)
        .toSet();

    final storedAudits = readAuditLogs();
    final effectiveAudits = storedAudits.isEmpty ? initial.auditLogs : storedAudits;

    final restoredVendors = initial.vendors
        .map(
          (vendor) => blockedVendorIds.contains(vendor.id)
              ? vendor.copyWith(
                  status: AccountStatus.blocked,
                  blockedReason: blockedDetails[vendor.id]?['reason'],
                  blockedFromReportId:
                      blockedDetails[vendor.id]?['relatedReportId'],
                  blockedAt: DateTime.tryParse(
                    blockedDetails[vendor.id]?['blockedAt'] ?? '',
                  ),
                  blockedBy: blockedDetails[vendor.id]?['blockedBy'],
                )
              : activeSuspensionIds.contains(vendor.id)
                  ? vendor.copyWith(status: AccountStatus.suspended)
                  : unblockedVendorIds.contains(vendor.id)
                      ? vendor.copyWith(status: AccountStatus.active)
                      : vendor,
        )
        .toList();

    final restoredCustomers = initial.customers
        .map(
          (customer) => blockedCustomerIds.contains(customer.id)
              ? customer.copyWith(
                  status: AccountStatus.blocked,
                  blockedReason: blockedDetails[customer.id]?['reason'],
                  blockedFromReportId:
                      blockedDetails[customer.id]?['relatedReportId'],
                  blockedAt: DateTime.tryParse(
                    blockedDetails[customer.id]?['blockedAt'] ?? '',
                  ),
                  blockedBy: blockedDetails[customer.id]?['blockedBy'],
                )
              : activeSuspensionIds.contains(customer.id)
                  ? customer.copyWith(status: AccountStatus.suspended)
                  : unblockedCustomerIds.contains(customer.id)
                      ? customer.copyWith(status: AccountStatus.active)
                      : customer,
        )
        .toList();

    final restoredReports =
        initial.reports.map((r) => restoreReport(r)).toList();

    return AppDataSeed(
      vendors: restoredVendors,
      customers: restoredCustomers,
      applications: restoredApplications,
      renewals: restoredRenewals,
      reports: restoredReports,
      announcements: initial.announcements,
      orders: initial.orders,
      auditLogs: effectiveAudits,
      suspensions: effectiveSuspensions,
    );
  }

  VendorApplication restoreApplication(VendorApplication app) {
    final raw = _preferences.getString('application_state_${app.id}');
    if (raw == null) return app;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return app.copyWith(
        status: ApplicationStatus.values.byName(map['status'] as String),
        rejectionReason: map['rejectionReason'] as String?,
      );
    } catch (_) {
      return app;
    }
  }

  RenewalRequest restoreRenewal(RenewalRequest renewal) {
    final raw = _preferences.getString('renewal_state_${renewal.id}');
    if (raw == null) return renewal;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return renewal.copyWith(
        status: RenewalStatus.values.byName(map['status'] as String),
      );
    } catch (_) {
      return renewal;
    }
  }

  Report restoreReport(Report report) {
    final raw = _preferences.getString('report_state_${report.id}');
    final legacyNote = _preferences.getString('report_notes_${report.id}');
    if (raw == null && legacyNote == null) return report;
    try {
      final map = raw == null
          ? <String, dynamic>{'notes': legacyNote}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final statusName = map['status'] as String?;
      return report.copyWith(
        status: statusName == null
            ? report.status
            : ReportStatus.values.byName(statusName),
        notes: map['notes'] as String? ?? report.notes,
        decision: map['decision'] as String?,
        actionTaken: map['actionTaken'] as String?,
        resolutionNote: map['resolutionNote'] as String?,
        resolvedAt: map['resolvedAt'] == null
            ? null
            : DateTime.tryParse(map['resolvedAt'] as String),
        resolvedBy: map['resolvedBy'] as String?,
      );
    } catch (_) {
      return report;
    }
  }

  Map<String, Map<String, String>> readBlockedDetails() {
    final raw = _preferences.getStringList('blocked_account_details') ?? [];
    final details = <String, Map<String, String>>{};
    for (final item in raw) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(item) as Map);
        final id = map['id'] as String?;
        if (id == null) continue;
        details[id] = {
          for (final entry in map.entries)
            if (entry.key != 'id' && entry.value != null)
              entry.key: entry.value.toString(),
        };
      } catch (_) {
        // Ignore malformed local overrides.
      }
    }
    return details;
  }

  List<AuditLog> readAuditLogs() {
    final raw = _preferences.getStringList('admin_audit_logs') ?? [];
    return raw
        .map((item) {
          try {
            return auditFromMap(jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<AuditLog>()
        .toList();
  }

  List<Suspension> readSuspensions() {
    final raw = _preferences.getStringList('admin_suspensions') ?? [];
    return raw
        .map((item) {
          try {
            return suspensionFromMap(jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Suspension>()
        .toList();
  }

  Future<void> persistSuspensions(List<Suspension> suspensions) =>
      _preferences.setStringList(
        'admin_suspensions',
        suspensions.map((item) => jsonEncode(suspensionToMap(item))).toList(),
      );

  Future<void> persistRenewal(RenewalRequest renewal) => _preferences.setString(
        'renewal_state_${renewal.id}',
        jsonEncode({'status': renewal.status.name}),
      );

  Future<void> persistApplication(VendorApplication app) =>
      _preferences.setString(
        'application_state_${app.id}',
        jsonEncode({
          'status': app.status.name,
          if (app.rejectionReason != null)
            'rejectionReason': app.rejectionReason,
        }),
      );

  Future<void> persistReport(Report report) => _preferences.setString(
        'report_state_${report.id}',
        jsonEncode({
          'status': report.status.name,
          'notes': report.notes,
          'decision': report.decision,
          'actionTaken': report.actionTaken,
          'resolutionNote': report.resolutionNote,
          'resolvedAt': report.resolvedAt?.toIso8601String(),
          'resolvedBy': report.resolvedBy,
        }),
      );

  Future<void> persistAuditLogs(List<AuditLog> auditLogs) =>
      _preferences.setStringList(
        'admin_audit_logs',
        auditLogs.map((item) => jsonEncode(auditToMap(item))).toList(),
      );

  Future<void> persistBlockedDetails({
    required List<Vendor> vendors,
    required List<Customer> customers,
  }) async {
    final details = <Map<String, dynamic>>[];
    for (final vendor in vendors) {
      if (vendor.status == AccountStatus.blocked) {
        details.add({
          'id': vendor.id,
          'reason': vendor.blockedReason ?? '',
          'reportId': vendor.blockedFromReportId ?? '',
          'blockedAt': vendor.blockedAt?.toIso8601String() ?? '',
          'blockedBy': vendor.blockedBy ?? '',
        });
      }
    }
    for (final customer in customers) {
      if (customer.status == AccountStatus.blocked) {
        details.add({
          'id': customer.id,
          'reason': customer.blockedReason ?? '',
          'reportId': customer.blockedFromReportId ?? '',
          'blockedAt': customer.blockedAt?.toIso8601String() ?? '',
          'blockedBy': customer.blockedBy ?? '',
        });
      }
    }
    await _preferences.setStringList(
      'blocked_account_details',
      details.map(jsonEncode).toList(),
    );
  }

  static Map<String, dynamic> auditToMap(AuditLog item) => {
        'id': item.id,
        'administratorId': item.administratorId,
        'administratorName': item.administratorName,
        'action': item.action.name,
        'targetEntityType': item.targetEntityType,
        'targetEntityId': item.targetEntityId,
        'targetUserName': item.targetUserName,
        'previousValue': item.previousValue,
        'newValue': item.newValue,
        'reason': item.reason,
        'metadata': item.metadata,
        'timestamp': item.timestamp.toIso8601String(),
      };

  static AuditLog auditFromMap(Map<String, dynamic> map) => AuditLog(
        id: map['id'] as String,
        administratorId: map['administratorId'] as String,
        administratorName: map['administratorName'] as String,
        action: AuditAction.values.byName(map['action'] as String),
        targetEntityType: map['targetEntityType'] as String,
        targetEntityId: map['targetEntityId'] as String,
        targetUserName: map['targetUserName'] as String,
        previousValue: map['previousValue'] as String,
        newValue: map['newValue'] as String,
        reason: map['reason'] as String,
        metadata: Map<String, String>.from(map['metadata'] as Map),
        timestamp: DateTime.parse(map['timestamp'] as String),
      );

  static Map<String, dynamic> suspensionToMap(Suspension item) => {
        'id': item.id,
        'accountId': item.accountId,
        'accountName': item.accountName,
        'accountType': item.accountType,
        'reason': item.reason,
        'startDate': item.startDate.toIso8601String(),
        'endDate': item.endDate.toIso8601String(),
        'administratorId': item.administratorId,
        'administratorName': item.administratorName,
        'createdAt': item.createdAt.toIso8601String(),
        'note': item.note,
        'notifyUser': item.notifyUser,
        'relatedReportId': item.relatedReportId,
        'liftedAt': item.liftedAt?.toIso8601String(),
      };

  static Suspension suspensionFromMap(Map<String, dynamic> map) => Suspension(
        id: map['id'] as String,
        accountId: map['accountId'] as String,
        accountName: map['accountName'] as String,
        accountType: map['accountType'] as String,
        reason: map['reason'] as String,
        startDate: DateTime.parse(map['startDate'] as String),
        endDate: DateTime.parse(map['endDate'] as String),
        administratorId: map['administratorId'] as String,
        administratorName: map['administratorName'] as String? ?? 'Administrator',
        createdAt: DateTime.parse(map['createdAt'] as String),
        note: map['note'] as String,
        notifyUser: map['notifyUser'] as bool,
        relatedReportId: map['relatedReportId'] as String?,
        liftedAt: map['liftedAt'] == null
            ? null
            : DateTime.parse(map['liftedAt'] as String),
      );
}

/// Data holder for restored seed collections.
class AppDataSeed {
  const AppDataSeed({
    required this.vendors,
    required this.customers,
    required this.applications,
    required this.renewals,
    required this.reports,
    required this.announcements,
    required this.orders,
    required this.auditLogs,
    required this.suspensions,
  });

  final List<Vendor> vendors;
  final List<Customer> customers;
  final List<VendorApplication> applications;
  final List<RenewalRequest> renewals;
  final List<Report> reports;
  final List<Announcement> announcements;
  final List<Order> orders;
  final List<AuditLog> auditLogs;
  final List<Suspension> suspensions;
}
