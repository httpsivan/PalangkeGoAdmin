import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../models/admin_models.dart';
import '../../models/app_models.dart';
import '../mock_data.dart';
import '../../core/theme/theme_controller.dart';
import 'firebase_admin_service.dart';
import 'supabase_admin_service.dart';

export 'auth_repository.dart';
import 'auth_repository.dart';
import '../mock/mock_admin_data_source.dart';

class AppDataState {
  const AppDataState({
    required this.vendors,
    required this.customers,
    required this.applications,
    required this.renewals,
    required this.reports,
    required this.announcements,
    this.orders = const [],
    this.suspensions = const [],
    this.auditLogs = const [],
  });

  final List<Vendor> vendors;
  final List<Customer> customers;
  final List<VendorApplication> applications;
  final List<RenewalRequest> renewals;
  final List<Report> reports;
  final List<Announcement> announcements;
  final List<Order> orders;
  final List<Suspension> suspensions;
  final List<AuditLog> auditLogs;

  AppDataState copyWith({
    List<Vendor>? vendors,
    List<Customer>? customers,
    List<VendorApplication>? applications,
    List<RenewalRequest>? renewals,
    List<Report>? reports,
    List<Announcement>? announcements,
    List<Order>? orders,
    List<Suspension>? suspensions,
    List<AuditLog>? auditLogs,
  }) {
    return AppDataState(
      vendors: vendors ?? this.vendors,
      customers: customers ?? this.customers,
      applications: applications ?? this.applications,
      renewals: renewals ?? this.renewals,
      reports: reports ?? this.reports,
      announcements: announcements ?? this.announcements,
      orders: orders ?? this.orders,
      suspensions: suspensions ?? this.suspensions,
      auditLogs: auditLogs ?? this.auditLogs,
    );
  }
}

class _ReportedAccountRef {
  const _ReportedAccountRef({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.isVendor,
  });

  final String id;
  final String name;
  final String type;
  final AccountStatus status;
  final bool isVendor;
}

final appDataProvider = StateNotifierProvider<AppDataController, AppDataState>((
  ref,
) {
  return AppDataController(
    ref.watch(sharedPreferencesProvider),
    firebaseEnabled: ref.read(firebaseEnabledProvider),
    supabaseEnabled: ref.read(supabaseEnabledProvider),
    supabase: ref.read(supabaseAdminServiceProvider),
  );
});

class AppDataController extends StateNotifier<AppDataState> {
  AppDataController(
    this._preferences, {
    required this.firebaseEnabled,
    this.supabaseEnabled = false,
    SupabaseAdminService? supabase,
  })  : _supabase = supabase,
        _dataSource = MockAdminDataSource(_preferences),
        super(
          // Firebase mode starts EMPTY — live data is loaded from Firestore;
          // seeded demo fiction must never render as real market data.
          firebaseEnabled || supabaseEnabled
              ? const AppDataState(
                  vendors: [],
                  customers: [],
                  applications: [],
                  renewals: [],
                  reports: [],
                  announcements: [],
                  orders: [],
                )
              : AppDataState(
                  vendors: seedVendors(),
                  customers: seedCustomers(),
                  applications: seedApplications(),
                  renewals: seedRenewals(),
                  reports: seedReports(),
                  announcements: seedAnnouncements(),
                  orders: seedOrders(),
                  auditLogs: seedAuditLogs(),
                  suspensions: seedSuspensions(),
                ),
        ) {
    if (firebaseEnabled && !supabaseEnabled) {
      _liveDataSubscription =
          FirebaseAdminService.instance.liveDataChanges.listen(
        (_) {
          _liveReloadTimer?.cancel();
          _liveReloadTimer = Timer(const Duration(milliseconds: 200), reload);
        },
        onError: (Object error) =>
            debugPrint('[admin] Firestore live update failed: $error'),
      );
    }
    if (supabaseEnabled) {
      _complaintChannel = _supabase?.subscribeToComplaintChanges(() {
        _complaintReloadTimer?.cancel();
        _complaintReloadTimer = Timer(
          const Duration(milliseconds: 200),
          _reloadComplaints,
        );
      });
    }
    if (firebaseEnabled || supabaseEnabled) {
      reload();
    } else {
      _restore();
    }
  }

  final SharedPreferences _preferences;
  final bool firebaseEnabled;
  final bool supabaseEnabled;
  final SupabaseAdminService? _supabase;
  final MockAdminDataSource _dataSource;
  StreamSubscription<void>? _liveDataSubscription;
  Timer? _liveReloadTimer;
  Timer? _complaintReloadTimer;
  RealtimeChannel? _complaintChannel;

