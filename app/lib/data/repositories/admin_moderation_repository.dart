import '../models/moderation_appeal.dart';
import '../models/moderation_case.dart';
import '../models/moderation_sanction.dart';
// `ModerationException` tek tanımdır; kuyruk da aynı hatayı fırlatır.
export 'moderation_repository.dart' show ModerationException;

/// WP-440: Yönetici moderasyon kuyruğunun tek veri kapısı.
///
/// Ekran artık `Supabase.instance.client` ile konuşmaz; tüm okuma/yazma
/// buradan geçer. Yazma yolu **doğrudan tablo UPDATE'i değil**
/// `admin_set_ugc_report_group_status` RPC'sidir: vaka sözleşmesi, yetki ve
/// geçerli durum listesi sunucuda doğrulanır.
///
/// Ajan B'nin `admin_repository.dart` (feedback) dosyasıyla paylaşılmaz.
abstract class AdminModerationRepository {
  /// Hedef başına toplanmış açık/kapalı vakalar, en yenisi başta.
  Future<List<ModerationCase>> fetchQueue();

  /// WP-629: 15 dakikadan uzun süredir `pending` kalmış yaptırımları `failed`
  /// olarak kapatır ve kaç satırın kapandığını döner.
  ///
  /// 🔴 Sunucu tarafı (`admin_reconcile_moderation_sanctions`, `0105:355`)
  /// `0105`ten beri **yazılıydı ama hiçbir yerden çağrılmıyordu**. Sonuç sessiz
  /// bir yarım durumdu: yaptırımın auth adımı geçip kapanış çağrısı düşünce
  /// satır sonsuza kadar `pending` kalıyor, `pending` satır **aktif yaptırım
  /// sayılmadığı** için kullanıcı aslında cezasız geziyor, admin ise cezayı
  /// uyguladığını sanıyordu. Kimse hata görmüyordu — çünkü hata yoktu, iş
  /// yarıda kalmıştı.
  Future<int> reconcileStaleSanctions();

  /// Vakanın tüm raporlarının durumunu tek işlemde değiştirir.
  ///
  /// Etkilenen rapor sayısını döner. WP-441 (`0105`) ile
  /// [ModerationCaseStatus.open] da yazılabilir: yanlışlıkla kapatılan vaka
  /// gerçekten açık duruma döner, `in_review`e sapmaz.
  Future<int> setCaseStatus({
    required ModerationCase moderationCase,
    required ModerationCaseStatus status,
  });

  /// Tek raporun detay/timeline verisi (`admin_ugc_report_detail`).
  Future<ModerationCaseDetail> fetchDetail(String reportId);

  /// WP-441: Basamaklı yaptırımı uygular.
  ///
  /// Çağrı **idempotenttir**: aynı [ModerationSanctionRequest.idempotencyKey]
  /// ile yeniden gönderim ikinci yaptırım açmaz, mevcut kaydı geri verir.
  /// Hedefte zaten aktif bir kısıt varsa çağrı [ModerationException] ile
  /// reddedilir — iki basamak üst üste binmez.
  Future<ModerationSanction> applySanction(ModerationSanctionRequest request);

  /// Yaptırımı geri alır; kısıt aynı anda auth tarafında da kalkar.
  Future<ModerationSanction> revokeSanction({
    required String sanctionId,
    required String reason,
  });

  /// Hedefin yaptırım geçmişi, en yenisi başta.
  Future<List<ModerationSanction>> fetchSanctions(String targetUserId);

  /// Vakayı geri alınabilir karantinaya alır ya da karantinadan çıkarır.
  ///
  /// Karantina içeriği silmez; inceleme bitene kadar üçüncü kişilere kapatır.
  Future<void> setQuarantine({
    required ModerationCase moderationCase,
    required bool quarantined,
    required String reason,
  });

  /// WP-442: İtiraz kuyruğu — açık itirazlar başta.
  ///
  /// [ModerationAppeal.decidable] sunucuda hesaplanır: yaptırımı uygulayan
  /// yönetici kendi kararını denetleyemez.
  Future<List<ModerationAppeal>> fetchAppeals();

  /// İtirazı karara bağlar. Karar **idempotenttir**: kararı verilmiş itiraz
  /// yeniden yazılmaz, `overturned` yaptırımı yalnız bir kez kaldırır.
  Future<ModerationAppeal> decideAppeal({
    required ModerationAppeal appeal,
    required bool overturn,
    required String note,
  });
}

/// Detay sayfasının okuduğu ham kayıt.
class ModerationCaseDetail {
  const ModerationCaseDetail({
    required this.snapshot,
    required this.details,
    required this.contextMessages,
    required this.reportCount,
    required this.sanctionReasons,
  });

  final String snapshot;
  final String? details;
  final List<ModerationContextMessage> contextMessages;
  final int reportCount;
  final List<String> sanctionReasons;
}

class ModerationContextMessage {
  const ModerationContextMessage({
    required this.displayName,
    required this.body,
    required this.isTarget,
  });

  final String displayName;
  final String body;
  final bool isTarget;
}
