import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego_admin/data/repositories/supabase_admin_service.dart';
import 'package:palengkego_admin/models/app_models.dart';

void main() {
  test('maps an app vendor complaint into an active admin report', () {
    final report = mapSupabaseComplaintRow({
      'complaint_id': 'complaint-123',
      'reason': 'Scam or Fraud',
      'details': 'Product was never delivered.',
      'status': 'open',
      'created_at': '2026-10-17T08:00:00Z',
      'stall_name': 'Fresh Fish Stand',
      'reporter_name': 'Test Customer',
    });

    expect(report.id, 'complaint-123');
    expect(report.type, 'Vendor');
    expect(report.accountIssue, 'Fresh Fish Stand');
    expect(report.submittedBy, 'Test Customer');
    expect(report.reason, 'Scam or Fraud');
    expect(report.description, 'Product was never delivered.');
    expect(report.status, ReportStatus.pending);
  });

  test('maps server review statuses into the admin report states', () {
    Report mapStatus(String status) => mapSupabaseComplaintRow({
          'complaint_id': 'complaint-123',
          'status': status,
        });

    expect(mapStatus('reviewing').status, ReportStatus.underReview);
    expect(mapStatus('resolved').status, ReportStatus.resolved);
    expect(mapStatus('dismissed').status, ReportStatus.resolved);
  });
}
