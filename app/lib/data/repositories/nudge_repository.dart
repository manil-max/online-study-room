import '../models/nudge.dart';
import '../models/nudge_mute.dart';
import '../models/profile.dart';

const Duration kNudgeCooldown = Duration(minutes: 10);
const int kMaxNudgeMessageLength = 120;

class NudgeException implements Exception {
  const NudgeException(this.message);

  final String message;

  @override
  String toString() => message;
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
    throw const NudgeException('Dürtme notu en fazla 120 karakter olabilir.');
  }
  return normalized;
}
