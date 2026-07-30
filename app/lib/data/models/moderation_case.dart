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
/// WP-441 (`0105`) ile `admin_set_ugc_report_group_status` dört durumu da
/// yazar: yanlışlıkla kapatılan vaka gerçekten `open`'a döner, `in_review`e
/// sapmaz. [writable] bu yüzden artık her durum için doğrudur ve yalnız
/// sözleşmenin adı olarak duruyor.
enum ModerationCaseStatus {
  open('open'),
  inReview('in_review'),
  resolved('resolved'),
  rejected('rejected');

  const ModerationCaseStatus(this.wire);

  final String wire;

  /// Sunucuya yazılabilir mi? `0105` sonrası dört durum da yazılabilir.
  bool get writable => true;

  /// Kart "Kapalı" mı gösteriyor?
  bool get isClosed =>
      this == ModerationCaseStatus.resolved ||
      this == ModerationCaseStatus.rejected;

  static const List<ModerationCaseStatus> writableValues = [
    ModerationCaseStatus.open,
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
    this.caseId,
    this.severity = ModerationSeverity.normal,
    this.slaDueAt,
    this.quarantined = false,
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

  /// `moderation_cases` satır kimliği. `0104` öncesinden kalan, vakaya
  /// bağlanmamış tarihsel raporlarda `null`'dır — o satırlar karantina gibi
  /// vaka bazlı aksiyonları desteklemez.
  final String? caseId;

  /// Sunucunun hesapladığı önem. Yalnız sıralama/SLA içindir; hiçbir yaptırımı
  /// otomatik açmaz — "rapor geldi = suçlu" yoktur.
  final ModerationSeverity severity;

  /// İncelemenin bitmesi gereken an; geçtiyse kart gecikmiş sayılır.
  final DateTime? slaDueAt;

  /// İçerik inceleme bitene kadar üçüncü kişilere kapatıldı mı?
  final bool quarantined;

  String get caseKey => '${targetType.wire}:$targetId';

  /// Vaka açıldığından beri geçen süre.
  Duration waitingFor(DateTime now) => now.difference(latestAt);

  /// SLA aşıldı mı? Süre yoksa gecikme de yoktur.
  bool isOverdue(DateTime now) =>
      slaDueAt != null && !status.isClosed && now.isAfter(slaDueAt!);

  /// Karantina/yaptırım aksiyonları vaka kimliği ister.
  bool get supportsCaseActions => caseId != null;

  ModerationCase copyWith({
    ModerationCaseStatus? status,
    bool? quarantined,
  }) => ModerationCase(
        targetType: targetType,
        targetId: targetId,
        targetIdentity: targetIdentity,
        status: status ?? this.status,
        reportCount: reportCount,
        reasons: reasons,
        latestAt: latestAt,
        reporters: reporters,
        reportIds: reportIds,
        caseId: caseId,
        severity: severity,
        slaDueAt: slaDueAt,
        quarantined: quarantined ?? this.quarantined,
      );
}

/// Sunucunun hesapladığı vaka önemi.
enum ModerationSeverity {
  normal('normal'),
  high('high');

  const ModerationSeverity(this.wire);

  final String wire;

  static ModerationSeverity fromWire(String? wire) =>
      wire == 'high' ? ModerationSeverity.high : ModerationSeverity.normal;
}
