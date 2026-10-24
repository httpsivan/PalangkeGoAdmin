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

final adminConversationsProvider =
    StreamProvider.autoDispose<List<ChatConversation>>((ref) async* {
  final repo = ref.watch(adminMessagingRepositoryProvider);
  final initial = await repo.getConversations();
  yield initial;
  yield* repo.watchConversations();
});

final adminUnreadMessagesCountProvider = Provider<int>((ref) {
  final conversationsAsync = ref.watch(adminConversationsProvider);
  return conversationsAsync.maybeWhen(
    data: (conversations) {
      return conversations.where((c) => c.hasUnreadForAdmin).length;
    },
    orElse: () => 0,
  );
});

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

  static const _conversationsKey = 'mock_chat_conversations_v1';
  static const _messagesKey = 'mock_chat_messages_v1';

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

  Stream<List<ChatConversation>> watchConversations() {
    final client = _client;
    if (client != null) {
      try {
        return client
            .from('conversations')
            .stream(primaryKey: ['id'])
            .order('last_message_timestamp', ascending: false)
            .map((rows) => rows.map((r) => ChatConversation.fromJson(r)).toList());
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase stream error, falling back to local: $e');
      }
    }
    return _conversationsStreamController.stream;
  }

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
            .toList();
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase getConversations error: $e');
      }
    }

    await _ensureLoaded();
    return List.unmodifiable(_localConversations);
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    final client = _client;
    if (client != null) {
      try {
        return client
            .from('messages')
            .stream(primaryKey: ['id'])
            .eq('conversation_id', conversationId)
            .order('timestamp', ascending: true)
            .map((rows) => rows.map((r) => ChatMessage.fromJson(r)).toList());
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

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('timestamp', ascending: true);
        return (response as List<dynamic>)
            .map((row) => ChatMessage.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList();
      } catch (e) {
        debugPrint('[AdminMessaging] Supabase getMessages error: $e');
      }
    }

    await _ensureLoaded();
    return List.unmodifiable(_localMessages[conversationId] ?? []);
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String text,
    String senderRole = 'admin',
    String senderName = 'PalengkeGo Admin',
    String senderId = 'admin-market-master',
    String? attachmentUrl,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final client = _client;

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
        };

        final inserted = await client.from('messages').insert(msgRow).select().single();
        final message = ChatMessage.fromJson(Map<String, dynamic>.from(inserted));

        await client.from('conversations').update({
          'last_message_text': text.trim(),
          'last_message_timestamp': nowIso,
          'last_message_sender_id': senderId,
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
    );

    final list = _localMessages.putIfAbsent(conversationId, () => []);
    list.add(message);
    _notifyMessages(conversationId);

    final convIdx = _localConversations.indexWhere((c) => c.id == conversationId);
    if (convIdx >= 0) {
      final updated = _localConversations[convIdx].copyWith(
        lastMessageText: text.trim(),
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

  Future<void> markAsRead(String conversationId) async {
    final client = _client;
    if (client != null) {
      try {
        final nowIso = DateTime.now().toIso8601String();
        await client
            .from('messages')
            .update({'is_read': true, 'read_at': nowIso})
            .eq('conversation_id', conversationId)
            .eq('is_read', false);

        await client.from('conversations').update({
          'customer_unread_count': 0,
          'vendor_unread_count': 0,
          'admin_unread_count': 0,
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

    // 1. Omar Rivera (Sari-Sari, Block 14 - Stall 2) with Customer Ana Santos
    final conv1 = ChatConversation(
      id: 'conv_omar_rivera_ana',
      stallId: 'VND-92858',
      stallName: 'Omar Rivera (SARI-SARI)',
      customerUid: 'cust_ana_santos',
      customerName: 'Ana Santos',
      lastMessageText: 'Available po ba yung bigas na Sinandomeng 5kg?',
      lastMessageTimestamp: now.subtract(const Duration(minutes: 12)),
      lastMessageSenderId: 'cust_ana_santos',
      vendorUnreadCount: 1,
      customerUnreadCount: 0,
      adminUnreadCount: 1,
      inquiryType: 'product',
      relatedOrderId: 'ORD-8924',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(minutes: 12)),
    );

    final msg1 = [
      ChatMessage(
        id: 'msg_1_1',
        conversationId: 'conv_omar_rivera_ana',
        senderId: 'cust_ana_santos',
        senderName: 'Ana Santos',
        senderRole: 'customer',
        text: 'Magandang araw po Mang Omar! Magtatanong lang po sana.',
        timestamp: now.subtract(const Duration(minutes: 18)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_1_2',
        conversationId: 'conv_omar_rivera_ana',
        senderId: 'VND-92858',
        senderName: 'Omar Rivera',
        senderRole: 'vendor',
        text: 'Opo ma\'am Ana, ano po yun?',
        timestamp: now.subtract(const Duration(minutes: 15)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_1_3',
        conversationId: 'conv_omar_rivera_ana',
        senderId: 'cust_ana_santos',
        senderName: 'Ana Santos',
        senderRole: 'customer',
        text: 'Available po ba yung bigas na Sinandomeng 5kg?',
        timestamp: now.subtract(const Duration(minutes: 12)),
        isRead: false,
      ),
    ];

    // 2. Mer's Mayao Fruit Stand with Customer Juan Dela Cruz
    final conv2 = ChatConversation(
      id: 'conv_fruit_stand_juan',
      stallId: 'v1',
      stallName: "Mer's Mayao Fruit Stand",
      customerUid: 'cust_juan_delacruz',
      customerName: 'Juan Dela Cruz',
      lastMessageText: 'Opo sir, sariwa po at bagong dating mula Batangas.',
      lastMessageTimestamp: now.subtract(const Duration(hours: 1, minutes: 20)),
      lastMessageSenderId: 'v1',
      vendorUnreadCount: 0,
      customerUnreadCount: 1,
      adminUnreadCount: 0,
      inquiryType: 'order',
      relatedOrderId: 'ORD-7712',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 1, minutes: 20)),
    );

    final msg2 = [
      ChatMessage(
        id: 'msg_2_1',
        conversationId: 'conv_fruit_stand_juan',
        senderId: 'cust_juan_delacruz',
        senderName: 'Juan Dela Cruz',
        senderRole: 'customer',
        text: 'Kumusta po! Matamis po ba ang mangga ngayon?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 30)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_2_2',
        conversationId: 'conv_fruit_stand_juan',
        senderId: 'v1',
        senderName: "Mer's Mayao Fruit Stand",
        senderRole: 'vendor',
        text: 'Opo sir, sariwa po at bagong dating mula Batangas.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 20)),
        isRead: false,
      ),
    ];

    // 3. Admin Market Master Direct Inquiry with Vendor Cora Morales
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

    // 4. Mateo Garcia (Vegetables) with Customer Maria Clara
    final conv4 = ChatConversation(
      id: 'conv_mateo_maria',
      stallId: 'VND-83742',
      stallName: 'Mateo Garcia (Vegetables)',
      customerUid: 'cust_maria_clara',
      customerName: 'Maria Clara',
      lastMessageText: 'Salamat po kuya Mateo! Natanggap ko na po ang delivery.',
      lastMessageTimestamp: now.subtract(const Duration(days: 1, hours: 2)),
      lastMessageSenderId: 'cust_maria_clara',
      vendorUnreadCount: 0,
      customerUnreadCount: 0,
      adminUnreadCount: 0,
      inquiryType: 'delivery',
      relatedOrderId: 'ORD-6531',
      createdAt: now.subtract(const Duration(days: 4)),
      updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
    );

    final msg4 = [
      ChatMessage(
        id: 'msg_4_1',
        conversationId: 'conv_mateo_maria',
        senderId: 'VND-83742',
        senderName: 'Mateo Garcia',
        senderRole: 'vendor',
        text: 'Nasa rider na po ang gulay order niyo ma\'am.',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_4_2',
        conversationId: 'conv_mateo_maria',
        senderId: 'cust_maria_clara',
        senderName: 'Maria Clara',
        senderRole: 'customer',
        text: 'Salamat po kuya Mateo! Natanggap ko na po ang delivery.',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),
    ];

    _localConversations.addAll([conv1, conv2, conv3, conv4]);
    _localMessages['conv_omar_rivera_ana'] = msg1;
    _localMessages['conv_fruit_stand_juan'] = msg2;
    _localMessages['conv_admin_cora_morales'] = msg3;
    _localMessages['conv_mateo_maria'] = msg4;
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
