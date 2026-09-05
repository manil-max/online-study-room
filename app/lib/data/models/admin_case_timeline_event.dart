import 'package:flutter/foundation.dart';

/// WP-796 — vakanın **zaman çizelgesi** için tek olay.
///
/// Kaynak `moderation_audit_events` (`0106`, WP-442): append-only zincir.
/// Tetikleyiciler her durum değişimini actor + zaman + eski/yeni + gerekçe
/// ile düşürür: vaka (`opened`/`updated`), yaptırım (`opened`/`state_changed`),
/// itiraz (`submitted`/`decided`).
///
/// 🔴 Bu tablo `0106`dan beri **doluyor ve istemci hiç okumadı** — deponun
/// tekrar eden kusuru ("bitmiş arka uç, bağlanmamış ön uç"). Zaman çizelgesi
/// bu yüzden migration'sız çıkar: sunucuda eksik olan şey yok, okuyan yoktu.
///
/// Sınıf **ham kaydı** taşır; ekranın çizdiği metin [kind] üzerinden türetilir.
/// Sunucu `action` adlarını yeniden adlandırırsa [kind] `other` döner —
/// yanlış bir dala **yuvarlanmaz**, ham `action` gösterilir.
@immutable
class AdminCaseTimelineEvent {
  const AdminCaseTimelineEvent({
    required this.id,
    required this.occurredAt,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.actorId,
    this.oldValue,
    this.newValue,
    this.reason,
  });

  final String id;
  final DateTime occurredAt;

  /// `0114` sonrası silinen yönetici için `null`; kanıt `actor_hash` ile durur.
  final String? actorId;

  /// `case` · `sanction` · `appeal`
  final String entityType;
  final String entityId;
  final String action;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? reason;

  AdminCaseTimelineKind get kind {
    switch ('$entityType:$action') {
      case 'case:opened':
        return AdminCaseTimelineKind.caseOpened;
      case 'case:updated':
        if (_changed('status')) return AdminCaseTimelineKind.statusChanged;
        if (_changed('quarantined')) {
          return AdminCaseTimelineKind.quarantineChanged;
        }
        if (_changed('severity')) return AdminCaseTimelineKind.severityChanged;
        return AdminCaseTimelineKind.other;
      case 'sanction:opened':
        return AdminCaseTimelineKind.sanctionApplied;
      case 'sanction:state_changed':
        return AdminCaseTimelineKind.sanctionStateChanged;
      case 'appeal:submitted':
        return AdminCaseTimelineKind.appealSubmitted;
      case 'appeal:decided':
        return AdminCaseTimelineKind.appealDecided;
    }
    return AdminCaseTimelineKind.other;
  }

  bool _changed(String key) => oldValue?[key] != newValue?[key];

  /// Yeni değerdeki alan; yoksa `null`.
  String? newField(String key) => newValue?[key]?.toString();
  String? oldField(String key) => oldValue?[key]?.toString();

  factory AdminCaseTimelineEvent.fromWire(Map<String, dynamic> map) {
    Map<String, dynamic>? asMap(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    return AdminCaseTimelineEvent(
      id: (map['id'] ?? '').toString(),
      occurredAt:
          DateTime.tryParse((map['occurred_at'] ?? '').toString())?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      actorId: map['actor_id'] as String?,
      entityType: (map['entity_type'] ?? '').toString(),
      entityId: (map['entity_id'] ?? '').toString(),
      action: (map['action'] ?? '').toString(),
      oldValue: asMap(map['old_value']),
      newValue: asMap(map['new_value']),
      reason: (map['reason'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['reason'] as String).trim(),
    );
  }
}

enum AdminCaseTimelineKind {
  caseOpened,
  statusChanged,
  quarantineChanged,
  severityChanged,
  sanctionApplied,
  sanctionStateChanged,
  appealSubmitted,
  appealDecided,
  other,
}

/// Eskiden yeniye sıralar; eşit anlarda kimlik sırası (determinist).
List<AdminCaseTimelineEvent> sortCaseTimeline(
  Iterable<AdminCaseTimelineEvent> events,
) {
  final list = events.toList();
  list.sort((a, b) {
    final byTime = a.occurredAt.compareTo(b.occurredAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return list;
}
