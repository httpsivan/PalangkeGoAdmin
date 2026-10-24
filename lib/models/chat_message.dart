class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'customer' | 'vendor' | 'admin'
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readAt;
  final String? attachmentUrl;
  final String? attachmentType; // 'image', etc.

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

  bool get isFromAdmin => senderRole == 'admin';
  bool get isFromVendor => senderRole == 'vendor';
  bool get isFromCustomer => senderRole == 'customer';
  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

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
