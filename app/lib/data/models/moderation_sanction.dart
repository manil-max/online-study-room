import 'package:flutter/foundation.dart';

/// WP-441: Basamaklı yaptırım sözleşmesi.
///
/// Yaptırım **iki fazlıdır**: sunucuda önce `pending` satır açılır, auth
/// tarafı işini yapar, sonra tek transaction'da `applied|failed` yazılır ve
/// denetim satırı düşer. İstemci bu sözleşmeyi taklit etmez; yalnız hangi
/// basamağın istendiğini ve tekrar gönderimi ayıran anahtarı taşır.
enum ModerationAction {
  /// Kayıt için "aksiyon yok" — vaka kapanır, kullanıcıya bir şey olmaz.
  noAction('no_action'),

  /// Kullanıcıya gerçekten iletilen uyarı (kayıt + bildirim).
  warn('warn'),

  /// Görünen adı sıfırla; geri alma `restore_user_name` ile.
  nameReset('name_reset'),

  /// 24 saat **yalnız-yazma** kısıtı. Okuma açıktır, auth ban değildir.
  mute24h('mute_24h'),

  suspend24h('suspend_24h'),
  suspend7d('suspend_7d'),
  suspend14d('suspend_14d'),
  suspend30d('suspend_30d'),
  banPermanent('ban_permanent');

  const ModerationAction(this.wire);

  final String wire;

  /// Hedefin hesabını/yazmasını kısıtlıyor mu?
  ///
  /// Sunucuda hedef başına **tek** aktif kısıtlayıcı yaptırım olabilir; bu
  /// ayrım oradaki kısmi tekil indeksle birebir aynıdır.
  bool get isRestrictive => switch (this) {
    ModerationAction.noAction ||
    ModerationAction.warn ||
    ModerationAction.nameReset => false,
    _ => true,
  };

  /// Auth tarafında oturum kapatma/ban gerektiriyor mu?
  ///
  /// `mute24h` **gerektirmez**: susturulan kullanıcı uygulamayı okumaya devam
  /// eder, yalnız mesaj yazamaz. Eski akış burada auth ban kuruyordu ve
  /// kullanıcıyı tamamen dışarı atıyordu.
  bool get requiresAuthBan => switch (this) {
    ModerationAction.suspend24h ||
    ModerationAction.suspend7d ||
    ModerationAction.suspend14d ||
    ModerationAction.suspend30d ||
    ModerationAction.banPermanent => true,
    _ => false,
  };

  /// Kısıtın süresi; kalıcı ban ve süresiz olmayan basamaklarda `null`.
  Duration? get duration => switch (this) {
    ModerationAction.mute24h ||
    ModerationAction.suspend24h => const Duration(hours: 24),
    ModerationAction.suspend7d => const Duration(days: 7),
    ModerationAction.suspend14d => const Duration(days: 14),
    ModerationAction.suspend30d => const Duration(days: 30),
    _ => null,
  };

  static ModerationAction fromWire(String wire) {
    for (final value in ModerationAction.values) {
      if (value.wire == wire) return value;
    }
    throw ArgumentError.value(wire, 'wire', 'bilinmeyen moderasyon aksiyonu');
  }
}

/// Yaptırımın yaşam döngüsü.
///
/// `pending` = sunucuda açıldı ama auth tarafı sonucu daha yazılmadı. Bu satır
/// **aktif yaptırım sayılmaz**: yarım kalan işlem kullanıcıyı cezalı bırakmaz,
/// uzlaştırma onu `failed`e çevirir ve admin yeniden uygulayabilir.
enum ModerationSanctionState {
  pending('pending'),
  applied('applied'),
  failed('failed'),
  revoked('revoked');

  const ModerationSanctionState(this.wire);

  final String wire;

  static ModerationSanctionState fromWire(String wire) {
    for (final value in ModerationSanctionState.values) {
      if (value.wire == wire) return value;
    }
    throw ArgumentError.value(wire, 'wire', 'bilinmeyen moderasyon durumu');
  }
}

@immutable
class ModerationSanction {
  const ModerationSanction({
    required this.id,
    required this.targetUserId,
    required this.action,
    required this.reason,
    required this.state,
    this.caseId,
    this.appliedAt,
    this.expiresAt,
    this.revokedAt,
    this.failureReason,
  });

  factory ModerationSanction.fromWire(Map<String, dynamic> map) {
    DateTime? parse(Object? value) => value is String
        ? DateTime.tryParse(value)?.toLocal()
        : null;
    return ModerationSanction(
      id: map['id'] as String,
      targetUserId: map['target_user_id'] as String,
      action: ModerationAction.fromWire(map['action'] as String),
      reason: (map['reason'] as String?) ?? '',
      state: ModerationSanctionState.fromWire(map['state'] as String),
      caseId: map['case_id'] as String?,
      appliedAt: parse(map['applied_at']),
      expiresAt: parse(map['expires_at']),
      revokedAt: parse(map['revoked_at']),
      failureReason: map['failure_reason'] as String?,
    );
  }

  final String id;
  final String targetUserId;
  final ModerationAction action;
  final String reason;
  final ModerationSanctionState state;
  final String? caseId;
  final DateTime? appliedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final String? failureReason;

  /// Şu an gerçekten yürürlükte mi?
  ///
  /// Süre dolduğunda satır silinmez; kullanıcı kendiliğinden geri açılır.
  bool isActive(DateTime now) =>
      state == ModerationSanctionState.applied &&
      action.isRestrictive &&
      (expiresAt == null || expiresAt!.isAfter(now));

  @override
  bool operator ==(Object other) =>
      other is ModerationSanction &&
      other.id == id &&
      other.state == state &&
      other.action == action &&
      other.expiresAt == expiresAt &&
      other.revokedAt == revokedAt;

  @override
  int get hashCode => Object.hash(id, state, action, expiresAt, revokedAt);
}

/// Tek yaptırım denemesi.
///
/// [idempotencyKey] **deneme başına** üretilir ve yeniden gönderimde aynı
/// kalır: sunucu aynı anahtarı ikinci kez gördüğünde yeni yaptırım açmaz,
/// mevcut kaydı geri verir. Anahtar üretimini istemcinin yapması şart, çünkü
/// "istek gitti mi gitmedi mi" belirsizliği yalnız istemcide bilinir.
@immutable
class ModerationSanctionRequest {
  const ModerationSanctionRequest({
    required this.targetUserId,
    required this.action,
    required this.reason,
    required this.idempotencyKey,
    this.caseId,
  });

  final String targetUserId;
  final ModerationAction action;
  final String reason;
  final String idempotencyKey;
  final String? caseId;

  static const int minKeyLength = 8;

  bool get isValid =>
      targetUserId.trim().isNotEmpty &&
      reason.trim().isNotEmpty &&
      idempotencyKey.trim().length >= minKeyLength;

  Map<String, dynamic> toFunctionBody() => {
    'action': action.wire,
    'targetUserId': targetUserId,
    'reason': reason.trim(),
    'idempotencyKey': idempotencyKey,
    if (caseId != null) 'caseId': caseId,
  };
}
