/// Represents a single chat message sent within a conversation thread.
class ChatMessage {
  /// Unique message identifier.
  final String id;

  /// Identifier of the parent conversation.
  final String conversationId;

  /// Identifier of the sender (admin UID or vendor/customer ID).
  final String senderId;

  /// Display name of the sender.
  final String senderName;

  /// Role of the sender ('customer', 'vendor', or 'admin').
  final String senderRole;

  /// Body text content of the message.
  final String text;

  /// Timestamp when the message was sent.
  final DateTime timestamp;

  /// Whether the message has been marked as read.
  final bool isRead;

  /// Timestamp when the message was read, if applicable.
  final DateTime? readAt;

  /// URL of any optional media attachment.
  final String? attachmentUrl;

  /// MIME or category type of attachment (e.g., 'image').
  final String? attachmentType;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.readAt,
    this.attachmentUrl,
    this.attachmentType,
  });

  /// True if sent by a Market Admin.
  bool get isFromAdmin => senderRole == 'admin';

  /// True if sent by a vendor or stall holder.
  bool get isFromVendor => senderRole == 'vendor';

  /// True if sent by a customer.
  bool get isFromCustomer => senderRole == 'customer';

  /// True if the message includes a media attachment.
  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

  /// Creates a copy of this message with specified fields replaced.
  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    DateTime? readAt,
    String? attachmentUrl,
    String? attachmentType,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentType != null) 'attachment_type': attachmentType,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? json['message_id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? json['conversationId'] ?? '').toString(),
      senderId: (json['sender_id'] ?? json['senderId'] ?? '').toString(),
      senderName: (json['sender_name'] ?? json['senderName'] ?? '').toString(),
      senderRole: (json['sender_role'] ?? json['senderRole'] ?? 'customer').toString(),
      text: (json['text'] ?? json['message'] ?? '').toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isRead: json['is_read'] == true || json['isRead'] == true,
      readAt: json['read_at'] != null || json['readAt'] != null
          ? DateTime.tryParse((json['read_at'] ?? json['readAt']).toString())
          : null,
      attachmentUrl: (json['attachment_url'] ?? json['attachmentUrl']) as String?,
      attachmentType: (json['attachment_type'] ?? json['attachmentType']) as String?,
    );
  }
}
