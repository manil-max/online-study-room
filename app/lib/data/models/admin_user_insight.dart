import 'package:flutter/foundation.dart';

/// WP-775 — bir kullanıcının **moderasyon dosyası**: tek çağrıda oranlar,
/// hesap bilgisi ve kullanım.
///
/// 🔴 Sahibin şartı: *"oradan olaya dahil iki kişinin de geçmişini göreyim,
/// çok şikâyet ettiklerini / şikâyet edildiklerini ve en üstte de oranları."*
///
/// **Neden ham sayı yetmiyor.** "7 kez şikâyet edildi" tek başına hiçbir şey
/// söylemez. Anlamı veren şey kaçının **haklı çıktığı**:
///
///   * 12 şikâyet almış ama hiçbiri haklı çıkmamış biri, büyük olasılıkla
///     hedef alınıyordur — ceza değil koruma gerekir.
///   * 3 şikâyet almış ve üçü de haklı çıkmış biri gerçek sorundur.
///   * Çok şikâyet edip hiçbiri tutmayan biri, şikâyet mekanizmasını kötüye
///     kullanıyordur.
///
/// Bu yüzden her iki yön de **ikişer sayı** taşır (toplam + haklı çıkan) ve
/// oranlar burada, saf olarak hesaplanır — ekranda değil, testte ölçülebilsin
/// diye.
///
/// 🔴 Sunucuda `admin_reporter_abuse_score(uuid)` **zaten vardı** (`0105`) ve
/// bugüne kadar Dart'tan **hiç çağrılmadı** — deponun tekrar eden kusuru
/// ("bitmiş arka uç, bağlanmamış ön uç"). Şikâyet eden yönü oradan gelir;
/// eksik olan, şikâyet **edilen** yönüdür.
@immutable
class AdminUserInsight {
  const AdminUserInsight({
    required this.userId,
    required this.reportsAgainst,
    required this.reportsAgainstUpheld,
    required this.reportsFiled,
    required this.reportsFiledUpheld,
    this.displayName,
    this.email,
    this.accountCreatedAt,
    this.lastSeenAt,
    this.totalStudySeconds = 0,
    this.currentStreakDays = 0,
    this.groupNames = const [],
    this.isDeleted = false,
  });

  final String userId;

  /// Hakkında açılan toplam şikâyet.
  final int reportsAgainst;

  /// Bunlardan **haklı bulunanlar** (vaka `resolved` kapandı).
  final int reportsAgainstUpheld;

  /// Kendi açtığı toplam şikâyet.
  final int reportsFiled;

  /// Bunlardan haklı bulunanlar.
  final int reportsFiledUpheld;

  final String? displayName;
  final String? email;

  /// Hesabın açılış anı. Şikâyetin ağırlığı hesabın yaşına bağlıdır: dün
  /// açılmış bir hesabın şikâyeti ile bir yıllık kullanıcınınki aynı değildir.
  final DateTime? accountCreatedAt;
  final DateTime? lastSeenAt;

  /// Uygulamaya özgü bağlam: gerçekten çalışan biri mi, yoksa yalnız sohbet
  /// için mi giriyor?
  final int totalStudySeconds;
  final int currentStreakDays;
  final List<String> groupNames;

  final bool isDeleted;

  /// Hakkındaki şikâyetlerin kaçı haklı çıktı — `0..1`, hiç şikâyet yoksa
  /// `null`.
  ///
  /// 🔴 `null` ile `0` **ayrı şeylerdir**: "hiç şikâyet edilmemiş" ile "beş kez
  /// şikâyet edilmiş, hiçbiri tutmamış" aynı kullanıcı değildir. Sıfıra
  /// yuvarlamak ikincisini masum, birincisini de ölçülmüş gibi gösterirdi.
  double? get upheldAgainstRatio =>
      reportsAgainst <= 0 ? null : reportsAgainstUpheld / reportsAgainst;

  /// Açtığı şikâyetlerin kaçı haklı çıktı — `0..1`, hiç açmamışsa `null`.
  double? get upheldFiledRatio =>
      reportsFiled <= 0 ? null : reportsFiledUpheld / reportsFiled;

  /// Hesap yaşı (gün). Açılış bilinmiyorsa `null`.
  ///
  /// Takvim değil **süre** sorulduğu için `difference` doğru araçtır; yaz saati
  /// geçişi burada bir hata üretmez (bkz. gün anahtarları için `dayOf`).
  int? accountAgeDays({DateTime? now}) {
    final created = accountCreatedAt;
    if (created == null) return null;
    return (now ?? DateTime.now()).difference(created).inDays;
  }

  /// Şikâyet **edilen** tarafta uyarı işareti.
  ///
  /// Eşik sunucudaki `admin_reporter_abuse_score` ile aynı biçimdedir (üç olay
  /// + yarıdan fazlası): tek bir haklı şikâyet insanı damgalamaz, tekrar eden
  /// ve çoğunlukla haklı çıkan bir örüntü damgalar.
  ///
  /// 🔴 Payda **karara bağlanmış** değil **toplam** şikâyettir; henüz `open`
  /// veya `in_review` duran şikâyetler de içindedir. Bu, işareti temkinli
  /// yapar: bekleyen şikâyeti çok olan biri eşiği geçemez, yani işaret
  /// GEÇ yanar. Yanlış yönde hata etmesi bilinçlidir — bir insanı erken
  /// damgalamaktansa geç damgalamak yeğdir.
  bool get flaggedAsOffender =>
      reportsAgainstUpheld >= 3 && reportsAgainstUpheld * 2 >= reportsAgainst;

  factory AdminUserInsight.fromWire(Map<String, dynamic> map) {
    int asInt(Object? v) => switch (v) {
      final int i => i,
      final num n => n.toInt(),
      final String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
    DateTime? asDate(Object? v) => switch (v) {
      final String s => DateTime.tryParse(s)?.toLocal(),
      final DateTime d => d,
      _ => null,
    };
    return AdminUserInsight(
      userId: (map['user_id'] ?? '').toString(),
      reportsAgainst: asInt(map['reports_against']),
      reportsAgainstUpheld: asInt(map['reports_against_upheld']),
      reportsFiled: asInt(map['reports_filed']),
      reportsFiledUpheld: asInt(map['reports_filed_upheld']),
      displayName: map['display_name'] as String?,
      email: map['email'] as String?,
      accountCreatedAt: asDate(map['account_created_at']),
      lastSeenAt: asDate(map['last_seen_at']),
      totalStudySeconds: asInt(map['total_study_seconds']),
      currentStreakDays: asInt(map['current_streak_days']),
      groupNames: [
        for (final raw in (map['group_names'] as List? ?? const []))
          raw.toString(),
      ],
      isDeleted: map['is_deleted'] == true,
    );
  }
}
