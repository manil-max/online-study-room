import 'package:flutter/foundation.dart';

@immutable
class FeedbackTicketNote {
  const FeedbackTicketNote({
    required this.id,
    required this.ticketId,
    required this.adminId,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String adminId;
  final String note;
  final DateTime createdAt;

  factory FeedbackTicketNote.fromMap(Map<String, dynamic> map) {
    return FeedbackTicketNote(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      adminId: map['admin_id'] as String,
      note: map['note'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticket_id': ticketId,
      'admin_id': adminId,
      'note': note,
    };
  }
}
