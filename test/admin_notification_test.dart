import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego_admin/models/admin_notification.dart';
import 'package:palengkego_admin/data/repositories/notification_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationController', () {
    test('starts without seeded sample notifications', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final controller = NotificationController(preferences);
      addTearDown(controller.dispose);

      expect(controller.state, isEmpty);
    });
  });

  group('NotificationTarget', () {
    test('builds the application detail destination', () {
      const target = NotificationTarget(
        type: NotificationTargetType.application,
        id: '#APP-92839',
      );

      expect(
        target.destination,
        '/applications?open=1&applicationId=%23APP-92839',
      );
    });

    test('builds destinations for every supported record type', () {
      expect(
        const NotificationTarget(
          type: NotificationTargetType.renewal,
          id: '#RN-92835',
        ).destination,
        '/renewal?open=1&renewalId=%23RN-92835',
      );
      expect(
        const NotificationTarget(
          type: NotificationTargetType.report,
          id: '#RPT-100',
        ).destination,
        '/reports?open=1&reportId=%23RPT-100',
      );
      expect(
        const NotificationTarget(
          type: NotificationTargetType.customer,
          id: 'CUS-1200',
        ).destination,
        '/accounts?open=1&accountId=CUS-1200&tab=customers',
      );
    });
  });
}