  @override
  void dispose() {
    _liveReloadTimer?.cancel();
    _complaintReloadTimer?.cancel();
    if (_complaintChannel != null) {
      unawaited(
        _supabase?.client?.removeChannel(_complaintChannel!).then((_) {}),
      );
    }
    _liveDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _reloadComplaints() async {
    if (!supabaseEnabled || _supabase == null) return;
    try {
      final reports = await _supabase.fetchComplaints();
      if (!mounted) return;
      state = state.copyWith(reports: reports);
    } catch (error) {
      debugPrint('[admin] Realtime complaint refresh failed: $error');
    }
  }

  Future<void> _setAccountBlocked(String id, bool blocked) async {
    if (supabaseEnabled && _supabase != null) {
      final error = await _supabase.setAccountBlocked(id, blocked);
      if (error != null) throw StateError(error);
    }
    if (firebaseEnabled && !supabaseEnabled) {
      final error =
          await FirebaseAdminService.instance.setAccountBlocked(id, blocked);
      if (error != null) debugPrint('[admin] setAccountBlocked: $error');
    }
  }

  /// Loads server truth. Called on startup and after every trusted
  /// mutation — the callables (and their audit trail) are the source of
  /// record, so local state is replaced, not merged.
  Future<void> reload() async {
    if (!firebaseEnabled && !supabaseEnabled) return;
    AdminLiveData? data;
    if (firebaseEnabled && !supabaseEnabled) {
      try {
        data = await FirebaseAdminService.instance.loadAll();
      } catch (e) {
        debugPrint('[admin] Firestore reload failed: $e');
      }
    }
    SupabaseAccounts? accounts;
    List<VendorApplication>? applications;
    List<Report>? reports;
    List<Order>? orders;
    List<Announcement>? announcements;
    if (supabaseEnabled && _supabase != null) {
      try {
        final values = await Future.wait<Object>([
          _supabase.fetchAccounts(),
          _supabase.fetchApplications(),
          _supabase.fetchComplaints(),
          _supabase.fetchOrders(),
          _supabase.fetchAnnouncements(),
        ]);
        accounts = values[0] as SupabaseAccounts;
        applications = values[1] as List<VendorApplication>;
        reports = values[2] as List<Report>;
        orders = values[3] as List<Order>;
        announcements = values[4] as List<Announcement>;
      } catch (e) {
        debugPrint('[admin] Supabase reload failed: $e');
      }
    }
    state = state.copyWith(
      vendors: accounts?.vendors ?? data?.vendors,
      customers: accounts?.customers ?? data?.customers,
      applications: applications ?? data?.applications,
      reports: reports ?? state.reports,
      renewals: data?.renewals,
      orders: orders ?? data?.orders,
      auditLogs: data?.auditLogs,
      announcements: announcements ?? data?.announcements,
    );
  }

  Future<void> _restore() async {
    final restored = _dataSource.restore(MockAdminDataSource.initialSeeds());
    var restoredApplications = restored.applications;
    if (restoredApplications
        .where((item) => item.status == ApplicationStatus.reviewing)
        .isEmpty) {
      final keys = _preferences
          .getKeys()
          .where((k) => k.startsWith('application_state_'))
          .toList();
      for (final k in keys) {
        await _preferences.remove(k);
      }
      restoredApplications = seedApplications();
    }

    var restoredRenewals = restored.renewals;
    if (restoredRenewals
        .where((item) => item.status == RenewalStatus.reviewing)
        .isEmpty) {
      final keys = _preferences
          .getKeys()
          .where((k) => k.startsWith('renewal_state_'))
          .toList();
      for (final k in keys) {
        await _preferences.remove(k);
      }
      restoredRenewals = seedRenewals();
    }

    state = state.copyWith(
      vendors: restored.vendors,
      customers: restored.customers,
      applications: restoredApplications,
      renewals: restoredRenewals,
      reports: restored.reports,
      auditLogs: restored.auditLogs,
      suspensions: restored.suspensions,
    );
    await _expireSuspensions();
  }

  Future<void> setVendorStatus(String id, AccountStatus status) async {
    if (firebaseEnabled || supabaseEnabled) {
      if (status == AccountStatus.blocked || status == AccountStatus.active) {
        await _setAccountBlocked(id, status == AccountStatus.blocked);
      }
      await reload();
      return;
    }
    await _wait();
    final previous = _firstOrNull(state.vendors.where((item) => item.id == id));
    final vendors = state.vendors
        .map(
          (vendor) => vendor.id == id
              ? vendor.copyWith(
                  status: status,
                  clearBlockDetails: status == AccountStatus.active &&
                      previous?.status == AccountStatus.blocked,
                )
              : vendor,
        )
        .toList();
    state = state.copyWith(vendors: vendors);
    final blocked = vendors
        .where((vendor) => vendor.status == AccountStatus.blocked)
        .map((vendor) => vendor.id)
        .toList();
    await _preferences.setStringList('blocked_vendors', blocked);
    await _updateUnblockedOverride(
      key: 'unblocked_vendors',
      id: id,
      status: status,
    );
    await _persistBlockedDetails();
    await recordAudit(
      action: status == AccountStatus.blocked
          ? AuditAction.blockAccount
          : status == AccountStatus.active
              ? AuditAction.unblockAccount
              : AuditAction.editAccountStatus,
      targetEntityType: 'Stall Holder',
      targetEntityId: id,
      targetUserName: previous?.name ?? id,
      previousValue: enumLabel(previous?.status ?? AccountStatus.active),
      newValue: enumLabel(status),
      metadata: previous?.blockedFromReportId == null
          ? const {}
          : {'relatedReportId': previous!.blockedFromReportId!},
    );
  }

  Future<void> updateVendorAccount(
    String id, {
    required AccountStatus status,
    required String administrativeNotes,
  }) async {
    if (firebaseEnabled || supabaseEnabled) {
      if (status == AccountStatus.blocked || status == AccountStatus.active) {
        await _setAccountBlocked(id, status == AccountStatus.blocked);
      }
      await reload();
      return;
    }
    await _wait();
    final previous = _firstOrNull(state.vendors.where((item) => item.id == id));
    final vendors = state.vendors
        .map(
          (vendor) => vendor.id == id
              ? vendor.copyWith(
                  status: status,
                  administrativeNotes: administrativeNotes,
                  clearBlockDetails: status == AccountStatus.active &&
                      previous?.status == AccountStatus.blocked,
                )
              : vendor,
        )
        .toList();
    state = state.copyWith(vendors: vendors);
    final blocked = vendors
        .where((vendor) => vendor.status == AccountStatus.blocked)
        .map((vendor) => vendor.id)
        .toList();
    await _preferences.setStringList('blocked_vendors', blocked);
    await _updateUnblockedOverride(
      key: 'unblocked_vendors',
      id: id,
      status: status,
    );
    await _persistBlockedDetails();
    await recordAudit(
      action: status == AccountStatus.blocked
          ? AuditAction.blockAccount
          : status == AccountStatus.active
              ? AuditAction.unblockAccount
              : AuditAction.editAccountStatus,
      targetEntityType: 'Stall Holder',
      targetEntityId: id,
      targetUserName: previous?.name ?? id,
      previousValue: enumLabel(previous?.status ?? AccountStatus.active),
      newValue: enumLabel(status),
      reason: administrativeNotes,
      metadata: previous?.blockedFromReportId == null
          ? const {}
          : {'relatedReportId': previous!.blockedFromReportId!},
    );
  }

  Future<void> approveVendorClosure(
    String id, {
    required String administrativeNotes,
  }) async {
    final previous = _firstOrNull(state.vendors.where((item) => item.id == id));
    final hasActiveOrders = state.orders.any(
      (o) =>
          (o.transactionId == id || o.vendorName == previous?.name) &&
          (o.status == OrderStatus.pending ||
              o.status == OrderStatus.processing),
    );
    if (hasActiveOrders) {
      throw StateError(
        'Cannot close stall: vendor has active orders that must be completed or refunded first.',
      );
    }
    if (firebaseEnabled) {
      final error =
          await FirebaseAdminService.instance.setAccountBlocked(id, true);
      if (error != null) debugPrint('[admin] approveVendorClosure: $error');
      await reload();
      return;
    }
    await _wait();
    final vendors = state.vendors
        .map(
          (vendor) => vendor.id == id
              ? vendor.copyWith(
                  status: AccountStatus.blocked,
                  administrativeNotes: administrativeNotes,
                  blockedReason: vendor.closureReason?.isNotEmpty == true
                      ? 'Stall closed upon vendor request: ${vendor.closureReason}'
                      : 'Stall closed upon vendor request.',
                  blockedAt: DateTime.now(),
                  blockedBy: 'Admin',
                  clearClosureRequest: true,
                )
              : vendor,
        )
        .toList();
    state = state.copyWith(vendors: vendors);
    final blocked = vendors
        .where((vendor) => vendor.status == AccountStatus.blocked)
        .map((vendor) => vendor.id)
        .toList();
    await _preferences.setStringList('blocked_vendors', blocked);
    await _persistBlockedDetails();
    await recordAudit(
      action: AuditAction.blockAccount,
      targetEntityType: 'Stall Holder',
      targetEntityId: id,
      targetUserName: previous?.name ?? id,
      previousValue: enumLabel(previous?.status ?? AccountStatus.active),
      newValue: 'Closed / Blocked',
      reason: administrativeNotes,
      metadata: {
        if (previous?.closureReason != null)
          'closureReason': previous!.closureReason!,
        if (previous?.closureRequestedAt != null)
          'requestedAt': previous!.closureRequestedAt!.toIso8601String(),
      },
    );
  }

  Future<void> dismissVendorClosureRequest(
    String id, {
    required String administrativeNotes,
  }) async {
    await _wait();
    final previous = _firstOrNull(state.vendors.where((item) => item.id == id));
    final vendors = state.vendors
        .map(
          (vendor) => vendor.id == id
              ? vendor.copyWith(
                  administrativeNotes: administrativeNotes,
                  clearClosureRequest: true,
                )
              : vendor,
        )
        .toList();
    state = state.copyWith(vendors: vendors);
    await recordAudit(
      action: AuditAction.editAccountStatus,
      targetEntityType: 'Stall Holder',
      targetEntityId: id,
      targetUserName: previous?.name ?? id,
      previousValue: 'Closure Requested',
      newValue: enumLabel(previous?.status ?? AccountStatus.active),
      reason: administrativeNotes,
    );
  }

  Future<void> reassignVendorLocation(
    String id, {
    required String newLocation,
    String? newCategory,
    required String administrativeNotes,
  }) async {
    await _wait();
    final previous = _firstOrNull(state.vendors.where((item) => item.id == id));
    final vendors = state.vendors
        .map(
          (vendor) => vendor.id == id
              ? vendor.copyWith(
                  location: newLocation,
                  stallType: newCategory ?? vendor.stallType,
                  administrativeNotes: administrativeNotes,
                  clearRelocationRequest: true,
                )
              : vendor,
        )
        .toList();
    state = state.copyWith(vendors: vendors);
    await recordAudit(
      action: AuditAction.editAccountStatus,
      targetEntityType: 'Stall Holder',
      targetEntityId: id,
      targetUserName: previous?.name ?? id,
      previousValue: '${previous?.location} (${previous?.stallType})',
      newValue: '$newLocation (${newCategory ?? previous?.stallType})',
      reason: administrativeNotes,
    );
  }

  Future<void> updateCustomerAccount(
    String id, {
    required AccountStatus status,
    required String administrativeNotes,
  }) async {
    if (firebaseEnabled || supabaseEnabled) {
      if (status == AccountStatus.blocked || status == AccountStatus.active) {
        await _setAccountBlocked(id, status == AccountStatus.blocked);
      }
      await reload();
      return;
    }
    await _wait();
    final previous =
        _firstOrNull(state.customers.where((item) => item.id == id));
    state = state.copyWith(
      customers: state.customers
          .map(
            (customer) => customer.id == id
                ? customer.copyWith(
                    status: status,
                    administrativeNotes: administrativeNotes,
                    clearBlockDetails: status == AccountStatus.active &&
                        previous?.status == AccountStatus.blocked,
                  )
                : customer,
          )
          .toList(),
    );
    final blockedCustomers = state.customers
        .where((item) => item.status == AccountStatus.blocked)
        .map((item) => item.id)
        .toList();
    await _preferences.setStringList('blocked_customers', blockedCustomers);
    await _updateUnblockedOverride(
      key: 'unblocked_customers',
      id: id,
      status: status,
    );
    await _persistBlockedDetails();
    await recordAudit(
      action: status == AccountStatus.blocked
          ? AuditAction.blockAccount
          : status == AccountStatus.active
              ? AuditAction.unblockAccount
              : AuditAction.editAccountStatus,
      targetEntityType: 'Customer',
      targetEntityId: id,
      targetUserName: previous?.name ?? id,
      previousValue: enumLabel(previous?.status ?? AccountStatus.active),
      newValue: enumLabel(status),
      reason: administrativeNotes,
      metadata: previous?.blockedFromReportId == null
          ? const {}
          : {'relatedReportId': previous!.blockedFromReportId!},
    );
  }

  Future<void> _updateUnblockedOverride({
    required String key,
    required String id,
    required AccountStatus status,
  }) async {
    final ids = {
      ...?_preferences.getStringList(key),
    };
    if (status == AccountStatus.active) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await _preferences.setStringList(key, ids.toList()..sort());
  }

  Future<void> updateApplication(
    String id,
    ApplicationStatus status, {
    String? rejectionReason,
  }) async {
    if (firebaseEnabled || supabaseEnabled) {
      if (supabaseEnabled && _supabase != null) {
        final error = await _supabase.updateApplicationStatus(
          id,
          status,
          rejectionReason: rejectionReason,
        );
        if (error != null) throw StateError(error);
      }
      if (firebaseEnabled && !supabaseEnabled) {
        final error = status == ApplicationStatus.verified
            ? await FirebaseAdminService.instance.approveKyc(id)
            : await FirebaseAdminService.instance.rejectKyc(
                id,
                rejectionReason ?? 'Documents did not pass review.',
              );
        if (error != null) {
          debugPrint('[admin] Firebase approveKyc: $error');
        }
      }
      await reload(); // server truth (incl. its own audit entry) wins
      return;
    }
    await _wait();
    final current = _firstOrNull(
      state.applications.where((item) => item.id == id),
    );
    final reviewedAt = DateTime.now();

    final updatedApplications = state.applications
        .map(
          (item) => item.id == id
              ? item.copyWith(
                  status: status,
                  rejectionReason: rejectionReason,
                  reviewedAt: reviewedAt,
                  reviewedBy: 'ADM-001',
                )
              : item,
        )
        .toList();

    List<Vendor> updatedVendors = List<Vendor>.from(state.vendors);

    if (status == ApplicationStatus.verified && current != null) {
      final existingIndex = updatedVendors.indexWhere(
        (v) =>
            v.name.trim().toLowerCase() ==
                current.applicant.trim().toLowerCase() ||
            v.id == 'VND-${current.id.replaceAll(RegExp(r'[^0-9]'), '')}',
      );
      if (existingIndex >= 0) {
        updatedVendors[existingIndex] = updatedVendors[existingIndex].copyWith(
          status: AccountStatus.active,
          administrativeNotes:
              'Account reactivated upon KYC application approval.',
        );
      } else {
        final cleanName = current.applicant
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '.');
        final digits = current.id.replaceAll(RegExp(r'[^0-9]'), '');
        final newVendor = Vendor(
          id: 'VND-$digits',
          name: current.applicant,
          email: '${cleanName.isEmpty ? 'vendor' : cleanName}@gmail.com',
          stallType: current.category,
          registeredAt: reviewedAt,
          status: AccountStatus.active,
          location: current.location.isNotEmpty
              ? current.location
              : 'Section A, Stall #1',
          orders: 0,
          transactions: 0.0,
          phone: '+63 921 555 ${1000 + updatedVendors.length}',
          residence: 'Brgy. Peñafrancia, Naga City',
          administrativeNotes:
              'Account automatically created upon KYC application approval. Stall allocation locked to ${current.location}.',
        );
        updatedVendors.insert(0, newVendor);
      }
    }

    state = state.copyWith(
      applications: updatedApplications,
      vendors: updatedVendors,
    );

    final updated =
        _firstOrNull(state.applications.where((item) => item.id == id));
    if (updated != null) await _persistApplication(updated);
    await recordAudit(
      action: status == ApplicationStatus.verified
          ? AuditAction.approveKyc
          : AuditAction.rejectKyc,
      targetEntityType: 'KYC Submission',
      targetEntityId: id,
      targetUserName: current?.applicant ?? id,
      previousValue: enumLabel(current?.status ?? ApplicationStatus.reviewing),
      newValue: enumLabel(status),
      reason: rejectionReason ??
          (status == ApplicationStatus.verified
              ? 'Approved & stall allocation locked to ${current?.location ?? "unassigned"}'
              : ''),
    );
  }

