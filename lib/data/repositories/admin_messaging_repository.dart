import '../../core/config/app_config.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/support_chat_client.dart';
import '../../models/chat_conversation.dart';
import '../../models/chat_message.dart';
import 'supabase_admin_service.dart';

final _messagingIdentityProvider = StreamProvider<String?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
  } catch (_) {
    return Stream.value(null);
  }
});
final adminMessagingRepositoryProvider =
    Provider<AdminMessagingRepository>((ref) {
  ref.watch(_messagingIdentityProvider);
  final backend = ref.watch(supabaseAdminServiceProvider).client;
  SupportChatClient? api;
  if (backend != null) {
    try {
      final config = ref.watch(appConfigProvider);
      api = SupportChatClient(backend, FirebaseAuth.instance,
          url: config.supabaseUrl, anonKey: config.supabaseAnonKey);
    } catch (_) {}
  }
  final repo = AdminMessagingRepository(api: api);
  ref.onDispose(repo.dispose);
  return repo;
});
final adminConversationsProvider =
    StreamProvider.autoDispose<List<ChatConversation>>((ref) =>
        ref.watch(adminMessagingRepositoryProvider).watchConversations());
final adminUnreadMessagesCountProvider = Provider<int>((ref) => ref
    .watch(adminConversationsProvider)
    .maybeWhen(
        data: (rows) => rows.where((row) => row.adminUnreadCount > 0).length,
        orElse: () => 0));
final adminConversationMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, id) =>
        ref.watch(adminMessagingRepositoryProvider).watchMessages(id));

class AdminMessagingRepository {
  AdminMessagingRepository({SupportChatClient? api}) : _api = api;
  final SupportChatClient? _api;
  SupportChatClient get api =>
      _api ??
      (throw StateError(
          'Sign in with a live administrator account to use messaging.'));
  static ChatConversation mapConversation(Map<String, dynamic> row) {
    final stall = row['stall'] as Map?;
    return ChatConversation(
        id: row['id'].toString(),
        stallId: (stall?['stall_holder_id'] ?? row['user_id']).toString(),
        stallName: (stall?['stall_name'] ?? 'Stall holder').toString(),
        customerUid: 'admin_support',
        customerName: 'Market Admin',
        lastMessageText: (row['last_message'] ?? '').toString(),
        lastMessageTimestamp:
            DateTime.parse(row['last_message_at'].toString()).toLocal(),
        lastMessageSenderId: '',
        vendorUnreadCount: (row['user_unread_count'] as num?)?.toInt() ?? 0,
        adminUnreadCount: (row['admin_unread_count'] as num?)?.toInt() ?? 0,
        inquiryType: 'admin_support',
        createdAt: DateTime.parse(row['created_at'].toString()).toLocal(),
        updatedAt: DateTime.parse(row['updated_at'].toString()).toLocal());
  }

  static ChatMessage mapMessage(Map<String, dynamic> row) => ChatMessage(
      id: row['id'].toString(),
      conversationId: row['conversation_id'].toString(),
      senderId: row['sender_user_id'].toString(),
      senderName:
          row['sender_role'] == 'admin' ? 'Market Admin' : 'Stall holder',
      senderRole: row['sender_role'].toString(),
      text: (row['body'] ?? '').toString(),
      timestamp: DateTime.parse(row['created_at'].toString()).toLocal(),
      isRead: row['read_at'] != null,
      readAt: DateTime.tryParse(row['read_at']?.toString() ?? '')?.toLocal(),
      attachmentUrl: row['attachment_url'] as String?,
      attachmentType: row['attachment_url'] == null ? null : 'image');
  Stream<List<ChatConversation>> watchConversations() => api
      .watch('conversations')
      .map((rows) => rows.map(mapConversation).toList());
  Stream<List<ChatMessage>> watchMessages(String id) =>
      api.watch(id).map((rows) => rows.map(mapMessage).toList());
  Future<List<ChatConversation>> getConversations() async =>
      (await api.load('conversations')).map(mapConversation).toList();
  Future<List<ChatMessage>> getMessages(String id) async =>
      (await api.load(id)).map(mapMessage).toList();
  bool hasOlder(String key) => _api?.hasOlder(key) ?? false;
  Future<void> loadOlder(String key) => api.loadOlder(key);
  Future<ChatMessage> sendMessage(
          {required String conversationId,
          required String text,
          String senderRole = 'admin',
          String senderName = 'Market Admin',
          String senderId = '',
          String? attachmentUrl,
          String? attachmentType}) async =>
      mapMessage(await api.send(conversationId, text, image: attachmentUrl));
  Future<void> markAsRead(String id) => api.markRead(id);
  void dispose() => _api?.dispose();
}
