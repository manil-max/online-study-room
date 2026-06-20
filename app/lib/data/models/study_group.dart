import 'package:flutter/foundation.dart';

/// Çalışma sınıfı (grup). Supabase `groups` tablosuna karşılık gelir (bkz. project.md §6).
@immutable
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  StudyGroup copyWith({String? name, String? inviteCode}) {
    return StudyGroup(
      id: id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  factory StudyGroup.fromMap(Map<String, dynamic> map) {
    return StudyGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      inviteCode: map['invite_code'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is StudyGroup &&
      other.id == id &&
      other.name == name &&
      other.inviteCode == inviteCode &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, inviteCode, createdBy, createdAt);
}
