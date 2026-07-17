/// WP-114: `my_account_deletion_status` RPC yanıtı.
class AccountDeletionStatus {
  const AccountDeletionStatus({
    required this.active,
    this.status,
    this.requestedAt,
    this.purgeAfter,
  });

  final bool active;
  final String? status;
  final DateTime? requestedAt;
  final DateTime? purgeAfter;

  factory AccountDeletionStatus.fromMap(Map<String, dynamic> map) {
    DateTime? parse(String? k) {
      final v = map[k];
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return AccountDeletionStatus(
      active: map['active'] as bool? ?? false,
      status: map['status'] as String?,
      requestedAt: parse('requested_at'),
      purgeAfter: parse('purge_after'),
    );
  }

  static const inactive = AccountDeletionStatus(active: false);
}
