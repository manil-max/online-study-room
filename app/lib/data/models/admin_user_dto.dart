import 'package:flutter/foundation.dart';

@immutable
class AdminUserDto {
  const AdminUserDto({
    required this.id,
    required this.email,
    required this.createdAt,
    this.lastSignInAt,
    this.bannedUntil,
    this.deleted = false,
  });

  final String id;
  final String email;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final String? bannedUntil;
  final bool deleted;

  bool get isSuspended => bannedUntil != null && bannedUntil != 'none';

  factory AdminUserDto.fromMap(Map<String, dynamic> map) {
    return AdminUserDto(
      id: map['id'] as String,
      email: map['email'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastSignInAt: map['lastSignInAt'] != null
          ? DateTime.parse(map['lastSignInAt'] as String)
          : null,
      bannedUntil: map['bannedUntil'] as String?,
      deleted: map['deleted'] as bool? ?? false,
    );
  }
}
