import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin_models.dart';
import '../../models/app_models.dart';
import 'mock_repository.dart';

export '../../models/admin_models.dart'
    show Suspension, Order;
export '../../models/app_models.dart'
    show Vendor, Customer, AccountStatus, VendorApplication, ApplicationStatus, RenewalRequest, RenewalStatus;

/// Reactive provider for stall holders / vendors.
final vendorsProvider = Provider<List<Vendor>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.vendors));
});

/// Reactive provider for customer accounts.
final customersProvider = Provider<List<Customer>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.customers));
});

/// Reactive provider for vendor stall applications.
final vendorApplicationsProvider = Provider<List<VendorApplication>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.applications));
});

/// Reactive provider for stall renewal requests.
final renewalsProvider = Provider<List<RenewalRequest>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.renewals));
});

/// Reactive provider for active and past account suspensions.
final suspensionsProvider = Provider<List<Suspension>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.suspensions));
});

/// Direct domain repository for vendor accounts, applications, and renewals.
final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  return VendorRepository(ref);
});

class VendorRepository {
  const VendorRepository(this._ref);

  final Ref _ref;

  AppDataController get _controller => _ref.read(appDataProvider.notifier);

  Future<void> setVendorStatus(String id, AccountStatus status) =>
      _controller.setVendorStatus(id, status);

  Future<void> updateVendorAccount(
    String id, {
    required AccountStatus status,
    required String administrativeNotes,
  }) =>
      _controller.updateVendorAccount(
        id,
        status: status,
        administrativeNotes: administrativeNotes,
      );

  Future<void> updateCustomerAccount(
    String id, {
    required AccountStatus status,
    required String administrativeNotes,
  }) =>
      _controller.updateCustomerAccount(
        id,
        status: status,
        administrativeNotes: administrativeNotes,
      );

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
  }) =>
      _controller.createSuspension(
        accountId: accountId,
        accountName: accountName,
        accountType: accountType,
        reason: reason,
        startDate: startDate,
        endDate: endDate,
        note: note,
        notifyUser: notifyUser,
        relatedReportId: relatedReportId,
      );

  Future<String?> liftSuspension(String suspensionId) =>
      _controller.liftSuspension(suspensionId);

  Future<void> updateApplication(
    String id,
    ApplicationStatus status, {
    String? rejectionReason,
  }) =>
      _controller.updateApplication(
        id,
        status,
        rejectionReason: rejectionReason,
      );

  Future<void> resetMockApplications() =>
      _controller.resetMockApplications();

  Future<void> updateRenewal(
    String id,
    RenewalStatus status, {
    String? rejectionReason,
  }) =>
      _controller.updateRenewal(
        id,
        status,
        rejectionReason: rejectionReason,
      );

  Future<void> resetMockRenewals() =>
      _controller.resetMockRenewals();
}
