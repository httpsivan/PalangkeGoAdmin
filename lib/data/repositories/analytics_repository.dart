import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin_models.dart';
import 'mock_repository.dart';

export '../../models/admin_models.dart' show AuditLog, AuditAction, Order;

/// Reactive provider for sales orders and transactions.
final ordersProvider = Provider<List<Order>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.orders));
});

/// Reactive provider for administrator audit trail.
final auditLogsProvider = Provider<List<AuditLog>>((ref) {
  return ref.watch(appDataProvider.select((state) => state.auditLogs));
});

/// Direct domain repository for analytics, orders, and administrative audit logging.
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref);
});

class AnalyticsRepository {
  const AnalyticsRepository(this._ref);

  final Ref _ref;

  AppDataController get _controller => _ref.read(appDataProvider.notifier);

  Future<void> recordAudit({
    required AuditAction action,
    required String targetEntityType,
    required String targetEntityId,
    required String targetUserName,
    required String previousValue,
    required String newValue,
    String reason = '',
    Map<String, String> metadata = const {},
  }) =>
      _controller.recordAudit(
        action: action,
        targetEntityType: targetEntityType,
        targetEntityId: targetEntityId,
        targetUserName: targetUserName,
        previousValue: previousValue,
        newValue: newValue,
        reason: reason,
        metadata: metadata,
      );
}
