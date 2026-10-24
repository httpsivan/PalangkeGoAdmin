import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palengkego_admin/data/mock_data.dart';
import 'package:palengkego_admin/data/repositories/mock_repository.dart';
import 'package:palengkego_admin/data/repositories/supabase_announcement_service.dart';
import 'package:palengkego_admin/models/admin_models.dart';
import 'package:palengkego_admin/models/app_models.dart';

void main() {
  group('SupabaseAnnouncementService audience mapping', () {
    test('normalizes Admin UI audience to database values', () {
      expect(
        SupabaseAnnouncementService.audienceToTargetAudience('Stall Holders'),
        'stallholders',
      );
      expect(
        SupabaseAnnouncementService.audienceToTargetAudience('stall holders'),
        'stallholders',
      );
      expect(
        SupabaseAnnouncementService.audienceToTargetAudience('Vendors'),
        'stallholders',
      );
      expect(
        SupabaseAnnouncementService.audienceToTargetAudience('vendor'),
        'stallholders',
      );
      expect(
        SupabaseAnnouncementService.audienceToTargetAudience('Customers'),
        'customers',
      );
      expect(
        SupabaseAnnouncementService.audienceToTargetAudience('customer'),
        'customers',
      );
      expect(
        SupabaseAnnouncementService.audienceToTargetAudience('All Users'),
        'all',
      );
      expect(
        SupabaseAnnouncementService.audienceToTargetAudience('unknown'),
        'all',
      );
    });

    test('maps database values back to Admin UI display labels', () {
      expect(
        SupabaseAnnouncementService.targetAudienceToDisplay('stallholders'),
        'Stall Holders',
      );
      expect(
        SupabaseAnnouncementService.targetAudienceToDisplay('vendors'),
        'Stall Holders',
      );
      expect(
        SupabaseAnnouncementService.targetAudienceToDisplay('customers'),
        'Customers',
      );
      expect(
        SupabaseAnnouncementService.targetAudienceToDisplay('all'),
        'All Users',
      );
      expect(
        SupabaseAnnouncementService.targetAudienceToDisplay(null),
        'All Users',
      );
    });
  });

  group('AppDataController announcement operations', () {
    late SharedPreferences preferences;
    late AppDataController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      controller = AppDataController(preferences, firebaseEnabled: false);
    });

    test('seeds initial announcements in mock mode', () {
      expect(controller.state.announcements, isNotEmpty);
      expect(controller.state.announcements.length, seedAnnouncements().length);
    });

    test('adds an announcement with image and expiration date', () async {
      final initialCount = controller.state.announcements.length;
      final expiry = DateTime.now().add(const Duration(days: 7));
      final testAnnouncement = Announcement(
        id: 'ANN-TEST-001',
        title: 'Bagsakan Flash Sale',
        summary: 'Special weekend discounts for wet market vendors.',
        audience: 'Stall Holders',
        createdAt: DateTime(2026, 10, 1),
        expiresAt: null,
        imageUrl: 'https://example.com/banner.jpg',
        isDraft: false,
      );

      await controller.addAnnouncement(
        testAnnouncement.copyWith(expiresAt: expiry),
      );

      expect(controller.state.announcements.length, initialCount + 1);
      final added = controller.state.announcements.first;
      expect(added.id, 'ANN-TEST-001');
      expect(added.title, 'Bagsakan Flash Sale');
      expect(added.audience, 'Stall Holders');
      expect(added.imageUrl, 'https://example.com/banner.jpg');
      expect(added.expiresAt, expiry);
      expect(preferences.getString('last_announcement'), 'Bagsakan Flash Sale');
      expect(
        controller.state.auditLogs.first.action,
        AuditAction.sendAnnouncement,
      );
    });

    test('updates an existing announcement', () async {
      final existing = controller.state.announcements.first;
      final updated = existing.copyWith(
        title: 'Updated Headline Notice',
        summary: 'Updated content body for users.',
        audience: 'Customers',
      );

      await controller.updateAnnouncement(updated);

      final found =
          controller.state.announcements.firstWhere((a) => a.id == existing.id);
      expect(found.title, 'Updated Headline Notice');
      expect(found.summary, 'Updated content body for users.');
      expect(found.audience, 'Customers');
      expect(
        controller.state.auditLogs.first.action,
        AuditAction.changeSettings,
      );
    });

    test('deletes an announcement', () async {
      final target = controller.state.announcements.first;
      final countBefore = controller.state.announcements.length;

      await controller.deleteAnnouncement(target.id);

      expect(controller.state.announcements.length, countBefore - 1);
      expect(
        controller.state.announcements.any((a) => a.id == target.id),
        isFalse,
      );
      expect(
        controller.state.auditLogs.first.action,
        AuditAction.changeSettings,
      );
    });
  });
}
