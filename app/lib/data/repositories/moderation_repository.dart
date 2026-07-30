import 'dart:typed_data';

import '../models/moderation_appeal.dart';
import '../models/moderation_sanction.dart';
import '../models/profile.dart';
import '../models/report_target.dart';

/// WP-116 / WP-129: UGC rapor / engel soyutlaması.
abstract class ModerationRepository {
  Future<void> acceptCommunityTerms(String version);

  Future<void> blockUser(String userId);

  Future<void> unblockUser(String userId);

  Future<List<String>> listBlockedUserIds();

  /// Engellenen kullanıcılar ekranı: id → profil özeti.
  /// Okunamayan id'ler için minimal [Profile] (maskeli ad) döner.
  Future<List<Profile>> fetchBlockedProfiles();

  /// WP-439: hedef artık serbest `(type, id)` metin çifti değil, doğrulanmış
  /// [ReportTarget] sözleşmesidir — yanlış tür/kimlik çifti ağa çıkamaz.
  ///
  /// WP-423: [attachmentBytes] tek ve **opsiyonel** foto ekidir. Yükleme
  /// başarısız olursa şikâyet yine de gönderilir; ek sessizce düşer.
  Future<void> reportUgc({
    required ReportTarget target,
    required String reason,
    String? details,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  });

  /// WP-442: Kullanıcının kendisi hakkındaki yaptırımlar — nedeni ve süresi.
  ///
  /// Kullanıcı yalnız kendi satırlarını görür; kimin şikâyet ettiği bu yolda
  /// hiç dönmez.
  Future<List<ModerationSanction>> fetchMySanctions();

  /// Yaptırıma itiraz eder. Aynı yaptırıma ikinci itiraz açılmaz; tekrar
  /// gönderim mevcut itirazı döner.
  Future<ModerationAppeal> submitAppeal({
    required String sanctionId,
    required String statement,
  });

  /// Kullanıcının kendi itirazları.
  Future<List<ModerationAppeal>> fetchMyAppeals();
}

/// İtiraz metni sunucuda 10–2000 karakter arası olmak zorunda; istemci aynı
/// sınırı uygular ki kullanıcı boş bir gönderimin ardından ham SQL hatası
/// görmesin.
const int kAppealMinLength = 10;
const int kAppealMaxLength = 2000;

class ModerationException implements Exception {
  const ModerationException(this.message);
  final String message;
  @override
  String toString() => message;
}
