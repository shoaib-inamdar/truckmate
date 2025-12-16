class ChatMessage {
  final String id;
  final String bookingId;
  final String senderId;
  final String senderType; // 'customer' or 'admin'
  final String message;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderType,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['\$id'] ?? '',
      bookingId: json['booking_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderType: json['sender_type'] ?? '',
      message: json['message'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'sender_id': senderId,
      'sender_type': senderType,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? bookingId,
    String? senderId,
    String? senderType,
    String? message,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}