  Future<void> updateRenewal(
    String id,
    RenewalStatus status, {
    String? rejectionReason,
  }) async {
    if (firebaseEnabled) {
      final error = status == RenewalStatus.approved
          ? await FirebaseAdminService.instance.approveRenewal(id)
          : await FirebaseAdminService.instance.rejectRenewal(
              id,
              rejectionReason ?? 'Renewal did not pass review.',
            );
      if (error != null) {
        debugPrint('[admin] approveRenewal failed: $error');
      }
      await reload();
      return;
    }
    await _wait();
    final current = _firstOrNull(state.renewals.where((item) => item.id == id));

    final updatedRenewals = state.renewals
        .map(
          (item) => item.id == id
              ? item.copyWith(
                  status: status,
                  rejectionReason: rejectionReason,
                )
              : item,
        )
        .toList();

    List<Vendor> updatedVendors = List<Vendor>.from(state.vendors);

    if (status == RenewalStatus.approved && current != null) {
      final now = DateTime.now();
      final targetYear =
          (now.month > 1 || (now.month == 1 && now.day > 7)) ? 2027 : 2026;
      final existingIndex = updatedVendors.indexWhere(
        (v) =>
            v.name.trim().toLowerCase() ==
                current.applicant.trim().toLowerCase() ||
            v.location.trim().toLowerCase() ==
                current.location.trim().toLowerCase(),
      );
      if (existingIndex >= 0) {
        updatedVendors[existingIndex] = updatedVendors[existingIndex].copyWith(
          status: AccountStatus.active,
          administrativeNotes:
              'Stall lease contract renewed and extended to $targetYear-01-07.',
        );
      }
    }

    state = state.copyWith(
      renewals: updatedRenewals,
      vendors: updatedVendors,
    );
    final updated = _firstOrNull(state.renewals.where((item) => item.id == id));
    if (updated != null) await _persistRenewal(updated);
    await recordAudit(
      action: AuditAction.editAccountStatus,
      targetEntityType: 'Renewal',
      targetEntityId: id,
      targetUserName: current?.applicant ?? id,
      previousValue: enumLabel(current?.status ?? RenewalStatus.reviewing),
      newValue: enumLabel(status),
      reason: rejectionReason ?? '',
    );
  }

