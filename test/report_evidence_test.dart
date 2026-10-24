import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego_admin/data/repositories/supabase_admin_service.dart';
import 'package:palengkego_admin/models/app_models.dart';

void main() {
  test('uploaded evidence survives mapping and opening the report', () {
    final report = mapSupabaseComplaintRow({
      'complaint_id': 'report-1',
      'status': 'open',
      'evidence_urls': [
        'https://example.com/evidence.jpg',
        null,
        'file:///private'
      ],
    });
    expect(report.evidenceUrls, ['https://example.com/evidence.jpg']);
    expect(report.isUnread, isTrue);
    final opened = report.copyWith(status: ReportStatus.underReview);
    expect(opened.isUnread, isFalse);
    expect(opened.evidenceUrls, report.evidenceUrls);
    expect(opened.copyWith(status: ReportStatus.resolved).evidenceUrls,
        report.evidenceUrls);
  });

  test('legacy reports have no fabricated evidence', () {
    expect(
        mapSupabaseComplaintRow({'status': 'reviewing'}).evidenceUrls, isEmpty);
    expect(mapSupabaseComplaintRow({'status': 'reviewing'}).isUnread, isFalse);
  });
}
