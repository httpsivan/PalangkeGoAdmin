import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palengkego_admin/core/theme/app_theme.dart';
import 'package:palengkego_admin/core/theme/theme_controller.dart';
import 'package:palengkego_admin/data/mock_data.dart';
import 'package:palengkego_admin/data/repositories/mock_repository.dart';
import 'package:palengkego_admin/features/vendor_applications/application_utils.dart';
import 'package:palengkego_admin/features/vendor_applications/vendor_applications_page.dart';
import 'package:palengkego_admin/features/vendor_applications/verification_dialog.dart';
import 'package:palengkego_admin/models/app_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vendor Applications Utilities & Logic', () {
    test('isSameCalendarDay returns true for matching year, month, and day',
        () {
      final date1 = DateTime(2023, 10, 24, 14, 30);
      final date2 = DateTime(2023, 10, 24, 08, 00);
      final date3 = DateTime(2023, 10, 25, 08, 00);

      expect(isSameCalendarDay(date1, date2), isTrue);
      expect(isSameCalendarDay(date1, date3), isFalse);
    });

    test('isApplicationNew requires same calendar day and unviewed ID', () {
      final today = DateTime(2023, 10, 24);
      final appToday = VendorApplication(
        id: '#APP-100',
        applicant: 'Test Applicant',
        stallName: 'Test Stall',
        category: 'VEGETABLES',
        submittedAt: DateTime(2023, 10, 24, 10, 0),
        status: ApplicationStatus.reviewing,
        location: 'Block 1',
        documents: const [],
      );

      final appOld = VendorApplication(
        id: '#APP-101',
        applicant: 'Old Applicant',
        stallName: 'Old Stall',
        category: 'VEGETABLES',
        submittedAt: DateTime(2023, 10, 23, 10, 0),
        status: ApplicationStatus.reviewing,
        location: 'Block 1',
        documents: const [],
      );

      expect(isApplicationNew(appToday, {}, today), isTrue);
      expect(isApplicationNew(appToday, {'#APP-100'}, today), isFalse);
      expect(isApplicationNew(appOld, {}, today), isFalse);
    });

    test('Applications sort strictly by submittedAt descending', () {
      final apps = seedApplications();
      final sorted = List<VendorApplication>.from(apps)
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      for (int i = 0; i < sorted.length - 1; i++) {
        expect(
          sorted[i].submittedAt.isAfter(sorted[i + 1].submittedAt) ||
              sorted[i].submittedAt.isAtSameMomentAs(sorted[i + 1].submittedAt),
          isTrue,
        );
      }
    });
  });

  group('VerificationDialog Modal Routing & Action Button Tests', () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    Widget buildTestableDialog(
        WidgetTester tester, VendorApplication application) {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: VerificationDialog.application(application),
          ),
        ),
      );
    }

    testWidgets('Reviewing application renders editable action buttons',
        (tester) async {
      final reviewingApp = VendorApplication(
        id: '#APP-900',
        applicant: 'Reviewing User',
        stallName: 'Reviewing Stall',
        category: 'VEGETABLES',
        submittedAt: DateTime(2023, 10, 24),
        status: ApplicationStatus.reviewing,
        location: 'Block 1',
        documents: const [],
      );

      await tester.pumpWidget(buildTestableDialog(tester, reviewingApp));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Request Additional Documents'), findsOneWidget);
      expect(find.text('Reopen for Review'), findsNothing);
    });

    testWidgets(
        'Verified application renders read-only modal with Reopen button',
        (tester) async {
      final verifiedApp = VendorApplication(
        id: '#APP-901',
        applicant: 'Verified User',
        stallName: 'Verified Stall',
        category: 'VEGETABLES',
        submittedAt: DateTime(2023, 10, 24),
        status: ApplicationStatus.verified,
        location: 'Block 1',
        documents: const [],
      );

      await tester.pumpWidget(buildTestableDialog(tester, verifiedApp));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Request Additional Documents'), findsNothing);
      expect(find.text('Reopen for Review'), findsOneWidget);
    });

    testWidgets(
        'Rejected application renders read-only modal with rejection details',
        (tester) async {
      final rejectedApp = VendorApplication(
        id: '#APP-902',
        applicant: 'Rejected User',
        stallName: 'Rejected Stall',
        category: 'VEGETABLES',
        submittedAt: DateTime(2023, 10, 24),
        status: ApplicationStatus.rejected,
        rejectionReason: 'Invalid business permit',
        location: 'Block 1',
        documents: const [],
      );

      await tester.pumpWidget(buildTestableDialog(tester, rejectedApp));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Request Additional Documents'), findsNothing);
      expect(find.text('Reopen for Review'), findsOneWidget);
      expect(find.textContaining('Invalid business permit'),
          findsAtLeastNWidgets(1));
    });

    testWidgets(
        'InvalidDocs application renders read-only modal with rejection details',
        (tester) async {
      final invalidDocsApp = VendorApplication(
        id: '#APP-903',
        applicant: 'InvalidDocs User',
        stallName: 'InvalidDocs Stall',
        category: 'VEGETABLES',
        submittedAt: DateTime(2023, 10, 24),
        status: ApplicationStatus.invalidDocs,
        rejectionReason: 'Unreadable permit scan',
        location: 'Block 1',
        documents: const [],
      );

      await tester.pumpWidget(buildTestableDialog(tester, invalidDocsApp));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Request Additional Documents'), findsNothing);
      expect(find.text('Reopen for Review'), findsOneWidget);
    });
  });

  group('VendorApplicationsPage UI Integration Tests', () {
    testWidgets('Renders Stall Holder Applications page with tabs and metrics',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: VendorApplicationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stall Holder Applications'), findsOneWidget);
      expect(find.text('TOTAL APPLICATIONS'), findsOneWidget);
      expect(find.text('PENDING APPLICATION'), findsOneWidget);
      expect(find.text('APPROVED APPLICATION'), findsOneWidget);
      expect(find.text('NEW TODAY'), findsOneWidget);
      expect(find.text('All Applications'), findsAtLeastNWidgets(1));
      expect(find.text('#APP-92834'), findsOneWidget); // Already approved.
      expect(find.text('#APP-92839'), findsOneWidget); // Awaiting review.
      expect(find.text('#APP-92836'), findsOneWidget); // Re-upload requested.

      await tester.tap(find.text('PENDING APPLICATION'));
      await tester.pumpAndSettle();
      expect(find.text('#APP-92834'), findsNothing);
      expect(find.text('#APP-92839'), findsOneWidget);

      await tester.enterText(
          find.byType(TextField).first, 'no matching applicant');
      await tester.pumpAndSettle();
      expect(find.text('No results found'), findsOneWidget);
      await tester.tap(find.text('TOTAL APPLICATIONS'));
      await tester.pumpAndSettle();
      expect(find.text('#APP-92834'), findsOneWidget);
      expect(find.text('#APP-92839'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VendorApplicationsPage)),
      );
      final approval =
          container.read(appDataProvider.notifier).updateApplication(
                '#APP-92839',
                ApplicationStatus.verified,
              );
      await tester.pump(const Duration(seconds: 1));
      await approval;
      await tester.pumpAndSettle();

      expect(find.text('#APP-92839'), findsOneWidget);
      expect(
        container
            .read(appDataProvider)
            .applications
            .firstWhere((item) => item.id == '#APP-92839')
            .status,
        ApplicationStatus.verified,
      );

      // Open filter menu and select Pending Review
      await tester.tap(find.text('All Applications').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pending Review').last);
      await tester.pumpAndSettle();
      expect(find.text('#APP-92839'), findsNothing);

      // Open filter menu and select Verified
      await tester.tap(find.text('Pending Review').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verified').last);
      await tester.pumpAndSettle();
      expect(find.text('#APP-92839'), findsOneWidget);
      expect(find.text('#APP-92843'), findsNothing);
    });
  });
}