  Future<String?> updateReport(
    String id,
    ReportStatus status,
    String notes,
  ) async {
    await _wait();
    final current = _firstOrNull(state.reports.where((item) => item.id == id));
    if (current == null) return 'Report not found.';
    if (supabaseEnabled && _supabase != null) {
      final backendStatus = switch (status) {
        ReportStatus.underReview => 'reviewing',
        ReportStatus.resolved => 'resolved',
        ReportStatus.dismissed => 'dismissed',
        ReportStatus.pending => null,
      };
      if (backendStatus == null) return 'Unsupported complaint status.';
      final error = await _supabase.reviewComplaint(
        complaintId: id,
        status: backendStatus,
        adminNotes: notes,
      );
      if (error != null) return error;
    }
    state = state.copyWith(
      reports: state.reports
          .map(
            (item) => item.id == id
                ? item.copyWith(status: status, notes: notes)
                : item,
          )
          .toList(),
    );
    await _preferences.setString('report_notes_$id', notes);
    final updated = _firstOrNull(state.reports.where((item) => item.id == id));
    if (updated != null) await _persistReport(updated);
    await recordAudit(
      action: AuditAction.resolveReport,
      targetEntityType: 'Report',
      targetEntityId: id,
      targetUserName: id,
      previousValue: enumLabel(current.status),
      newValue: enumLabel(status),
      reason: notes,
    );
    return null;
  }

