import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego_admin/core/theme/app_theme.dart';
import 'package:palengkego_admin/core/theme/theme_controller.dart';
import 'package:palengkego_admin/models/app_models.dart';
import 'package:palengkego_admin/features/accounts/accounts_page.dart';
import 'package:palengkego_admin/features/announcements/announcement_dialog.dart';
import 'package:palengkego_admin/features/announcements/announcement_history_page.dart';
import 'package:palengkego_admin/features/audit_log/audit_log_page.dart';
import 'package:palengkego_admin/features/authentication/login_page.dart';
import 'package:palengkego_admin/features/notifications/notifications_page.dart';
import 'package:palengkego_admin/features/overview/overview_page.dart';
import 'package:palengkego_admin/features/renewals/renewals_page.dart';
import 'package:palengkego_admin/features/reports/reports_page.dart';
import 'package:palengkego_admin/features/sales_reports/sales_reports_page.dart';
import 'package:palengkego_admin/features/vendor_applications/vendor_applications_page.dart';
import 'package:palengkego_admin/features/vendor_applications/verification_dialog.dart';
import 'package:palengkego_admin/data/repositories/mock_repository.dart';

Future<void> _testZeroOverflow(
  WidgetTester tester, {
  required Size size,
  required String viewportName,
  required Widget widget,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final errors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details);

  try {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: widget),
        ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = originalOnError;
  }

  final overflowErrors = errors
      .where((e) => e.exceptionAsString().contains('overflowed by'))
      .toList();
  expect(overflowErrors, isEmpty,
      reason: 'Expected 0 overflow errors on $viewportName');
}

void main() {
  const viewports = <String, Size>{
    'Phone (360x780)': Size(360, 780),
    'Tablet (768x1024)': Size(768, 1024),
    'Laptop (1280x800)': Size(1280, 800),
    'Computer (1920x1080)': Size(1920, 1080),
  };

  for (final entry in viewports.entries) {
    final viewportName = entry.key;
    final size = entry.value;

    testWidgets('Zero overflow in LoginPage on $viewportName', (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const LoginPage(),
      );
    });

    testWidgets('Zero overflow in OverviewPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const OverviewPage(),
      );
    });

    testWidgets('Zero overflow in AccountsPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const AccountsPage(),
      );
    });

    testWidgets('Zero overflow in VendorApplicationsPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const VendorApplicationsPage(),
      );
    });

    testWidgets('Zero overflow in RenewalsPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const RenewalsPage(),
      );
    });

    testWidgets('Zero overflow in ReportsPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const ReportsPage(),
      );
    });

    testWidgets('Zero overflow in SalesReportsPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const SalesReportsPage(),
      );
    });

    testWidgets('Zero overflow in AnnouncementHistoryPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const AnnouncementHistoryPage(),
      );
    });

    testWidgets('Zero overflow in NotificationsPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const NotificationsPage(),
      );
    });

    testWidgets('Zero overflow in AuditLogPage on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const AuditLogPage(),
      );
    });

    testWidgets('Zero overflow in VerificationDialog on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: VerificationDialog.application(
          VendorApplication(
            id: 'APP-1001',
            applicant: 'Juan Dela Cruz',
            stallName: 'Fresh Veggies',
            category: 'Vegetables',
            location: 'Section A, Stall 12',
            status: ApplicationStatus.reviewing,
            submittedAt: DateTime.now(),
          ),
        ),
      );
    });

    testWidgets('Zero overflow in AnnouncementDialog on $viewportName',
        (tester) async {
      await _testZeroOverflow(
        tester,
        size: size,
        viewportName: viewportName,
        widget: const AnnouncementDialog(),
      );
    });
  }

  testWidgets('popup announcement clears and hides the feature image',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final existing = container
        .read(appDataProvider)
        .announcements
        .first
        .copyWith(imageUrl: 'https://example.com/card.jpg');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AnnouncementDialog(
                    announcementToEdit: existing,
                  ),
                ),
                child: const Text('Edit announcement'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit announcement'));
    await tester.pumpAndSettle();

    expect(find.text('Feature Image (Optional)'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Feature Image (Optional)'), findsNothing);

    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final saved = container
        .read(appDataProvider)
        .announcements
        .firstWhere((announcement) => announcement.id == existing.id);
    expect(saved.showAsPopup, isTrue);
    expect(saved.imageUrl, isNull);
    expect(saved.imageBytes, isNull);
  });
}
