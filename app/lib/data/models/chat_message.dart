import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorAnimal,
  });

  final String id;
  final String groupId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String? authorAnimal;

  ChatMessage copyWith({
    String? authorDisplayName,
    String? authorAvatarUrl,
    String? authorAnimal,
  }) {
    return ChatMessage(
      id: id,
      groupId: groupId,
      userId: userId,
      body: body,
      createdAt: createdAt,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorAnimal: authorAnimal ?? this.authorAnimal,
    );
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      userId: map['user_id'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      authorDisplayName: map['author_display_name'] as String?,
      authorAvatarUrl: map['author_avatar_url'] as String?,
      authorAnimal: map['author_animal'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'author_display_name': authorDisplayName,
      'author_avatar_url': authorAvatarUrl,
      'author_animal': authorAnimal,
    };
  }
}
