import 'package:flutter/foundation.dart';

import 'moderation_sanction.dart';

/// WP-442: Yaptırıma itiraz.
///
/// Bir yaptırıma **tek** itiraz açılır: tekrar gönderim yeni kayıt üretmez,
/// mevcut itirazı geri verir. Kararı, yaptırımı uygulayan yöneticinin kendisi
/// veremez — sunucu bunu reddeder, istemci de düğmeyi hiç açmaz.
enum ModerationAppealStatus {
  open('open'),

  /// Yaptırım yerinde kaldı.
  upheld('upheld'),

  /// İtiraz kabul edildi; yaptırım kaldırıldı.
  overturned('overturned');

  const ModerationAppealStatus(this.wire);

  final String wire;

  bool get isDecided => this != ModerationAppealStatus.open;

  static ModerationAppealStatus fromWire(String wire) {
    for (final value in ModerationAppealStatus.values) {
      if (value.wire == wire) return value;
    }
    throw ArgumentError.value(wire, 'wire', 'bilinmeyen itiraz durumu');
  }
}

@immutable
class ModerationAppeal {
  const ModerationAppeal({
    required this.id,
    required this.sanctionId,
    required this.statement,
    required this.status,
    required this.createdAt,
    this.appellantId,
    this.sanctionAction,
    this.sanctionReason,
    this.decisionNote,
    this.decidable = true,
  });

  factory ModerationAppeal.fromWire(Map<String, dynamic> map) {
    final rawAction = map['sanction_action'] as String?;
    return ModerationAppeal(
      id: map['id'] as String,
      sanctionId: map['sanction_id'] as String,
      statement: (map['statement'] as String?) ?? '',
      status: ModerationAppealStatus.fromWire(map['status'] as String),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      appellantId: map['appellant_id'] as String?,
      sanctionAction: rawAction == null
          ? null
          : ModerationAction.fromWire(rawAction),
      sanctionReason: map['sanction_reason'] as String?,
      decisionNote: map['decision_note'] as String?,
      // Sunucu bunu `actor_id <> auth.uid()` ile hesaplar; istemci kendi
      // başına karar veremez.
      decidable: map['decidable'] != false,
    );
  }

  final String id;
  final String sanctionId;
  final String statement;
  final ModerationAppealStatus status;
  final DateTime createdAt;
  final String? appellantId;
  final ModerationAction? sanctionAction;
  final String? sanctionReason;
  final String? decisionNote;

  /// Bu itirazı **bu** yönetici karara bağlayabilir mi?
  ///
  /// Yaptırımı uygulayan kişi kendi kararını denetleyemez; sunucu reddeder,
  /// istemci de eylemi hiç göstermez.
  final bool decidable;

  bool get canBeDecidedNow => !status.isDecided && decidable;

  @override
  bool operator ==(Object other) =>
      other is ModerationAppeal &&
      other.id == id &&
      other.status == status &&
      other.decidable == decidable;

  @override
  int get hashCode => Object.hash(id, status, decidable);
}
