import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego_admin/core/theme/theme_controller.dart';
import 'package:palengkego_admin/features/accounts/accounts_page.dart';

void main() {
  testWidgets(
      'suspension date selection opens a time picker and preserves chosen time',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
          home: Scaffold(
              body: Consumer(
                  builder: (context, ref, _) => TextButton(
                      onPressed: () => showSuspensionDialog(context, ref,
                          accountId: 'customer',
                          accountName: 'Test customer',
                          accountType: 'Customer'),
                      child: const Text('Open suspension'))))),
    ));
    await tester.tap(find.text('Open suspension'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starts'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    // Enter an explicit time rather than accepting the original time.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
        of: find.byType(TimePickerDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '9');
    await tester.enterText(fields.at(1), '37');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('9:37'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