  Future<String?> dismissReport({
    required String reportId,
    required String note,
    String decision = 'No Violation',
    String actionTaken = 'Dismissed',
  }) async {
    await _wait();
    final report = _firstOrNull(
      state.reports.where((item) => item.id == reportId),
    );
    if (report == null) return 'Report not found.';
    if (report.status == ReportStatus.resolved) {
      return 'This report has already been resolved.';
    }

    if (supabaseEnabled && _supabase != null) {
      final error = await _supabase.reviewComplaint(
        complaintId: reportId,
        status: 'dismissed',
        adminNotes: note,
      );
      if (error != null) return error;
    }

    final now = DateTime.now();
    final administrator =
        _preferences.getString('admin_name') ?? defaultAdminName;
    final updated = report.copyWith(
      status: ReportStatus.resolved,
      decision: decision,
      actionTaken: actionTaken,
      resolutionNote: note.trim(),
      resolvedAt: now,
      resolvedBy: administrator,
      notes: note.trim().isEmpty ? report.notes : note.trim(),
    );
    state = state.copyWith(
      reports: state.reports
          .map((item) => item.id == report.id ? updated : item)
          .toList(),
    );
    await _persistReport(updated);
    await recordAudit(
      action: AuditAction.resolveReport,
      targetEntityType: 'Report',
      targetEntityId: report.id,
      targetUserName: report.accountIssue,
      previousValue: enumLabel(report.status),
      newValue: 'Resolved',
      reason: note.trim(),
      metadata: {
        'decision': decision,
        'actionTaken': actionTaken,
        'accountStatus': 'Unchanged',
        'sourceReportId': report.id,
      },
    );
    return null;
  }

  Future<String?> resolveReport({
    required String reportId,
    required String note,
  }) =>
      dismissReport(
        reportId: reportId,
        note: note,
        decision: 'Resolved',
        actionTaken: 'Marked as Resolved',
      );

