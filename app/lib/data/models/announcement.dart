import 'package:flutter/foundation.dart';

@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.targetType,
    this.targetId,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String title;
  final String message;
  final String targetType; // 'all', 'group', 'user'
  final String? targetId;
  final DateTime createdAt;
  final String createdBy;

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      targetType: map['target_type'] as String,
      targetId: map['target_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      createdBy: map['created_by'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      'created_by': createdBy,
    };
  }
}
