import 'package:flutter/foundation.dart';

enum FeedbackTicketKind {
  feedback('feedback'),
  bug('bug');

  const FeedbackTicketKind(this.dbValue);

  final String dbValue;

  static FeedbackTicketKind fromDb(String value) {
    return FeedbackTicketKind.values.firstWhere(
      (kind) => kind.dbValue == value,
      orElse: () => FeedbackTicketKind.feedback,
    );
  }
}

enum FeedbackTicketStatus {
  open('open'),
  inProgress('in_progress'),
  closed('closed');

  const FeedbackTicketStatus(this.dbValue);

  final String dbValue;

  static FeedbackTicketStatus fromDb(String value) {
    return FeedbackTicketStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => FeedbackTicketStatus.open,
    );
  }
}

@immutable
class FeedbackTicket {
  const FeedbackTicket({
    required this.id,
    required this.userId,
    required this.kind,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reporterDisplayName,
  });

  final String id;
  final String userId;
  final FeedbackTicketKind kind;
  final String subject;
  final String message;
  final FeedbackTicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reporterDisplayName;

  FeedbackTicket copyWith({
    FeedbackTicketStatus? status,
    DateTime? updatedAt,
    String? reporterDisplayName,
  }) {
    return FeedbackTicket(
      id: id,
      userId: userId,
      kind: kind,
      subject: subject,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reporterDisplayName: reporterDisplayName ?? this.reporterDisplayName,
    );
  }

  factory FeedbackTicket.fromMap(Map<String, dynamic> map) {
    return FeedbackTicket(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      kind: FeedbackTicketKind.fromDb(map['kind'] as String),
      subject: map['subject'] as String,
      message: map['message'] as String,
      status: FeedbackTicketStatus.fromDb(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      reporterDisplayName: map['reporter_display_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'kind': kind.dbValue,
      'subject': subject,
      'message': message,
      'status': status.dbValue,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'reporter_display_name': reporterDisplayName,
    };
  }
}
