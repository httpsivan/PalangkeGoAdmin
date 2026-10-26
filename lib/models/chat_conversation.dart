/// Represents a messaging thread between Market Admin and a stall holder / vendor.
class ChatConversation {
  /// Unique conversation identifier.
  final String id;

  /// Identifier of the stall holder or vendor.
  final String stallId;

  /// Display name of the stall (e.g., "Omar Rivera (Sari-sari)").
  final String stallName;

  /// Optional avatar image URL for the stall.
  final String? stallAvatar;

  /// UID of the customer or admin participant.
  final String customerUid;

  /// Display name of the customer or admin.
  final String customerName;

  /// Optional avatar image URL for customer/admin.
  final String? customerAvatar;

  /// Text content of the most recent message in the thread.
  final String lastMessageText;

  /// Timestamp when the most recent message was sent.
  final DateTime lastMessageTimestamp;

  /// Sender identifier of the most recent message.
  final String lastMessageSenderId;

  /// Unread message count for the customer view.
  final int customerUnreadCount;

  /// Unread message count for the vendor view.
  final int vendorUnreadCount;

  /// Unread message count requiring Market Admin review.
  final int adminUnreadCount;

  /// Category or inquiry type ('product', 'order', 'delivery', 'general').
  final String inquiryType;

  /// Optional related order identifier if inquiring about a specific order.
  final String? relatedOrderId;

  /// Timestamp when the conversation was initialized.
  final DateTime createdAt;

  /// Timestamp when the conversation was last updated.
  final DateTime updatedAt;

  const ChatConversation({
    required this.id,
    required this.stallId,
    required this.stallName,
    this.stallAvatar,
    required this.customerUid,
    required this.customerName,
    this.customerAvatar,
    required this.lastMessageText,
    required this.lastMessageTimestamp,
    required this.lastMessageSenderId,
    this.customerUnreadCount = 0,
    this.vendorUnreadCount = 0,
    this.adminUnreadCount = 0,
    this.inquiryType = 'general',
    this.relatedOrderId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True if there are unread messages requiring admin attention.
  bool get hasUnreadForAdmin =>
      adminUnreadCount > 0 || customerUnreadCount > 0 || vendorUnreadCount > 0;

  /// Returns the formatted stall name with category tag formatted in Title Case.
  /// E.g., "Mer's Mayao Fruit Stand" -> "Mer's Mayao (Fruit)".
  String get displayStallName {
    var name = stallName;
    if (!name.contains('(') && name.toLowerCase().contains('fruit')) {
      name = '${name.replaceAll(RegExp(r'\s+fruit\s+stand', caseSensitive: false), '')} (Fruit)';
    }
    return name.replaceAllMapped(RegExp(r'\(([^)]+)\)'), (m) {
      final inner = m.group(1) ?? '';
      if (inner.isEmpty) return '()';
      return '(${inner[0].toUpperCase()}${inner.substring(1).toLowerCase()})';
    });
  }

  /// Creates a copy of this conversation with specified fields replaced.
  ChatConversation copyWith({
    String? id,
    String? stallId,
    String? stallName,
    String? stallAvatar,
    String? customerUid,
    String? customerName,
    String? customerAvatar,
    String? lastMessageText,
    DateTime? lastMessageTimestamp,
    String? lastMessageSenderId,
    int? customerUnreadCount,
    int? vendorUnreadCount,
    int? adminUnreadCount,
    String? inquiryType,
    String? relatedOrderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      stallId: stallId ?? this.stallId,
      stallName: stallName ?? this.stallName,
      stallAvatar: stallAvatar ?? this.stallAvatar,
      customerUid: customerUid ?? this.customerUid,
      customerName: customerName ?? this.customerName,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      customerUnreadCount: customerUnreadCount ?? this.customerUnreadCount,
      vendorUnreadCount: vendorUnreadCount ?? this.vendorUnreadCount,
      adminUnreadCount: adminUnreadCount ?? this.adminUnreadCount,
      inquiryType: inquiryType ?? this.inquiryType,
      relatedOrderId: relatedOrderId ?? this.relatedOrderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes this conversation to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stall_id': stallId,
      'stall_name': stallName,
      'stall_avatar': stallAvatar,
      'customer_uid': customerUid,
      'customer_name': customerName,
      'customer_avatar': customerAvatar,
      'last_message_text': lastMessageText,
      'last_message_timestamp': lastMessageTimestamp.toIso8601String(),
      'last_message_sender_id': lastMessageSenderId,
      'customer_unread_count': customerUnreadCount,
      'vendor_unread_count': vendorUnreadCount,
      'admin_unread_count': adminUnreadCount,
      'inquiry_type': inquiryType,
      'related_order_id': relatedOrderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes a conversation from a database row or JSON map.
  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: (json['id'] ?? json['conversation_id'] ?? '').toString(),
      stallId: (json['stall_id'] ?? json['stallId'] ?? '').toString(),
      stallName: (json['stall_name'] ?? json['stallName'] ?? 'Stall Holder').toString(),
      stallAvatar: (json['stall_avatar'] ?? json['stallAvatar']) as String?,
      customerUid: (json['customer_uid'] ?? json['customerUid'] ?? '').toString(),
      customerName: (json['customer_name'] ?? json['customerName'] ?? 'Customer').toString(),
      customerAvatar: (json['customer_avatar'] ?? json['customerAvatar']) as String?,
      lastMessageText: (json['last_message_text'] ?? json['lastMessageText'] ?? '').toString(),
      lastMessageTimestamp: json['last_message_timestamp'] != null || json['lastMessageTimestamp'] != null
          ? DateTime.tryParse((json['last_message_timestamp'] ?? json['lastMessageTimestamp']).toString()) ??
              DateTime.now()
          : (json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      lastMessageSenderId: (json['last_message_sender_id'] ?? json['lastMessageSenderId'] ?? '').toString(),
      customerUnreadCount: (json['customer_unread_count'] ?? json['customerUnreadCount'] as num?)?.toInt() ?? 0,
      vendorUnreadCount: (json['vendor_unread_count'] ?? json['vendorUnreadCount'] as num?)?.toInt() ?? 0,
      adminUnreadCount: (json['admin_unread_count'] ?? json['adminUnreadCount'] as num?)?.toInt() ?? 0,
      inquiryType: (json['inquiry_type'] ?? json['inquiryType'] ?? 'general').toString(),
      relatedOrderId: (json['related_order_id'] ?? json['relatedOrderId']) as String?,
      createdAt: json['created_at'] != null || json['createdAt'] != null
          ? DateTime.tryParse((json['created_at'] ?? json['createdAt']).toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null || json['updatedAt'] != null
          ? DateTime.tryParse((json['updated_at'] ?? json['updatedAt']).toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
