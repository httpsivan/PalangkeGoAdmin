import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego_admin/core/theme/light_theme.dart';
import 'package:palengkego_admin/core/theme/theme_controller.dart';
import 'package:palengkego_admin/core/widgets/document_viewer_modal.dart';
import 'package:palengkego_admin/features/vendor_applications/verification_dialog.dart';
import 'package:palengkego_admin/models/app_models.dart';

void main() {
  const url =
      'https://example.supabase.co/storage/v1/object/sign/kyc/id.jpg?token=test';

  testWidgets('KYC verification card previews the document URL',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final document = KycDocument(
      name: 'Mayor Permit',
      filename: 'permit.jpg',
      mimeType: 'image/jpeg',
      uploadedAt: DateTime.utc(2026, 10, 13),
      fileUrl: url,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: VerificationDialog.application(
              VendorApplication(
                id: 'application-1',
                applicant: 'Applicant',
                stallName: 'Test Stall',
                category: 'Vegetables',
                submittedAt: DateTime.utc(2026, 10, 13),
                status: ApplicationStatus.reviewing,
                location: 'Stall 1',
                email: 'stallholder@example.com',
                documents: [document],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('stallholder@example.com'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url == url,
      ),
      findsOneWidget,
    );
  });

  testWidgets('KYC image viewer uses the document URL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: DocumentViewerModal(
          documents: [
            KycDocument(
              name: 'Mayor Permit',
              filename: 'permit.jpg',
              mimeType: 'image/jpeg',
              uploadedAt: DateTime.utc(2026, 10, 13),
              fileUrl: url,
            ),
          ],
          applicantName: 'Applicant',
          stallName: 'Test Stall',
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect((image.image as NetworkImage).url, url);
  });

  testWidgets('government ID viewer shows only the required front side',
      (tester) async {
    const frontUrl = 'https://example.supabase.co/id-front.jpg';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: DocumentViewerModal(
          documents: [
            KycDocument(
              name: 'Valid Government ID',
              filename: 'government-id.jpg',
              mimeType: 'image/jpeg',
              uploadedAt: DateTime.utc(2026, 11, 2),
              fileUrl: url,
              idFrontUrl: frontUrl,
              idBackUrl: 'https://example.supabase.co/id-back.jpg',
              hasBackSide: true,
            ),
          ],
          applicantName: 'Applicant',
          stallName: 'Test Stall',
        ),
      ),
    );

    expect(find.text('Valid Government ID'), findsOneWidget);
    expect(find.text('Front'), findsNothing);
    expect(find.text('Back'), findsNothing);
    final image = tester.widget<Image>(find.byType(Image).first);
    expect((image.image as NetworkImage).url, frontUrl);
  });
}
