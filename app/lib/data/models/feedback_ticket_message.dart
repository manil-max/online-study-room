import 'package:flutter/foundation.dart';

enum FeedbackTicketSenderRole {
  admin('admin'),
  user('user');

  const FeedbackTicketSenderRole(this.dbValue);

  final String dbValue;

  static FeedbackTicketSenderRole fromDb(String value) {
    return FeedbackTicketSenderRole.values.firstWhere(
      (role) => role.dbValue == value,
      orElse: () => FeedbackTicketSenderRole.user,
    );
  }
}

@immutable
class FeedbackTicketMessage {
  const FeedbackTicketMessage({
    required this.id,
    required this.ticketId,
    // WP-464: hesap silinince sunucu bu alani NULL'lar (`0114`, on delete set
    // null) ve kanit `sender_hash` takma kimligiyle durur. Zorunlu okumak
    // silinmis gonderici olan bir bileti acan herkeste ekrani cokertirdi.
    this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
    required this.messageSeq,
    this.clientMessageId,
    this.readAt,
  });

  final String id;
  final String ticketId;
  final String? senderId;
  final FeedbackTicketSenderRole senderRole;
  final String message;
  final DateTime createdAt;
  final int messageSeq;
  final String? clientMessageId;
  final DateTime? readAt;

  factory FeedbackTicketMessage.fromMap(Map<String, dynamic> map) {
    return FeedbackTicketMessage(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      senderId: map['sender_id'] as String?,
      senderRole: FeedbackTicketSenderRole.fromDb(map['sender_role'] as String),
      message: map['message'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      messageSeq: (map['message_seq'] as num?)?.toInt() ?? 0,
      clientMessageId: map['client_message_id'] as String?,
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'] as String),
    );
  }
}
