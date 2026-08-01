import '../models/nudge.dart';
import '../models/nudge_mute.dart';
import '../models/profile.dart';

/// WP-476: aynı kişiye iki dürtme arasındaki bekleme (sunucu `send_nudge`
/// ile birebir; migration 0116).
///
/// 10 dakikaydı ve kullanıcılar "görev için 10 dk'da bir dürtüyorlar" dedi —
/// pencere spam'in tam boyuydu, yani davranışı sistem üretiyordu.
const Duration kNudgeCooldown = Duration(minutes: 20);

const int kMaxNudgeMessageLength = 120;

/// WP-477: dürtme hatalarının **makine okunur** karşılığı.
///
/// Metin burada üretilmez: repository katmanı `BuildContext`/`AppLocalizations`
/// alamaz (katman ihlali olur), bu yüzden hazır cümle döndürmek İngilizce
/// arayüzde Türkçe metin çıkmasına yol açıyordu. Çeviriyi sunum katmanı
/// `NudgeErrorCode` → l10n eşlemesiyle yapar (`core/l10n/nudge_error_text.dart`).
enum NudgeErrorCode {
  /// Aynı kişiye [kNudgeCooldown] dolmadan ikinci dürtme.
  cooldown,

  /// Alıcı şu an çalışıyor; odağı bölünmesin diye sunucu reddetti.
  recipientIsStudying,
  cannotNudgeSelf,
  notGroupMember,
  blocked,
  messageTooLong,
  cannotMuteSelf,

  /// Sınıflandırılamayan gönderim hatası.
  sendFailed,
  markReadFailed,
  mutesUnavailable,
  muteSaveFailed,
}

class NudgeException implements Exception {
  const NudgeException(this.code, {this.detail});

  final NudgeErrorCode code;

  /// Sunucudan gelen ham teknik ayrıntı. Yalnız günlük/hata ayıklama içindir;
  /// kullanıcıya gösterilen metin koddan üretilir.
  final String? detail;

  @override
  String toString() => detail == null
      ? 'NudgeException(${code.name})'
      : 'NudgeException(${code.name}): $detail';
}

abstract class NudgeRepository {
  Stream<List<Nudge>> watchReceivedNudges(String userId);

  /// Dürtme gönderir.
  ///
  /// WP-444: Alıcı bu göndereni susturmuşsa çağrı **başarılı görünür** ama
  /// sunucuda dürtme satırı, realtime olayı ve push outbox kaydı oluşmaz.
  /// Gönderen tercihi okuyamaz; hata mesajı, gecikme ve cooldown davranışı
  /// susturulmamış alıcıyla aynıdır (yan kanal yok).
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  });

  Future<void> markRead(String nudgeId);

  /// WP-444: çağıranın dürtmesini susturduğu kişi kimlikleri.
  ///
  /// Yalnız **kendi** tercihini döndürür; kimse başkasının susturma listesini
  /// okuyamaz.
  Future<List<String>> listMutedNudgeSenderIds();

  /// WP-444: yönetim ekranı için ad/avatar ile susturma listesi.
  Future<List<NudgeMute>> fetchNudgeMutes();

  /// WP-444: [userId] kişisinin dürtmelerini sustur. Engelleme **değildir**;
  /// mesaj, profil ve grup erişimi etkilenmez. Aynı kişi için tekrar çağrılması
  /// güvenlidir (idempotent).
  Future<void> muteNudgesFrom(String userId);

  /// WP-444: susturmayı geri al (idempotent).
  Future<void> unmuteNudgesFrom(String userId);
}

String? normalizeNudgeMessage(String? message) {
  final normalized = message?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > kMaxNudgeMessageLength) {
    throw const NudgeException(NudgeErrorCode.messageTooLong);
  }
  return normalized;
}
