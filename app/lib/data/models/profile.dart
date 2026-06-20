import 'package:flutter/foundation.dart';

/// Kullanıcı profili. Supabase `profiles` tablosuna karşılık gelir (bkz. project.md §6).
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.createdAt,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  Profile copyWith({String? displayName, String? avatarUrl}) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, displayName, avatarUrl, createdAt);
}
