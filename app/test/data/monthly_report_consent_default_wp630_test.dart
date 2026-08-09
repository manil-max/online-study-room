// WP-630 — aylık rapor rızası ÖN İŞARETLİ geliyordu.
//
// `0030` sütunu `default true` ile kurmuş, istemci de iki yerde `?? true`
// yazıyordu. Yani kullanıcı hiçbir şey yapmadan "aylık rapor e-postası
// istiyorum" işaretli başlıyordu. KVKK/GDPR'da ön işaretli onay kutusu geçerli
// rıza sayılmaz.
//
// Bugüne kadar tek bir rapor gönderilmediği için (`send-report` çağrılmıyor ve
// deploy edilmiyor — WP-626) hiçbir `true` bilinçli bir seçimi temsil etmiyor;
// hepsi varsayılanın kendisi. Sunucu tarafı eşi `0125`.
//
// 🔴 İkinci `?? true` daha sinsiydi: sütun okunamadığında (eski satır, kısıtlı
// kolon seçimi, çevrimdışı üretilen yedek profil) rıza VAR sayılıyordu — yani
// kullanıcının hiç vermediği bir izin uyduruluyordu.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';

void main() {
  test('varsayılan yapıcı rızayı VERİLMİŞ saymaz', () {
    final profile = Profile(
      id: 'u1',
      displayName: 'Deneme',
      createdAt: DateTime(2026, 8, 9),
    );
    expect(
      profile.monthlyReportOptIn,
      isFalse,
      reason:
          'Kullanıcı hiçbir şey yapmadan aylık rapor iznine sahip görünüyor: '
          'ön işaretli onay kutusu geçerli rıza değildir.',
    );
  });

  test('sütun YOKSA rıza uydurulmaz', () {
    final profile = Profile.fromMap({
      'id': 'u1',
      'display_name': 'Deneme',
      'created_at': DateTime(2026, 8, 9).toIso8601String(),
    });
    expect(
      profile.monthlyReportOptIn,
      isFalse,
      reason:
          'Sütun okunamadığında rıza VAR sayılıyor: çevrimdışı yedek profil ya '
          'da kısıtlı kolon seçimi izni kendiliğinden açar.',
    );
  });

  test('🔴 sunucu AÇIKÇA true derse rıza korunur', () {
    // Ters iddia. Bu olmadan "her zaman false döndür" çözümü de geçerdi ve o
    // çözüm, kullanıcının bilerek açtığı izni sessizce kapatırdı.
    final profile = Profile.fromMap({
      'id': 'u1',
      'display_name': 'Deneme',
      'created_at': DateTime(2026, 8, 9).toIso8601String(),
      'monthly_report_opt_in': true,
    });
    expect(
      profile.monthlyReportOptIn,
      isTrue,
      reason: 'Kullanıcının bilerek verdiği rıza istemcide siliniyor.',
    );
  });
}