  Future<String?> suspendAccountFromReport({
    required String reportId,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) return 'A suspension reason is required.';
    if (!endDate.isAfter(startDate)) {
      return 'The suspension end date must be after the start date.';
    }
    if (endDate.isBefore(DateTime.now())) {
      return 'The suspension cannot end in the past.';
    }

    await _wait();
    final report = _firstOrNull(
      state.reports.where((item) => item.id == reportId),
    );
    if (report == null) return 'Report not found.';
    if (report.status == ReportStatus.resolved) {
      return 'This report has already been resolved.';
    }
    final account = _findReportedAccount(report);
    if (account == null) return 'The reported account could not be found.';
    if (account.status == AccountStatus.blocked) {
      return 'A blocked account cannot be suspended.';
    }
    if (state.suspensions
        .any((item) => item.accountId == account.id && item.isActive)) {
      return 'This account already has an active suspension.';
    }

    final now = DateTime.now();
    final administrator =
        _preferences.getString('admin_name') ?? defaultAdminName;
    final suspension = Suspension(
      id: 'SUS-${now.microsecondsSinceEpoch}',
      accountId: account.id,
      accountName: account.name,
      accountType: account.type,
      reason: cleanReason,
      startDate: startDate,
      endDate: endDate,
      administratorId: 'ADM-001',
      administratorName: administrator,
      createdAt: now,
      note: cleanReason,
      notifyUser: false,
      relatedReportId: report.id,
    );
    final updated = report.copyWith(
      status: ReportStatus.resolved,
      decision: 'Account Suspended',
      actionTaken: 'Account Suspended',
      resolutionNote: cleanReason,
      resolvedAt: now,
      resolvedBy: administrator,
      notes: cleanReason,
    );
    state = state.copyWith(
      suspensions: [suspension, ...state.suspensions],
      vendors: state.vendors
          .map((item) => item.id == account.id
              ? item.copyWith(status: AccountStatus.suspended)
              : item)
          .toList(),
      customers: state.customers
          .map((item) => item.id == account.id
              ? item.copyWith(status: AccountStatus.suspended)
              : item)
          .toList(),
      reports: state.reports
          .map((item) => item.id == report.id ? updated : item)
          .toList(),
    );
    await _persistSuspensions();
    await _persistReport(updated);
    await recordAudit(
      action: AuditAction.suspendAccount,
      targetEntityType: account.type,
      targetEntityId: account.id,
      targetUserName: account.name,
      previousValue: enumLabel(account.status),
      newValue: 'Suspended',
      reason: cleanReason,
      metadata: {
        'sourceReportId': report.id,
        'reportDecision': 'Account Suspended',
        'suspensionId': suspension.id,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );
    return null;
  }

  Future<String?> blockAccountFromReport({
    required String reportId,
    required String reason,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) return 'A blocking reason is required.';

    await _wait();
    final report = _firstOrNull(
      state.reports.where((item) => item.id == reportId),
    );
    if (report == null) return 'Report not found.';
    if (report.status == ReportStatus.resolved) {
      return 'This report has already been resolved.';
    }
    final account = _findReportedAccount(report);
    if (account == null) return 'The reported account could not be found.';
    if (account.status == AccountStatus.blocked) {
      return 'This account is already blocked.';
    }

    if (supabaseEnabled && _supabase != null) {
      final blockError = await _supabase.setAccountBlocked(account.id, true);
      if (blockError != null) return blockError;
      final reviewError = await _supabase.reviewComplaint(
        complaintId: reportId,
        status: 'resolved',
        adminNotes: cleanReason,
      );
      if (reviewError != null) return reviewError;
    }

    final now = DateTime.now();
    final administrator =
        _preferences.getString('admin_name') ?? defaultAdminName;
    final suspensions = state.suspensions
        .map(
          (item) => item.accountId == account.id && item.isActive
              ? item.lift(now)
              : item,
        )
        .toList();
    final updated = report.copyWith(
      status: ReportStatus.resolved,
      decision: 'Account Blocked',
      actionTaken: 'Account Blocked',
      resolutionNote: cleanReason,
      resolvedAt: now,
      resolvedBy: administrator,
      notes: cleanReason,
    );
    state = state.copyWith(
      suspensions: suspensions,
      vendors: account.isVendor
          ? state.vendors
              .map((item) => item.id == account.id
                  ? item.copyWith(
                      status: AccountStatus.blocked,
                      blockedReason: cleanReason,
                      blockedFromReportId: report.id,
                      blockedAt: now,
                      blockedBy: administrator,
                    )
                  : item)
              .toList()
          : state.vendors,
      customers: account.isVendor
          ? state.customers
          : state.customers
              .map((item) => item.id == account.id
                  ? item.copyWith(
                      status: AccountStatus.blocked,
                      blockedReason: cleanReason,
                      blockedFromReportId: report.id,
                      blockedAt: now,
                      blockedBy: administrator,
                    )
                  : item)
              .toList(),
      reports: state.reports
          .map((item) => item.id == report.id ? updated : item)
          .toList(),
    );
    await _persistBlockedAccountIds();
    await _persistBlockedDetails();
    await _persistSuspensions();
    await _persistReport(updated);
    await recordAudit(
      action: AuditAction.blockAccount,
      targetEntityType: account.type,
      targetEntityId: account.id,
      targetUserName: account.name,
      previousValue: enumLabel(account.status),
      newValue: 'Blocked',
      reason: cleanReason,
      metadata: {
        'sourceReportId': report.id,
        'reportDecision': 'Account Blocked',
      },
    );
    return null;
  }

  _ReportedAccountRef? _findReportedAccount(Report report) {
    if (report.type == 'Vendor' || report.type == 'Stall Holder') {
      final vendor = _firstOrNull(state.vendors.where(
        (item) =>
            item.name == report.accountIssue || item.name == report.vendorName,
      ));
      if (vendor == null) return null;
      return _ReportedAccountRef(
        id: vendor.id,
        name: vendor.name,
        type: 'Stall Holder',
        status: vendor.status,
        isVendor: true,
      );
    }
    if (report.type == 'Customer') {
      final customer = _firstOrNull(state.customers.where(
        (item) => item.name == report.accountIssue,
      ));
      if (customer != null) {
        return _ReportedAccountRef(
          id: customer.id,
          name: customer.name,
          type: 'Customer',
          status: customer.status,
          isVendor: false,
        );
      }

      final vendor = _firstOrNull(state.vendors.where(
        (item) => item.name == report.vendorName,
      ));
      if (vendor != null) {
        return _ReportedAccountRef(
          id: vendor.id,
          name: vendor.name,
          type: 'Stall Holder',
          status: vendor.status,
          isVendor: true,
        );
      }
    }
    return null;
  }

  Future<void> addAnnouncement(Announcement announcement) async {
    if (firebaseEnabled || supabaseEnabled) {
      final targetAudience = switch (announcement.audience.toLowerCase()) {
        'stall holders' || 'vendors' => 'stallholders',
        'customers' => 'customers',
        _ => 'all',
      };
      if (supabaseEnabled && _supabase != null) {
        final error = await _supabase.publishAnnouncement(
          title: announcement.title,
          body: announcement.summary,
          audience: targetAudience,
          expiresAt: announcement.expiresAt,
          imageUrl: announcement.imageUrl,
          imageBytes: announcement.imageBytes,
          showAsPopup: announcement.showAsPopup,
          facebookUrl: announcement.facebookUrl,
          popupImageUrls: announcement.popupImageUrls,
          popupImageBytes: announcement.popupImageBytes,
        );
        if (error != null) throw StateError(error);
      } else {
        await FirebaseAdminService.instance.publishAnnouncement(
          title: announcement.title,
          body: announcement.summary,
          targetAudience: targetAudience,
          expiresAt: announcement.expiresAt,
          imageUrl: announcement.imageUrl,
        );
      }
      await reload();
      return;
    }
    await _wait();
    state = state.copyWith(
      announcements: [announcement, ...state.announcements],
    );
    await _preferences.setString('last_announcement', announcement.title);
    await recordAudit(
      action: AuditAction.sendAnnouncement,
      targetEntityType: 'Announcement',
      targetEntityId:
          announcement.id.isEmpty ? announcement.title : announcement.id,
      targetUserName: announcement.audience,
      previousValue: '',
      newValue: announcement.title,
    );
  }

  Future<void> updateAnnouncement(Announcement updated) async {
    if (firebaseEnabled || supabaseEnabled) {
      final targetAudience = switch (updated.audience.toLowerCase()) {
        'stall holders' || 'vendors' => 'stallholders',
        'customers' => 'customers',
        _ => 'all',
      };
      if (supabaseEnabled && _supabase != null) {
        final error = await _supabase.updateAnnouncement(
          id: updated.id,
          title: updated.title,
          body: updated.summary,
          audience: targetAudience,
          expiresAt: updated.expiresAt,
          imageUrl: updated.imageUrl,
          imageBytes: updated.imageBytes,
          clearImage: updated.showAsPopup ||
              (updated.imageBytes == null &&
                  (updated.imageUrl == null || updated.imageUrl!.isEmpty)),
          showAsPopup: updated.showAsPopup,
          facebookUrl: updated.facebookUrl,
          popupImageUrls: updated.popupImageUrls,
          popupImageBytes: updated.popupImageBytes,
        );
        if (error != null) throw StateError(error);
      } else {
        await FirebaseAdminService.instance.updateAnnouncement(
          id: updated.id,
          title: updated.title,
          body: updated.summary,
          targetAudience: targetAudience,
          expiresAt: updated.expiresAt,
          imageUrl: updated.imageUrl,
        );
      }
      await reload();
      return;
    }
    await _wait();
    final previous =
        state.announcements.where((a) => a.id == updated.id).firstOrNull;
    state = state.copyWith(
      announcements: state.announcements
          .map((a) => a.id == updated.id ? updated : a)
          .toList(),
    );
    await _preferences.setString('last_announcement', updated.title);
    if (previous != null) {
      await recordAudit(
        action: AuditAction.changeSettings,
        targetEntityType: 'Announcement',
        targetEntityId: updated.id,
        targetUserName: updated.audience,
        previousValue: previous.title,
        newValue: updated.title,
      );
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    if (firebaseEnabled || supabaseEnabled) {
      if (supabaseEnabled && _supabase != null) {
        final error = await _supabase.deleteAnnouncement(id);
        if (error != null) throw StateError(error);
      } else {
        await FirebaseAdminService.instance.deleteAnnouncement(id);
      }
      await reload();
      return;
    }
    await _wait();
    final target = state.announcements.where((a) => a.id == id).firstOrNull;
    state = state.copyWith(
      announcements: state.announcements.where((a) => a.id != id).toList(),
    );
    if (target != null) {
      await recordAudit(
        action: AuditAction.changeSettings,
        targetEntityType: 'Announcement',
        targetEntityId: target.id,
        targetUserName: target.audience,
        previousValue: target.title,
        newValue: 'Deleted',
      );
    }
  }

  Future<String?> createSuspension({
    required String accountId,
    required String accountName,
    required String accountType,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
    required String note,
    required bool notifyUser,
    String? relatedReportId,
  }) async {
    if (reason.trim().isEmpty) return 'A suspension reason is required.';
    if (!endDate.isAfter(startDate)) {
      return 'The suspension end date must be after the start date.';
    }
    if (endDate.isBefore(DateTime.now())) {
      return 'The suspension cannot end in the past.';
    }
    final vendor =
        _firstOrNull(state.vendors.where((item) => item.id == accountId));
    final customer = _firstOrNull(
      state.customers.where((item) => item.id == accountId),
    );
    final currentStatus = vendor?.status ?? customer?.status;
    if (currentStatus == null) return 'The account could not be found.';
    if (currentStatus == AccountStatus.blocked) {
      return 'A blocked account cannot be suspended.';
    }
    if (state.suspensions
        .any((item) => item.accountId == accountId && item.isActive)) {
      return 'This account already has an active suspension.';
    }
    final suspension = Suspension(
      id: 'SUS-${DateTime.now().millisecondsSinceEpoch}',
      accountId: accountId,
      accountName: accountName,
      accountType: accountType,
      reason: reason.trim(),
      startDate: startDate,
      endDate: endDate,
      administratorId: 'ADM-001',
      administratorName:
          _preferences.getString('admin_name') ?? defaultAdminName,
      createdAt: DateTime.now(),
      note: note.trim(),
      notifyUser: notifyUser,
      relatedReportId: relatedReportId,
    );
    state = state.copyWith(
      suspensions: [suspension, ...state.suspensions],
      vendors: state.vendors
          .map((item) => item.id == accountId
              ? item.copyWith(status: AccountStatus.suspended)
              : item)
          .toList(),
      customers: state.customers
          .map((item) => item.id == accountId
              ? item.copyWith(status: AccountStatus.suspended)
              : item)
          .toList(),
    );
    await _persistSuspensions();
    await recordAudit(
      action: AuditAction.suspendAccount,
      targetEntityType: accountType,
      targetEntityId: accountId,
      targetUserName: accountName,
      previousValue: enumLabel(currentStatus),
      newValue: 'Suspended',
      reason: reason,
      metadata: {
        'endDate': endDate.toIso8601String(),
        if (relatedReportId != null) 'relatedReportId': relatedReportId,
      },
    );
    return null;
  }

  Future<String?> liftSuspension(String suspensionId) async {
    final current = _firstOrNull(
      state.suspensions.where((item) => item.id == suspensionId),
    );
    if (current == null) return 'Suspension not found.';
    final lifted = current.lift(DateTime.now());
    state = state.copyWith(
      suspensions: state.suspensions
          .map((item) => item.id == suspensionId ? lifted : item)
          .toList(),
      vendors: state.vendors
          .map((item) => item.id == current.accountId
              ? item.copyWith(status: AccountStatus.active)
              : item)
          .toList(),
      customers: state.customers
          .map((item) => item.id == current.accountId
              ? item.copyWith(status: AccountStatus.active)
              : item)
          .toList(),
    );
    await _persistSuspensions();
    await recordAudit(
      action: AuditAction.liftSuspension,
      targetEntityType: current.accountType,
      targetEntityId: current.accountId,
      targetUserName: current.accountName,
      previousValue: 'Suspended',
      newValue: 'Active',
      reason: 'Suspension lifted early',
      metadata: current.relatedReportId == null
          ? const {}
          : {'relatedReportId': current.relatedReportId!},
    );
    return null;
  }

  Future<void> _expireSuspensions() async {
    final expired = state.suspensions.where((item) => item.isExpired).toList();
    if (expired.isEmpty) return;
    final ids = expired.map((item) => item.accountId).toSet();
    state = state.copyWith(
      suspensions: state.suspensions
          .map((item) => item.isExpired ? item.lift(item.endDate) : item)
          .toList(),
      vendors: state.vendors
          .map((item) =>
              ids.contains(item.id) && item.status == AccountStatus.suspended
                  ? item.copyWith(status: AccountStatus.active)
                  : item)
          .toList(),
      customers: state.customers
          .map((item) =>
              ids.contains(item.id) && item.status == AccountStatus.suspended
                  ? item.copyWith(status: AccountStatus.active)
                  : item)
          .toList(),
    );
    await _persistSuspensions();
    for (final item in expired) {
      await recordAudit(
        action: AuditAction.liftSuspension,
        targetEntityType: item.accountType,
        targetEntityId: item.accountId,
        targetUserName: item.accountName,
        previousValue: 'Suspended',
        newValue: 'Active',
        reason: 'Suspension expired automatically',
        metadata: item.relatedReportId == null
            ? const {}
            : {'relatedReportId': item.relatedReportId!},
      );
    }
  }

  Future<void> recordAudit({
    required AuditAction action,
    required String targetEntityType,
    required String targetEntityId,
    required String targetUserName,
    required String previousValue,
    required String newValue,
    String reason = '',
    Map<String, String> metadata = const {},
  }) async {
    final audit = AuditLog(
      id: 'AUD-${DateTime.now().microsecondsSinceEpoch}',
      administratorId: 'ADM-001',
      administratorName:
          _preferences.getString('admin_name') ?? defaultAdminName,
      action: action,
      targetEntityType: targetEntityType,
      targetEntityId: targetEntityId,
      targetUserName: targetUserName,
      previousValue: previousValue,
      newValue: newValue,
      reason: reason,
      metadata: metadata,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(auditLogs: [audit, ...state.auditLogs]);
    await _dataSource.persistAuditLogs(state.auditLogs);
  }

  Future<void> _persistBlockedAccountIds() async {
    await _preferences.setStringList(
      'blocked_vendors',
      state.vendors
          .where((item) => item.status == AccountStatus.blocked)
          .map((item) => item.id)
          .toList(),
    );
    await _preferences.setStringList(
      'blocked_customers',
      state.customers
          .where((item) => item.status == AccountStatus.blocked)
          .map((item) => item.id)
          .toList(),
    );
  }

  Future<void> _persistBlockedDetails() => _dataSource.persistBlockedDetails(
        vendors: state.vendors,
        customers: state.customers,
      );

  Future<void> _persistApplication(VendorApplication application) =>
      _dataSource.persistApplication(application);

  Future<void> resetMockRenewals() async {
    final keys = _preferences
        .getKeys()
        .where((k) => k.startsWith('renewal_state_'))
        .toList();
    for (final key in keys) {
      await _preferences.remove(key);
    }
    state = state.copyWith(renewals: seedRenewals());
  }

  Future<void> resetMockApplications() async {
    final keys = _preferences
        .getKeys()
        .where((k) => k.startsWith('application_state_'))
        .toList();
    for (final key in keys) {
      await _preferences.remove(key);
    }
    state = state.copyWith(applications: seedApplications());
  }

  Future<void> _persistRenewal(RenewalRequest renewal) =>
      _dataSource.persistRenewal(renewal);

  Future<void> _persistReport(Report report) =>
      _dataSource.persistReport(report);

  Future<void> _persistSuspensions() =>
      _dataSource.persistSuspensions(state.suspensions);

  Future<void> _wait() => Future<void>.value();
}

T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;
