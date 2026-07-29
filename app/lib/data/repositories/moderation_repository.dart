import 'dart:typed_data';

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
}

class ModerationException implements Exception {
  const ModerationException(this.message);
  final String message;
  @override
  String toString() => message;
}
