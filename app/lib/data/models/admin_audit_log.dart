import 'package:flutter/foundation.dart';

@immutable
class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    required this.adminId,
    this.targetUserId,
    this.targetUserEmail,
    required this.action,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String adminId;
  final String? targetUserId;
  final String? targetUserEmail;
  final String action;
  final String reason;
  final DateTime createdAt;

  factory AdminAuditLog.fromMap(Map<String, dynamic> map) {
    return AdminAuditLog(
      id: map['id'] as String,
      adminId: map['admin_id'] as String,
      targetUserId: map['target_user_id'] as String?,
      targetUserEmail: map['target_user_email'] as String?,
      action: map['action'] as String,
      reason: map['reason'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
