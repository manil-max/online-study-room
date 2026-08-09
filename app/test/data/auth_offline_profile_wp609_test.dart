// WP-609 — çevrimdışı profil yedeği SESSİZ BİR VERİ KAYBIYDI.
//
// WP-603 çevrimdışı açılışı düzeltti: internet yokken cihazdaki oturumla
// giriliyor ve **önbellekteki son gerçek profil** gösteriliyor — doğru ad,
// doğru günlük hedef, doğru avatar.
//
// 🔴 Ama arka planda dönen ağ turu ~20 saniye sonra başarısız olunca depo
// yedek olarak `user_metadata`dan bir profil kuruyordu. O profil **yalnız
// `displayName`** taşır; `dailyGoalMinutes` ve avatar **varsayılana** düşer.
// Kullanıcının gördüğü sıra:
//
//   1. metroda uygulamayı açıyor, günlük hedefini DOĞRU görüyor (WP-603),
//   2. ~20 saniye sonra hedef sessizce VARSAYILANA dönüyor,
//   3. hedefe bağlı ne varsa (ilerleme halkası, "hedefi tuttun mu", seri
//      tamamlama) o andan itibaren yanlış çalışıyor.
//
// Veri silinmediği için gözle fark edilmesi zor; tam da bu yüzden testle
// bağlanır.
//
// 🔴 Bu dosya AĞA ÇIKMAZ ve saate bakmaz: ölçülen şey saf karar.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';

const _userId = 'user-1';
final _createdAt = DateTime.utc(2026, 1, 1);

Profile _cached({String id = _userId, int goal = 300}) => Profile(
  id: id,
  displayName: 'Muhlis',
  createdAt: _createdAt,
  dailyGoalMinutes: goal,
);

void main() {
  test('ASIL HATA: yedek, günlük hedefi VARSAYILANA düşürmez', () {
    final cached = _cached();
    final result = offlineProfileFallback(
      userId: _userId,
      metadataDisplayName: 'Muhlis',
      createdAt: _createdAt,
      cached: cached,
    );

    expect(
      result.dailyGoalMinutes,
      cached.dailyGoalMinutes,
      reason:
          'Çevrimdışı ağ turu başarısız olunca günlük hedef varsayılana '
          'kayıyor: kullanıcı hedefini önce doğru görüp sonra sessizce '
          'kaybediyor.',
    );
    expect(
      result.dailyGoalMinutes,
      isNot(kDefaultDailyGoalMinutes),
      reason: 'Kurgu anlamsız olurdu: önbellekteki hedef varsayılanla aynı.',
    );
  });

  test('önbellek YOKKEN metadata yolu korunur (ilk açılış bozulmadı)', () {
    final result = offlineProfileFallback(
      userId: _userId,
      metadataDisplayName: 'Yeni Kullanıcı',
      createdAt: _createdAt,
      cached: null,
    );

    expect(result.id, _userId);
    expect(result.displayName, 'Yeni Kullanıcı');
    expect(
      result.dailyGoalMinutes,
      kDefaultDailyGoalMinutes,
      reason:
          'Hiç profil görülmemişken varsayılan doğrudur; bu dalın bozulmaması '
          'gerekiyor.',
    );
  });

  test('BAŞKA kullanıcının önbelleği KULLANILMAZ', () {
    // Hesap değiştirilen cihazda başkasının hedefini göstermek, düzeltmeye
    // çalıştığımız hatadan daha kötü olurdu.
    final result = offlineProfileFallback(
      userId: _userId,
      metadataDisplayName: 'Muhlis',
      createdAt: _createdAt,
      cached: _cached(id: 'baska-kullanici', goal: 999),
    );

    expect(result.id, _userId);
    expect(result.dailyGoalMinutes, kDefaultDailyGoalMinutes);
  });

  test('sağlayıcı okuyucuyu GERÇEKTEN bağlıyor (kaynak sözleşmesi)', () {
    // Saf karar doğru olsa bile sağlayıcı okuyucuyu vermezse `cached` her
    // zaman null gelir ve hata aynen sürer — "yazıldı ama çağıran yok".
    final source = File(
      'lib/data/providers/auth_providers.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('cachedProfile:'),
      reason: 'authRepositoryProvider önbellek okuyucusunu vermiyor.',
    );
    expect(
      source,
      contains('readProfile()'),
      reason: 'Okuyucu önbelleğe bağlı değil.',
    );
  });
}
