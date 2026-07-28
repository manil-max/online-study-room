class ModerationQueueIdentity {
  const ModerationQueueIdentity({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isDeleted = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isDeleted;
}

class ModerationQueueReport {
  const ModerationQueueReport({
    required this.id,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.contentSnapshot,
    required this.reporter,
    required this.target,
  });

  final String id;
  final String targetType;
  final String reason;
  final String status;
  final String? contentSnapshot;
  final ModerationQueueIdentity reporter;
  final ModerationQueueIdentity target;
}
