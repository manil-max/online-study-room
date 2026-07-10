import 'package:flutter/foundation.dart';

@immutable
class Nudge {
  const Nudge({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    this.message,
    this.readAt,
    this.senderDisplayName,
    this.senderAvatarUrl,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String recipientId;
  final String? message;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? senderDisplayName;
  final String? senderAvatarUrl;

  Nudge copyWith({
    DateTime? readAt,
    String? senderDisplayName,
    String? senderAvatarUrl,
  }) {
    return Nudge(
      id: id,
      groupId: groupId,
      senderId: senderId,
      recipientId: recipientId,
      message: message,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
    );
  }

  factory Nudge.fromMap(Map<String, dynamic> map) {
    return Nudge(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String,
      message: map['message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'] as String),
      senderDisplayName: map['sender_display_name'] as String?,
      senderAvatarUrl: map['sender_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'sender_display_name': senderDisplayName,
      'sender_avatar_url': senderAvatarUrl,
    };
  }
}
