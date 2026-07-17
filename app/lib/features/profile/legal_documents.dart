/// WP-111: Yasal metin gövdeleri (TR/EN) — uygulama içi gösterim.
/// Kaynak dosyalar: `docs/legal/*`. Sürüm/tarih burada sabitlenir.
class LegalDocuments {
  const LegalDocuments._();

  static const policyVersion = '2026-07-17';
  static const communityVersion = '1';

  /// Canlı HTTPS tabanı (GitHub Pages vb.). Boşsa yalnız uygulama içi metin.
  static const legalBaseUrl = String.fromEnvironment(
    'LEGAL_BASE_URL',
    defaultValue: '',
  );

  static bool get hasPublicLegalSite => legalBaseUrl.trim().isNotEmpty;

  static String? publicUrl(String path) {
    if (!hasPublicLegalSite) return null;
    final base = legalBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/$path';
  }

  static String privacy({required bool turkish}) =>
      turkish ? _privacyTr : _privacyEn;

  static String terms({required bool turkish}) =>
      turkish ? _termsTr : _termsEn;

  static String community({required bool turkish}) =>
      turkish ? _communityTr : _communityEn;

  static const _privacyTr = '''
Gizlilik Politikası — Odak Kampı
Sürüm: $policyVersion

1) Toplanan veriler
Hesap (e-posta), profil (ad, avatar, hayvan), çalışma oturumları, grup/sohbet/dürtme, geri bildirim, cihaz tercihleri. İsteğe bağlı telemetri: çökme türü ve senkron sayaçları (Sentry); e-posta veya oturum token’ı gönderilmez.

2) İşleyiciler
Supabase (Auth, veritabanı, depolama). Sentry yalnızca derlemede açık ve Ayarlar’da telemetri açıksa. Play dışı sideload güncellemeleri GitHub Releases kullanabilir.

3) Saklama ve silme
Hesap silme isteği → geri alma penceresi → planlı kalıcı silme. Ayrıntı: Veri saklama takvimi. Pipeline tamamlanana kadar “istek + geri alma + planlı silme” modeli geçerlidir.

4) Çocuklar
Uygulama bilerek 13 yaş altı çocuklara yönelik değildir.

5) Haklar
Erişim, düzeltme, silme talebi; telemetriyi Ayarlar’dan kapatma. İletişim: uygulama içi geri bildirim veya mağaza geliştirici e-postası.

6) Değişiklikler
Bu sürüm/tarih güncellenir; yasal merkezde yeni sürüm görünür.
''';

  static const _privacyEn = '''
Privacy Policy — Odak Kampı
Version: $policyVersion

1) Data we process
Account (email), profile (name, avatar, animal), study sessions, group/chat/nudges, feedback, device preferences. Optional telemetry: crash type and sync counters (Sentry); no email or session tokens.

2) Processors
Supabase (Auth, database, storage). Sentry only when build-enabled and telemetry is on in Settings. Non-Play sideload updates may use GitHub Releases.

3) Retention & deletion
Deletion request → cooling-off window → scheduled hard delete. See retention schedule. Until the full pipeline ships, request + grace + planned purge applies.

4) Children
Not directed at children under 13.

5) Rights
Access, correction, deletion requests; turn off telemetry in Settings. Contact: in-app feedback or store developer email.

6) Changes
Version/date updates appear in the legal center.
''';

  static const _termsTr = '''
Kullanım Koşulları — Odak Kampı
Sürüm: $policyVersion

1. Hizmet çalışma takibi, sınıf, istatistik ve motivasyon amaçlıdır.
2. Hesap güvenliği kullanıcıya aittir.
3. Yasa dışı, taciz, spam ve izinsiz veri paylaşımı yasaktır (Topluluk Kuralları).
4. Kullanıcı içeriğinden (sohbet, grup adı, profil) kullanıcı sorumludur.
5. Uygulama hakları saklıdır.
6. Hizmet “olduğu gibi” sunulur; yasal izin verilen ölçüde sorumluluk sınırlıdır.
7. Aykırılıkta erişim askıya alınabilir.
8. Koşullar güncellenebilir.
9. İletişim: geri bildirim / mağaza e-postası.
''';

  static const _termsEn = '''
Terms of Use — Odak Kampı
Version: $policyVersion

1. Service for study tracking, classes, stats, and motivation.
2. You must secure your account.
3. No illegal content, harassment, spam, or unauthorized data sharing (Community Guidelines).
4. You are responsible for user content (chat, group names, profile).
5. App IP reserved.
6. Service “as is”; liability limited as permitted by law.
7. Access may be suspended for violations.
8. Terms may update.
9. Contact: feedback / store email.
''';

  static const _communityTr = '''
Topluluk Kuralları — Odak Kampı
Sürüm: $communityVersion · $policyVersion

Yasak: nefret, taciz, tehdit, yasa dışı içerik, spam, dolandırıcılık, kimlik taklidi, özel veri sızdırma, platforma saldırı.

Beklenen: saygı, çalışma odaklı sınıf, güvenli davet kodu yönetimi.

Raporlama/engelleme uygulama içinden (etkinleştirildikçe). Acil durumda yerel yetkililer.

Yaptırım: uyarı, içerik gizleme, askı, hesap sonlandırma. İtiraz: geri bildirim.
''';

  static const _communityEn = '''
Community Guidelines — Odak Kampı
Version: $communityVersion · $policyVersion

Prohibited: hate, harassment, threats, illegal content, spam, fraud, impersonation, leaking private data, attacking the platform.

Expected: respect, study-focused classes, safe invite codes.

Report/block in-app when enabled. Emergencies: local authorities.

Enforcement: warning, hide content, suspension, termination. Appeal via feedback.
''';
}
