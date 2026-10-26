import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/theme_controller.dart';
import '../../models/chat_conversation.dart';
import '../../models/chat_message.dart';
import 'supabase_admin_service.dart';

/// Riverpod provider delivering the singleton instance of [AdminMessagingRepository].
final adminMessagingRepositoryProvider = Provider<AdminMessagingRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final supabaseAdmin = ref.watch(supabaseAdminServiceProvider);
  final client = supabaseAdmin.client;

  final repo = AdminMessagingRepository(
    client: client,
    preferences: prefs,
  );

  ref.onDispose(repo.dispose);
  return repo;
});

/// Real-time stream provider of all conversations for the admin messaging dashboard.
final adminConversationsProvider =
    StreamProvider.autoDispose<List<ChatConversation>>((ref) async* {
  final repo = ref.watch(adminMessagingRepositoryProvider);
  final initial = await repo.getConversations();
  yield initial;
  yield* repo.watchConversations();
});

/// Provider computing the total number of conversations with unread messages for admin.
final adminUnreadMessagesCountProvider = Provider<int>((ref) {
  final conversationsAsync = ref.watch(adminConversationsProvider);
  return conversationsAsync.maybeWhen(
    data: (conversations) {
      return conversations.where((c) => c.hasUnreadForAdmin).length;
    },
    orElse: () => 0,
  );
});

/// Stream provider for live messages belonging to a specific [conversationId].
final adminConversationMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) async* {
  final repo = ref.watch(adminMessagingRepositoryProvider);
  final initial = await repo.getMessages(conversationId);
  yield initial;
  yield* repo.watchMessages(conversationId);
});

/// Repository orchestrating market admin messaging with stall holders.
///
/// Supports real-time updates via Supabase and falls back transparently
/// to a persistent local SharedPreferences store when offline or in mock mode.
class AdminMessagingRepository {
  AdminMessagingRepository({
    SupabaseClient? client,
    required SharedPreferences preferences,
  })  : _client = client,
        _preferences = preferences {
    _initLocalStore();
  }

  final SupabaseClient? _client;
  final SharedPreferences _preferences;

  static const _conversationsKey = 'mock_chat_conversations_v3';
  static const _messagesKey = 'mock_chat_messages_v3';

  final List<ChatConversation> _localConversations = [];
  final Map<String, List<ChatMessage>> _localMessages = {};

  final _conversationsStreamController =
      StreamController<List<ChatConversation>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>>
      _messageStreamControllers = {};

  bool _isLoaded = false;

  void dispose() {
    _conversationsStreamController.close();
    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
  }

  // ── Public Stream & Query Methods ──────────────────────────────────────────

  bool _isAdminConversation(ChatConversation c) {
    return c.inquiryType == 'admin_support' ||
        c.customerUid == 'admin_support' ||
        c.customerUid == 'admin-market-master' ||
        c.stallId == 'admin_support';
  }

  bool _hasConversationStarted(ChatConversation c) {
    final text = c.lastMessageText.trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (lower == 'no messages yet' ||
        lower == 'started a conversation' ||
        lower.contains('how can the palengkego admin team help you')) {
      return false;
    }
    return true;
  }

  /// Returns a real-time stream of all conversations ordered by latest message.
  Stream<List<ChatConversation>> watchConversations() {
    final client = _client;
    if (client != null) {
      try {
        return client
            .from('conversations')
            .stream(primaryKey: ['id'])
            .order('last_message_timestamp', ascending: false)
            .map((rows) {
              return rows
                  .map((r) => ChatConversation.fromJson(r))
                  .where((c) => _isAdminConversation(c) && _hasConversationStarted(c))
                  .toList();
            });
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase stream error, falling back to local: $e');
      }
    }
    return _conversationsStreamController.stream;
  }

