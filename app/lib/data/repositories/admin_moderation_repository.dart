import '../models/moderation_case.dart';
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

  /// Vakanın tüm raporlarının durumunu tek işlemde değiştirir.
  ///
  /// Etkilenen rapor sayısını döner. [ModerationCaseStatus.open] sunucuda
  /// yazılabilir değildir; çağrı [ModerationException] ile reddedilir.
  Future<int> setCaseStatus({
    required ModerationCase moderationCase,
    required ModerationCaseStatus status,
  });

  /// Tek raporun detay/timeline verisi (`admin_ugc_report_detail`).
  Future<ModerationCaseDetail> fetchDetail(String reportId);
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
