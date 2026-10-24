import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego_admin/core/theme/app_theme.dart';
import 'package:palengkego_admin/core/theme/theme_controller.dart';
import 'package:palengkego_admin/core/widgets/messages_bell.dart';
import 'package:palengkego_admin/data/repositories/admin_messaging_repository.dart';
import 'package:palengkego_admin/models/chat_conversation.dart';
import 'package:palengkego_admin/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Models Serialization', () {
    test('ChatMessage toJson and fromJson match schema', () {
      final now = DateTime(2026, 10, 24, 22, 0);
      final msg = ChatMessage(
        id: 'msg_test_1',
        conversationId: 'conv_1',
        senderId: 'admin_1',
        senderName: 'PalengkeGo Admin',
        senderRole: 'admin',
        text: 'Hello from market admin',
        timestamp: now,
        isRead: false,
      );

      final json = msg.toJson();
      expect(json['id'], 'msg_test_1');
      expect(json['sender_role'], 'admin');
      expect(json['text'], 'Hello from market admin');

      final reconstructed = ChatMessage.fromJson(json);
      expect(reconstructed.id, msg.id);
      expect(reconstructed.conversationId, msg.conversationId);
      expect(reconstructed.isFromAdmin, isTrue);
      expect(reconstructed.isFromCustomer, isFalse);
      expect(reconstructed.isFromVendor, isFalse);
    });

    test('ChatConversation toJson and fromJson match schema', () {
      final now = DateTime(2026, 10, 24, 22, 0);
      final conv = ChatConversation(
        id: 'conv_test_1',
        stallId: 'VND-92858',
        stallName: 'Omar Rivera (SARI-SARI)',
        customerUid: 'cust_ana',
        customerName: 'Ana Santos',
        lastMessageText: 'May stock po ba?',
        lastMessageTimestamp: now,
        lastMessageSenderId: 'cust_ana',
        adminUnreadCount: 1,
        inquiryType: 'product',
        createdAt: now,
        updatedAt: now,
      );

      final json = conv.toJson();
      expect(json['stall_name'], 'Omar Rivera (SARI-SARI)');
      expect(json['admin_unread_count'], 1);

      final reconstructed = ChatConversation.fromJson(json);
      expect(reconstructed.id, conv.id);
      expect(reconstructed.stallId, conv.stallId);
      expect(reconstructed.hasUnreadForAdmin, isTrue);
      expect(reconstructed.displayStallName, 'Omar Rivera (Sari-sari)');

      final fruitConv = conv.copyWith(stallName: "Mer's Mayao Fruit Stand");
      expect(fruitConv.displayStallName, "Mer's Mayao (Fruit)");
    });
  });

  group('AdminMessagingRepository', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('seeds default market conversations and allows sending admin messages', () async {
      final repo = AdminMessagingRepository(preferences: prefs);

      final conversations = await repo.getConversations();
      expect(conversations.isNotEmpty, isTrue);
      expect(conversations.any((c) => c.stallName.contains('Omar Rivera')), isTrue);

      final firstConv = conversations.first;
      final messages = await repo.getMessages(firstConv.id);
      expect(messages.isNotEmpty, isTrue);

      // Send admin message
      final sent = await repo.sendMessage(
        conversationId: firstConv.id,
        text: 'Notice: Market inspection scheduled tomorrow.',
      );

      expect(sent.isFromAdmin, isTrue);
      expect(sent.text, 'Notice: Market inspection scheduled tomorrow.');

      final updatedMessages = await repo.getMessages(firstConv.id);
      expect(updatedMessages.last.text, 'Notice: Market inspection scheduled tomorrow.');

      // Mark as read
      await repo.markAsRead(firstConv.id);
      final readMessages = await repo.getMessages(firstConv.id);
      expect(readMessages.every((m) => m.isRead), isTrue);

      repo.dispose();
    });
  });

  group('MessagesBell Widget', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders MessagesBell and opens MessagesPanel on tap', (tester) async {
      final repo = AdminMessagingRepository(preferences: prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            adminMessagingRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: Center(
                child: MessagesBell(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify button exists
      expect(find.byType(MessagesBell), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      // Tap messages button
      await tester.tap(find.byType(MessagesBell));
      await tester.pumpAndSettle();

      // Verify popup panel opened with title
      expect(find.text('Messages'), findsOneWidget);

      repo.dispose();
    });
  });
}