  /// Fetches a one-time snapshot of conversations from Supabase or local storage.
  Future<List<ChatConversation>> getConversations() async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client
            .from('conversations')
            .select()
            .order('last_message_timestamp', ascending: false);
        return (response as List<dynamic>)
            .map((row) => ChatConversation.fromJson(Map<String, dynamic>.from(row as Map)))
            .where((c) => _isAdminConversation(c) && _hasConversationStarted(c))
            .toList();
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase getConversations error: $e');
      }
    }

    await _ensureLoaded();
    return _localConversations.where(_hasConversationStarted).toList();
  }

  /// Returns a real-time stream of messages in a given [conversationId].
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    final client = _client;
    if (client != null) {
      try {
        return client
            .from('messages')
            .stream(primaryKey: ['id'])
            .eq('conversation_id', conversationId)
            .order('timestamp', ascending: true)
            .map((rows) {
              final list = rows.map((r) => ChatMessage.fromJson(r)).toList();
              list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              return list;
            });
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase watchMessages error: $e');
      }
    }

    if (!_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId] =
          StreamController<List<ChatMessage>>.broadcast();
    }
    return _messageStreamControllers[conversationId]!.stream;
  }

  /// Fetches existing messages for a given [conversationId].
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('timestamp', ascending: true);
        final list = (response as List<dynamic>)
            .map((row) => ChatMessage.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList();
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return list;
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase getMessages error: $e');
      }
    }

    await _ensureLoaded();
    final localList = List<ChatMessage>.from(_localMessages[conversationId] ?? []);
    localList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return List.unmodifiable(localList);
  }

  /// Dispatches a message from Admin to a vendor conversation thread.
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String text,
    String senderRole = 'admin',
    String senderName = 'PalengkeGo Admin',
    String senderId = 'admin_support',
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toUtc().toIso8601String();
    final client = _client;
    final previewText = text.trim().isNotEmpty
        ? text.trim()
        : (attachmentUrl != null && attachmentUrl.isNotEmpty ? '📷 Photo' : '');
    final resolvedAttachmentType =
        attachmentType ?? (attachmentUrl != null && attachmentUrl.isNotEmpty ? 'image' : null);

    if (client != null) {
      try {
        final msgRow = {
          'conversation_id': conversationId,
          'sender_id': senderId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'text': text.trim(),
          'timestamp': nowIso,
          'is_read': false,
          if (attachmentUrl != null) 'attachment_url': attachmentUrl,
          if (resolvedAttachmentType != null) 'attachment_type': resolvedAttachmentType,
        };

        final inserted = await client.from('messages').insert(msgRow).select().single();
        final message = ChatMessage.fromJson(Map<String, dynamic>.from(inserted));

        await client.from('conversations').update({
          'last_message_text': previewText,
          'last_message_timestamp': nowIso,
          'last_message_sender_id': senderId,
          'vendor_unread_count': 1,
          'customer_unread_count': 0,
          'updated_at': nowIso,
        }).eq('id', conversationId);

        return message;
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase sendMessage failed: $e');
      }
    }

    await _ensureLoaded();
    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: text.trim(),
      timestamp: now,
      isRead: false,
      attachmentUrl: attachmentUrl,
      attachmentType: resolvedAttachmentType,
    );

    final list = _localMessages.putIfAbsent(conversationId, () => []);
    list.add(message);
    _notifyMessages(conversationId);

    final convIdx = _localConversations.indexWhere((c) => c.id == conversationId);
    if (convIdx >= 0) {
      final updated = _localConversations[convIdx].copyWith(
        lastMessageText: previewText,
        lastMessageTimestamp: now,
        lastMessageSenderId: senderId,
        updatedAt: now,
      );
      _localConversations[convIdx] = updated;
      _notifyConversations();
    }

    await _saveLocalStore();
    return message;
  }

  /// Marks all unread messages in [conversationId] as read by Admin and clears unread counters.
  Future<void> markAsRead(String conversationId) async {
    final client = _client;
    if (client != null) {
      try {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        await client
            .from('messages')
            .update({'is_read': true, 'read_at': nowIso})
            .eq('conversation_id', conversationId)
            .eq('is_read', false);

        await client.from('conversations').update({
          'customer_unread_count': 0,
        }).eq('id', conversationId);
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase markAsRead failed: $e');
      }
    }

    await _ensureLoaded();
    final list = _localMessages[conversationId];
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        if (!list[i].isRead) {
          list[i] = list[i].copyWith(isRead: true, readAt: DateTime.now());
        }
      }
      _notifyMessages(conversationId);
    }

    final convIdx = _localConversations.indexWhere((c) => c.id == conversationId);
    if (convIdx >= 0) {
      _localConversations[convIdx] = _localConversations[convIdx].copyWith(
        customerUnreadCount: 0,
        vendorUnreadCount: 0,
        adminUnreadCount: 0,
      );
      _notifyConversations();
    }

    await _saveLocalStore();
  }

  // ── Local Storage & Seeding ────────────────────────────────────────────────

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    _initLocalStore();
  }

  void _initLocalStore() {
    final convJson = _preferences.getString(_conversationsKey);
    final msgJson = _preferences.getString(_messagesKey);

    if (convJson != null && msgJson != null) {
      try {
        final List<dynamic> decodedConv = jsonDecode(convJson);
        _localConversations.clear();
        _localConversations.addAll(
          decodedConv.map((e) => ChatConversation.fromJson(e as Map<String, dynamic>)),
        );

        final Map<String, dynamic> decodedMsg = jsonDecode(msgJson);
        _localMessages.clear();
        decodedMsg.forEach((k, v) {
          final list = v as List<dynamic>;
          _localMessages[k] = list
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
        });

        _isLoaded = true;
        _notifyConversations();
        return;
      } catch (e) {
        debugPrint('[AdminMessaging] Failed to parse local cached messages: $e');
      }
    }

    _seedDefaultMarketConversations();
    _isLoaded = true;
    _notifyConversations();
    _saveLocalStore();
  }

  void _seedDefaultMarketConversations() {
    _localConversations.clear();
    _localMessages.clear();

    final now = DateTime.now();

    // 1. Omar Rivera (Sari-Sari, Block 14 - Stall 2) - Stall Holder ↔ Market Admin
    final conv1 = ChatConversation(
      id: 'conv_omar_rivera_admin',
      stallId: 'VND-92858',
      stallName: 'Omar Rivera (Sari-sari)',
      customerUid: 'admin-market-master',
      customerName: 'PalengkeGo Market Admin',
      lastMessageText: 'Sige po Market Master, susundin po namin ang SRP ceiling sa bigas.',
      lastMessageTimestamp: now.subtract(const Duration(minutes: 12)),
      lastMessageSenderId: 'VND-92858',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      adminUnreadCount: 1,
      inquiryType: 'general',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(minutes: 12)),
    );

    final msg1 = [
      ChatMessage(
        id: 'msg_1_1',
        conversationId: 'conv_omar_rivera_admin',
        senderId: 'admin-market-master',
        senderName: 'PalengkeGo Market Admin',
        senderRole: 'admin',
        text: 'Magandang araw Mang Omar. Paalala lang po ukol sa DTI Suggested Retail Price monitoring para sa bigas ngayong linggo.',
        timestamp: now.subtract(const Duration(minutes: 18)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_1_2',
        conversationId: 'conv_omar_rivera_admin',
        senderId: 'VND-92858',
        senderName: 'Omar Rivera',
        senderRole: 'vendor',
        text: 'Magandang araw po Market Master! Nakuha na po namin ang official circular.',
        timestamp: now.subtract(const Duration(minutes: 15)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_1_3',
        conversationId: 'conv_omar_rivera_admin',
        senderId: 'VND-92858',
        senderName: 'Omar Rivera',
        senderRole: 'vendor',
        text: 'Sige po Market Master, susundin po namin ang SRP ceiling sa bigas.',
        timestamp: now.subtract(const Duration(minutes: 12)),
        isRead: false,
      ),
    ];

    // 2. Mer's Mayao (Fruit) - Stall Holder ↔ Market Admin
    final conv2 = ChatConversation(
      id: 'conv_fruit_stand_admin',
      stallId: 'v1',
      stallName: "Mer's Mayao (Fruit)",
      customerUid: 'admin-market-master',
      customerName: 'PalengkeGo Market Admin',
      lastMessageText: 'Noted po Market Admin. Lilinisin na po namin ang fruit racks bago mag-closing.',
      lastMessageTimestamp: now.subtract(const Duration(hours: 1, minutes: 20)),
      lastMessageSenderId: 'v1',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      adminUnreadCount: 0,
      inquiryType: 'general',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 1, minutes: 20)),
    );

    final msg2 = [
      ChatMessage(
        id: 'msg_2_1',
        conversationId: 'conv_fruit_stand_admin',
        senderId: 'admin-market-master',
        senderName: 'PalengkeGo Market Admin',
        senderRole: 'admin',
        text: 'Paalala lang po ukol sa scheduled deep cleaning at sanitation ng fruit section bukas ng alas-sais ng gabi.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 30)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_2_2',
        conversationId: 'conv_fruit_stand_admin',
        senderId: 'v1',
        senderName: "Mer's Mayao",
        senderRole: 'vendor',
        text: 'Noted po Market Admin. Lilinisin na po namin ang fruit racks bago mag-closing.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 20)),
        isRead: true,
      ),
    ];

    // 3. Cora Morales (Manilatas) - Stall Holder ↔ Market Admin
    final conv3 = ChatConversation(
      id: 'conv_admin_cora_morales',
      stallId: 'VND-29482',
      stallName: 'Cora Morales (Manilatas)',
      customerUid: 'admin-market-master',
      customerName: 'PalengkeGo Market Admin',
      lastMessageText: 'Maraming salamat po sa abiso Market Master, naipasa na po ang renewal form.',
      lastMessageTimestamp: now.subtract(const Duration(hours: 3)),
      lastMessageSenderId: 'VND-29482',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      adminUnreadCount: 1,
      inquiryType: 'general',
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(hours: 3)),
    );

    final msg3 = [
      ChatMessage(
        id: 'msg_3_1',
        conversationId: 'conv_admin_cora_morales',
        senderId: 'admin-market-master',
        senderName: 'PalengkeGo Market Admin',
        senderRole: 'admin',
        text: 'Paalala lamang po mula sa Market Administration ukol sa darating na stall permit renewal ngayong buwan.',
        timestamp: now.subtract(const Duration(hours: 4)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_3_2',
        conversationId: 'conv_admin_cora_morales',
        senderId: 'VND-29482',
        senderName: 'Cora Morales',
        senderRole: 'vendor',
        text: 'Maraming salamat po sa abiso Market Master, naipasa na po ang renewal form.',
        timestamp: now.subtract(const Duration(hours: 3)),
        isRead: false,
      ),
    ];

    // 4. Mateo Garcia (Vegetables) - Stall Holder ↔ Market Admin
    final conv4 = ChatConversation(
      id: 'conv_mateo_admin',
      stallId: 'VND-83742',
      stallName: 'Mateo Garcia (Vegetables)',
      customerUid: 'admin-market-master',
      customerName: 'PalengkeGo Market Admin',
      lastMessageText: 'Approved po Kuya Mateo. Naabisuhan na po ang security guards sa gate para sa inyong delivery truck.',
      lastMessageTimestamp: now.subtract(const Duration(days: 1, hours: 2)),
      lastMessageSenderId: 'admin-market-master',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      adminUnreadCount: 0,
      inquiryType: 'general',
      createdAt: now.subtract(const Duration(days: 4)),
      updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
    );

    final msg4 = [
      ChatMessage(
        id: 'msg_4_1',
        conversationId: 'conv_mateo_admin',
        senderId: 'VND-83742',
        senderName: 'Mateo Garcia',
        senderRole: 'vendor',
        text: 'Market Master, humihingi po sana ng clearance para sa maagang delivery unloading bukas ng 4:00 AM sa Bay 2.',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_4_2',
        conversationId: 'conv_mateo_admin',
        senderId: 'admin-market-master',
        senderName: 'PalengkeGo Market Admin',
        senderRole: 'admin',
        text: 'Approved po Kuya Mateo. Naabisuhan na po ang security guards sa gate para sa inyong delivery truck.',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),
    ];

    _localConversations.addAll([conv1, conv2, conv3, conv4]);
    _localMessages['conv_omar_rivera_admin'] = msg1;
    _localMessages['conv_fruit_stand_admin'] = msg2;
    _localMessages['conv_admin_cora_morales'] = msg3;
    _localMessages['conv_mateo_admin'] = msg4;
  }

  void _notifyConversations() {
    _localConversations.sort(
      (a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
    );
    _conversationsStreamController.add(List.unmodifiable(_localConversations));
  }

  void _notifyMessages(String conversationId) {
    final list = _localMessages[conversationId] ?? [];
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId]!.add(List.unmodifiable(list));
    }
  }

  Future<void> _saveLocalStore() async {
    try {
      final convJson = jsonEncode(
        _localConversations.map((c) => c.toJson()).toList(),
      );
      final msgJson = jsonEncode(
        _localMessages.map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList())),
      );

      await _preferences.setString(_conversationsKey, convJson);
      await _preferences.setString(_messagesKey, msgJson);
    } catch (e) {
      debugPrint('[AdminMessaging] Error saving local store: $e');
    }
  }
}
