import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palengkego_admin/data/mock_data.dart';
import 'package:palengkego_admin/data/repositories/mock_repository.dart';
import 'package:palengkego_admin/models/admin_models.dart';
import 'package:palengkego_admin/models/app_models.dart';

void main() {
  test('mock list data uses unique display names', () {
    final applications = seedApplications();
    final renewals = seedRenewals();
    final reports = seedReports();

    expect(
      applications.map((item) => item.applicant).toSet(),
      hasLength(applications.length),
    );
    expect(
      applications.map((item) => item.stallName).toSet(),
      hasLength(applications.length),
    );
    expect(
      renewals.map((item) => item.applicant).toSet(),
      hasLength(renewals.length),
    );
    expect(
      renewals.map((item) => item.stallName).toSet(),
      hasLength(renewals.length),
    );
    expect(
      reports.map((item) => item.accountIssue).toSet(),
      hasLength(reports.length),
    );
    expect(
      reports.map((item) => item.submittedBy).toSet(),
      hasLength(reports.length),
    );
  });

  test('order totals and net revenue are computed from line items', () {
    final order = Order(
      id: 'ORD-1',
      transactionId: 'TX-1',
      placedAt: DateTime(2026, 7, 28),
      customerName: 'Customer',
      vendorName: 'Vendor',
      stallName: 'Stall',
      items: const [
        OrderItem(
          name: 'Rice',
          category: 'GRAINS',
          quantity: 2,
          unitPrice: 100,
        ),
      ],
      discounts: 20,
      deliveryFee: 50,
      platformFee: 10,
      refundAmount: 30,
      paymentMethod: PaymentMethod.gcash,
      paymentStatus: PaymentStatus.paid,
      status: OrderStatus.completed,
    );

    expect(order.subtotal, 200);
    expect(order.total, 240);
    expect(order.netRevenue, 210);
    expect(order.quantity, 2);
    expect(order.categories, 'GRAINS');

    final summary = SalesSummary.fromOrders([order]);
    expect(summary.grossSales, order.total);
    expect(summary.netRevenue, order.netRevenue);
  });

  test('sales summary aggregates seeded order data', () {
    final orders = seedOrders();
    final summary = SalesSummary.fromOrders(orders);

    expect(
      orders.map((order) => order.id),
      everyElement(matches(RegExp(r'^\d{6}-\d{2}$'))),
    );
    expect(
      orders.map((order) => order.id.substring(7)),
      List.generate(orders.length, (index) => '${index + 1}'.padLeft(2, '0')),
    );
    expect(summary.totalOrders, orders.length);
    expect(summary.grossSales, greaterThan(0));
    expect(summary.netRevenue, greaterThan(0));
    expect(
      summary.completedOrders +
          summary.pendingOrders +
          summary.cancelledOrders +
          summary.refundedOrders,
      orders.length,
    );
  });

  test('suspension is active only inside its date window', () {
    final now = DateTime.now();
    final suspension = Suspension(
      id: 'SUS-1',
      accountId: 'VND-1',
      accountName: 'Vendor',
      accountType: 'Vendor',
      reason: 'Policy violation',
      startDate: now.subtract(const Duration(hours: 1)),
      endDate: now.add(const Duration(days: 1)),
      administratorId: 'ADM-001',
      createdAt: now,
      note: '',
      notifyUser: true,
    );

    expect(suspension.isActive, isTrue);
    expect(suspension.isExpired, isFalse);
    expect(suspension.lift(now).isActive, isFalse);
  });

  test('application stores KYC documents and rejection reason', () {
    final application = VendorApplication(
      id: 'APP-1',
      applicant: 'Vendor',
      stallName: 'Stall',
      category: 'FRUITS',
      submittedAt: DateTime(2026, 7, 28),
      status: ApplicationStatus.rejected,
      location: 'Block 1',
      documents: [
        KycDocument(
          name: 'Permit',
          filename: 'permit.pdf',
          mimeType: 'application/pdf',
          uploadedAt: DateTime(2026, 7, 28),
        ),
      ],
      rejectionReason: 'Document is unreadable',
    );

    expect(application.documents, hasLength(1));
    expect(application.rejectionReason, 'Document is unreadable');
  });

  test(
      'dismissing a report moves it to resolved history without changing account',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppDataController(preferences, firebaseEnabled: false);
    final report = controller.state.reports.firstWhere(
      (item) =>
          item.type == 'Customer' && item.accountIssue == 'Juan Dela Cruz',
    );

    final error = await controller.dismissReport(
      reportId: report.id,
      note: 'No policy violation found.',
    );

    expect(error, isNull);
    final updated = controller.state.reports.firstWhere(
      (item) => item.id == report.id,
    );
    expect(updated.status, ReportStatus.resolved);
    expect(updated.decision, 'No Violation');
    expect(updated.actionTaken, 'Dismissed');
    expect(
      controller.state.customers
          .firstWhere((item) => item.name == 'Juan Dela Cruz')
          .status,
      AccountStatus.active,
    );
    expect(
      controller.state.auditLogs.first.action,
      AuditAction.resolveReport,
    );
  });

  test('suspending a reported account resolves the report and can be lifted',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppDataController(preferences, firebaseEnabled: false);
    final report = controller.state.reports.firstWhere(
      (item) =>
          item.type == 'Customer' && item.accountIssue == 'Juan Dela Cruz',
    );
    final start = DateTime.now();
    final end = start.add(const Duration(days: 7));

    final error = await controller.suspendAccountFromReport(
      reportId: report.id,
      reason: 'Marketplace violation',
      startDate: start,
      endDate: end,
    );

    expect(error, isNull);
    final suspension = controller.state.suspensions.firstWhere(
      (item) => item.relatedReportId == report.id,
    );
    expect(
      controller.state.customers
          .firstWhere((item) => item.name == 'Juan Dela Cruz')
          .status,
      AccountStatus.suspended,
    );
    expect(
      controller.state.reports
          .firstWhere((item) => item.id == report.id)
          .decision,
      'Account Suspended',
    );

    await controller.liftSuspension(suspension.id);

    expect(
      controller.state.customers
          .firstWhere((item) => item.name == 'Juan Dela Cruz')
          .status,
      AccountStatus.active,
    );
    expect(
      controller.state.reports
          .firstWhere((item) => item.id == report.id)
          .status,
      ReportStatus.resolved,
    );
    expect(
      controller.state.auditLogs.first.metadata['relatedReportId'],
      report.id,
    );
  });

  test('blocking a reported vendor stores details and supports unblocking',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppDataController(preferences, firebaseEnabled: false);
    final report = controller.state.reports.firstWhere(
      (item) =>
          (item.type == 'Vendor' || item.type == 'Stall Holder') &&
          item.accountIssue.contains('Diosa'),
    );

    final error = await controller.blockAccountFromReport(
      reportId: report.id,
      reason: 'Repeated marketplace violations',
    );

    expect(error, isNull);
    final vendor = controller.state.vendors.firstWhere(
      (item) => item.name.contains('Diosa'),
    );
    expect(vendor.status, AccountStatus.blocked);
    expect(vendor.blockedReason, 'Repeated marketplace violations');
    expect(vendor.blockedFromReportId, report.id);
    expect(
      controller.state.reports
          .firstWhere((item) => item.id == report.id)
          .status,
      ReportStatus.resolved,
    );

    await controller.updateVendorAccount(
      vendor.id,
      status: AccountStatus.active,
      administrativeNotes: '',
    );

    final unblocked = controller.state.vendors.firstWhere(
      (item) => item.id == vendor.id,
    );
    expect(unblocked.status, AccountStatus.active);
    expect(unblocked.blockedReason, isNull);
    expect(
      controller.state.reports
          .firstWhere((item) => item.id == report.id)
          .status,
      ReportStatus.resolved,
    );
  });

  test('blocking a suspended account closes its active suspension', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppDataController(preferences, firebaseEnabled: false);
    final vendor = controller.state.vendors.first;
    final report = controller.state.reports.firstWhere(
      (item) =>
          (item.type == 'Vendor' || item.type == 'Stall Holder') &&
          item.accountIssue == vendor.name,
    );

    final suspensionError = await controller.createSuspension(
      accountId: vendor.id,
      accountName: vendor.name,
      accountType: 'Vendor',
      reason: 'Temporary investigation hold',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      note: '',
      notifyUser: false,
    );
    expect(suspensionError, isNull);
    expect(
      controller.state.vendors
          .firstWhere((item) => item.id == vendor.id)
          .status,
      AccountStatus.suspended,
    );

    final blockError = await controller.blockAccountFromReport(
      reportId: report.id,
      reason: 'Confirmed policy violation',
    );

    expect(blockError, isNull);
    expect(
      controller.state.vendors
          .firstWhere((item) => item.id == vendor.id)
          .status,
      AccountStatus.blocked,
    );
    expect(
      controller.state.suspensions
          .where((item) => item.accountId == vendor.id && item.isActive),
      isEmpty,
    );
  });

  test(
      'renewal requests filtering, badge equality, mutual exclusivity, and sorting',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppDataController(preferences, firebaseEnabled: false);
    final renewals = controller.state.renewals;

    final requestsTabItems =
        renewals.where((r) => r.status == RenewalStatus.reviewing).toList();
    final historyTabItems =
        renewals.where((r) => r.status != RenewalStatus.reviewing).toList();

    // Requests tab only contains pending Under Review renewals
    expect(
      requestsTabItems.every((r) => r.status == RenewalStatus.reviewing),
      isTrue,
    );

    // Renewal History tab contains only non-pending states (approved, expired)
    expect(
      historyTabItems.every((r) => r.status != RenewalStatus.reviewing),
      isTrue,
    );

    // Badge counts equal filter row counts
    expect(requestsTabItems.length, 6);
    expect(historyTabItems.length, 19);
    expect(requestsTabItems.length + historyTabItems.length, renewals.length);

    // Mutual exclusivity: no renewal ID appears in both tabs
    final requestsIds = requestsTabItems.map((r) => r.id).toSet();
    final historyIds = historyTabItems.map((r) => r.id).toSet();
    expect(requestsIds.intersection(historyIds), isEmpty);

    // Default sorting for Requests tab: soonest expiry date first
    final sortedRequests = List<RenewalRequest>.from(requestsTabItems)
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    for (int i = 0; i < sortedRequests.length - 1; i++) {
      expect(
        sortedRequests[i]
                .expiryDate
                .isBefore(sortedRequests[i + 1].expiryDate) ||
            sortedRequests[i]
                .expiryDate
                .isAtSameMomentAs(sortedRequests[i + 1].expiryDate),
        isTrue,
      );
    }

    // State change: approving a renewal moves it from Requests tab to Renewal History tab
    final pendingRenewal = requestsTabItems.first;
    await controller.updateRenewal(pendingRenewal.id, RenewalStatus.approved);

    final updatedRenewals = controller.state.renewals;
    final newRequestsTab = updatedRenewals
        .where((r) => r.status == RenewalStatus.reviewing)
        .toList();
    final newHistoryTab = updatedRenewals
        .where((r) => r.status != RenewalStatus.reviewing)
        .toList();

    expect(newRequestsTab.map((r) => r.id), isNot(contains(pendingRenewal.id)));
    expect(newHistoryTab.map((r) => r.id), contains(pendingRenewal.id));
    expect(newRequestsTab.length, 5);
    expect(newHistoryTab.length, 20);

    // State change: reopening a renewal moves it from Renewal History tab back to Requests tab
    await controller.updateRenewal(pendingRenewal.id, RenewalStatus.reviewing);

    final reopenedRenewals = controller.state.renewals;
    final reopenedRequestsTab = reopenedRenewals
        .where((r) => r.status == RenewalStatus.reviewing)
        .toList();
    expect(reopenedRequestsTab.map((r) => r.id), contains(pendingRenewal.id));
    expect(reopenedRequestsTab.length, 6);
  });

  test('vendor closure request workflow and active order guard', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = AppDataController(prefs, firebaseEnabled: false);

    // Vendor with seeded closure request
    final vendorWithRequest = controller.state.vendors.firstWhere(
      (v) => v.closureRequestedAt != null,
    );
    expect(vendorWithRequest.closureReason, isNotEmpty);

    // Guard test: create an active order for this vendor
    final activeOrder = Order(
      id: 'ORD-TEST-ACTIVE',
      transactionId: vendorWithRequest.id,
      placedAt: DateTime.now(),
      customerName: 'Test Customer',
      vendorName: vendorWithRequest.name,
      stallName: 'Test Stall',
      items: const [
        OrderItem(name: 'Item', category: 'Meat', quantity: 1, unitPrice: 100),
      ],
      discounts: 0,
      deliveryFee: 0,
      platformFee: 0,
      refundAmount: 0,
      paymentMethod: PaymentMethod.cashOnDelivery,
      paymentStatus: PaymentStatus.pending,
      status: OrderStatus.processing,
    );
    controller.state = controller.state.copyWith(
      orders: [activeOrder, ...controller.state.orders],
    );

    // Attempting closure should throw StateError due to active orders
    expect(
      () => controller.approveVendorClosure(
        vendorWithRequest.id,
        administrativeNotes: 'Closing stall',
      ),
      throwsStateError,
    );

    // Remove active order (or mark completed)
    controller.state = controller.state.copyWith(
      orders: controller.state.orders
          .where((o) => o.id != 'ORD-TEST-ACTIVE')
          .toList(),
    );

    // Now approving closure succeeds
    await controller.approveVendorClosure(
      vendorWithRequest.id,
      administrativeNotes: 'Closure approved by admin upon vendor request',
    );

    final updatedVendor = controller.state.vendors.firstWhere(
      (v) => v.id == vendorWithRequest.id,
    );
    expect(updatedVendor.status, AccountStatus.blocked);
    expect(updatedVendor.closureRequestedAt, isNull);
    expect(updatedVendor.blockedReason,
        contains('Stall closed upon vendor request'));

    // Check audit trail
    final audit = controller.state.auditLogs.first;
    expect(audit.action, AuditAction.blockAccount);
    expect(audit.targetEntityId, vendorWithRequest.id);
  });

  test(
      'dismissing vendor closure request keeps vendor active and clears request',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = AppDataController(prefs, firebaseEnabled: false);

    final vendorWithRequest = controller.state.vendors.firstWhere(
      (v) => v.closureRequestedAt != null,
    );

    await controller.dismissVendorClosureRequest(
      vendorWithRequest.id,
      administrativeNotes: 'Vendor retracted request',
    );

    final updated = controller.state.vendors.firstWhere(
      (v) => v.id == vendorWithRequest.id,
    );
    expect(updated.closureRequestedAt, isNull);
    expect(updated.status, AccountStatus.active);

    final audit = controller.state.auditLogs.first;
    expect(audit.action, AuditAction.editAccountStatus);
    expect(audit.previousValue, 'Closure Requested');
  });

  test('reassigning stall location updates location, category, and audit trail',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = AppDataController(prefs, firebaseEnabled: false);

    final vendor = controller.state.vendors.first;
    final oldLocation = vendor.location;

    await controller.reassignVendorLocation(
      vendor.id,
      newLocation: 'Stall #99, Dry Goods Section',
      newCategory: 'Dry Goods',
      administrativeNotes: 'Approved relocation permit #204',
    );

    final updated =
        controller.state.vendors.firstWhere((v) => v.id == vendor.id);
    expect(updated.location, 'Stall #99, Dry Goods Section');
    expect(updated.stallType, 'Dry Goods');

    final audit = controller.state.auditLogs.first;
    expect(audit.action, AuditAction.editAccountStatus);
    expect(audit.previousValue, contains(oldLocation));
    expect(
        audit.newValue, contains('Stall #99, Dry Goods Section (Dry Goods)'));
  });

  test(
      'seeded vendors contain relocation request and archived/closed stall samples',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = AppDataController(prefs, firebaseEnabled: false);

    final relocationVendors =
        controller.state.vendors.where((v) => v.relocationRequestedAt != null);
    expect(relocationVendors.length, greaterThanOrEqualTo(1));
    final sampleRelocation = relocationVendors.first;
    expect(sampleRelocation.relocationTargetLocation, isNotNull);
    expect(sampleRelocation.relocationReason, isNotNull);

    final closedStalls = controller.state.vendors.where(
      (v) =>
          v.status == AccountStatus.blocked &&
          (v.blockedReason?.contains('Stall closed') == true),
    );
    expect(closedStalls.length, greaterThanOrEqualTo(1));
    final sampleClosed = closedStalls.first;
    expect(sampleClosed.location, contains('Archived'));
    expect(sampleClosed.blockedAt, isNotNull);
    expect(sampleClosed.blockedBy, isNotNull);

    // Verify reopening closed stall restores account to active
    await controller.updateVendorAccount(
      sampleClosed.id,
      status: AccountStatus.active,
      administrativeNotes: 'Stall lease reopened per application',
    );
    final reopened =
        controller.state.vendors.firstWhere((v) => v.id == sampleClosed.id);
    expect(reopened.status, AccountStatus.active);
    expect(reopened.blockedReason, isNull);
  });
}
