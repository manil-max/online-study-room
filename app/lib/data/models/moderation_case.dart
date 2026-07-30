import 'package:flutter/foundation.dart';

import 'report_target.dart';

/// WP-440: Moderasyon kuyruğundaki bir **vaka**.
///
/// Kuyruk artık tek tek raporları değil, `admin_ugc_report_groups()` ile
/// hedef başına toplanmış vakaları gösterir: aynı hedefe gelen on rapor tek
/// kart, tek durum ve tek karardır.

/// Kuyrukta gösterilen kişi (şikâyet eden veya şikâyet edilen).
@immutable
class ModerationIdentity {
  const ModerationIdentity({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isDeleted = false,
  });

  /// Profili çözülemeyen kimlik: kart boş kalmaz, "silinmiş kullanıcı" olur.
  const ModerationIdentity.unresolved(this.id)
      : displayName = '',
        avatarUrl = null,
        isDeleted = true;

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isDeleted;

  @override
  bool operator ==(Object other) =>
      other is ModerationIdentity &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.isDeleted == isDeleted;

  @override
  int get hashCode => Object.hash(id, displayName, avatarUrl, isDeleted);
}

/// Vaka durumu.
///
/// `open` sunucuda satırın **varsayılan** durumudur ama
/// `admin_set_ugc_report_group_status` yalnız `in_review|resolved|rejected`
/// yazabilir. Bu yüzden `open` gösterilebilir, seçilemez: kuyrukta ölü bir
/// seçenek bırakmamak için [writable] ayrımı var. Yeniden açma
/// (`open`'a dönüş) `0105` yaptırım diliminde RPC'ye eklenecek; o güne kadar
/// kapatılan vaka [ModerationCaseStatus.inReview] ile geri alınır.
enum ModerationCaseStatus {
  open('open'),
  inReview('in_review'),
  resolved('resolved'),
  rejected('rejected');

  const ModerationCaseStatus(this.wire);

  final String wire;

  /// Sunucuya yazılabilir mi? `open` yalnız okunur.
  bool get writable => this != ModerationCaseStatus.open;

  /// Kart "Kapalı" mı gösteriyor?
  bool get isClosed =>
      this == ModerationCaseStatus.resolved ||
      this == ModerationCaseStatus.rejected;

  static const List<ModerationCaseStatus> writableValues = [
    ModerationCaseStatus.inReview,
    ModerationCaseStatus.resolved,
    ModerationCaseStatus.rejected,
  ];

  static ModerationCaseStatus fromWire(String wire) {
    for (final value in ModerationCaseStatus.values) {
      if (value.wire == wire) return value;
    }
    throw ArgumentError.value(wire, 'wire', 'bilinmeyen vaka durumu');
  }
}

@immutable
class ModerationCase {
  const ModerationCase({
    required this.targetType,
    required this.targetId,
    required this.targetIdentity,
    required this.status,
    required this.reportCount,
    required this.reasons,
    required this.latestAt,
    required this.reporters,
    required this.reportIds,
  });

  /// WP-439 sözleşmesi: tür + değişmez kimlik birlikte vakayı tekilleştirir.
  ///
  /// Kuyruk **okuma** tarafıdır; burada `ReportTarget` değer nesnesi
  /// kullanılmaz, çünkü o nesne mesaj hedefinde gerçek grup bağlamı ister ve
  /// grup RPC'si onu `0104`e kadar döndürmüyor. Uydurma bağlam yazmaktansa
  /// kuyruk yalnız gerçekten bildiği iki alanı taşır.
  final ReportTargetType targetType;
  final String targetId;

  /// Şikâyet edilen kişi; grup hedeflerinde çözülemez ve `null` olur.
  final ModerationIdentity? targetIdentity;

  final ModerationCaseStatus status;

  /// Bu vakaya kaç ayrı rapor düştü.
  final int reportCount;

  /// Vakadaki farklı gerekçeler (`harassment`, `spam`, …).
  final List<String> reasons;

  /// En son rapor zamanı — kuyruk sıralaması ve bekleme süresi bundan gelir.
  final DateTime latestAt;

  /// Şikâyet edenler; kartta ilki gösterilir, kalanı sayı olarak.
  final List<ModerationIdentity> reporters;

  /// Vakayı oluşturan rapor kimlikleri (detay/timeline girişi).
  final List<String> reportIds;

  String get caseKey => '${targetType.wire}:$targetId';

  /// Vaka açıldığından beri geçen süre. SLA rozeti WP-441'de bu değeri
  /// sunucudan gelen severity ile birleştirecek; şimdilik yalnız bekleme.
  Duration waitingFor(DateTime now) => now.difference(latestAt);

  ModerationCase copyWith({ModerationCaseStatus? status}) => ModerationCase(
        targetType: targetType,
        targetId: targetId,
        targetIdentity: targetIdentity,
        status: status ?? this.status,
        reportCount: reportCount,
        reasons: reasons,
        latestAt: latestAt,
        reporters: reporters,
        reportIds: reportIds,
      );
}
