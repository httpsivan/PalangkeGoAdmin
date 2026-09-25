import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_models.dart';
import 'mock_repository.dart';

export '../../models/app_models.dart' show Report, ReportStatus;

/// Reactive provider for the list of submitted reports and complaints.
final reportsProvider = Provider<List<Report>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.reports));
});

/// Direct domain repository for managing reports, complaints, and report-driven penalties.
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref);
});

class ReportsRepository {
  const ReportsRepository(this._ref);

  final Ref _ref;

  AppDataController get _controller => _ref.read(appDataProvider.notifier);

  Future<String?> dismissReport({
    required String reportId,
    required String note,
    String decision = 'Dismissed',
    String actionTaken = 'Dismissed without penalties',
  }) =>
      _controller.dismissReport(
        reportId: reportId,
        note: note,
        decision: decision,
        actionTaken: actionTaken,
      );

  Future<String?> resolveReport({
    required String reportId,
    required String note,
  }) =>
      _controller.resolveReport(reportId: reportId, note: note);

  Future<String?> suspendAccountFromReport({
    required String reportId,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      _controller.suspendAccountFromReport(
        reportId: reportId,
        reason: reason,
        startDate: startDate,
        endDate: endDate,
      );

  Future<String?> blockAccountFromReport({
    required String reportId,
    required String reason,
  }) =>
      _controller.blockAccountFromReport(reportId: reportId, reason: reason);
}
