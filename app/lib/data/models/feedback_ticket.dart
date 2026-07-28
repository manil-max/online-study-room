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

/// WP-387: Destek kutusundaki ürün anlamı. Eski `kind` alanı geri bildirim
/// formunun "geri bildirim/hata" seçimini korur; bu alan ise destek akışını
/// (geri bildirim, soru veya rapor) sunucuda sınıflandırır.
enum FeedbackTicketType {
  feedback('feedback'),
  question('question'),
  report('report');

  const FeedbackTicketType(this.dbValue);

  final String dbValue;

  static FeedbackTicketType fromDb(String? value) {
    return FeedbackTicketType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => FeedbackTicketType.feedback,
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
    this.type = FeedbackTicketType.feedback,
    this.reporterDisplayName,
    this.attachmentPath,
    this.archivedAt,
  });

  final String id;
  final String userId;
  final FeedbackTicketKind kind;
  final String subject;
  final String message;
  final FeedbackTicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FeedbackTicketType type;
  final String? reporterDisplayName;
  final String? attachmentPath;
  final DateTime? archivedAt;

  FeedbackTicket copyWith({
    FeedbackTicketStatus? status,
    DateTime? updatedAt,
    FeedbackTicketType? type,
    String? reporterDisplayName,
    String? attachmentPath,
    DateTime? archivedAt,
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
      type: type ?? this.type,
      reporterDisplayName: reporterDisplayName ?? this.reporterDisplayName,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      archivedAt: archivedAt ?? this.archivedAt,
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
      type: FeedbackTicketType.fromDb(map['ticket_type'] as String?),
      reporterDisplayName: map['reporter_display_name'] as String?,
      attachmentPath: map['attachment_path'] as String?,
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.parse(map['archived_at'] as String),
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
      'ticket_type': type.dbValue,
      'reporter_display_name': reporterDisplayName,
      if (attachmentPath != null) 'attachment_path': attachmentPath,
      if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
    };
  }
}
