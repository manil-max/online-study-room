// WP-621 — WP-609'un açık bıraktığı yarısı: bozuk profil "gerçek" diye
// önbelleğe yazılıyordu.
//
// WP-609 ağ düşünce önbellekteki profili döndürmeyi sağladı — okuma tarafı.
// Yazma tarafı açıktı: `auth_providers` akıştan geçen **her** profili "bir
// sonraki çevrimdışı açılışın yedeği" diye diske yazıyordu. Oysa o akıştan
// çevrimdışı üretilen yedek profil de geçiyor ve o profil yalnız `displayName`
// taşıyor; `dailyGoalMinutes` **varsayılana** düşmüş oluyor.
//
// Zinciri kapatınca kalıcı bozulma çıkıyordu:
//   1. kullanıcının ilk açılışı çevrimdışı → eksik yedek profil üretilir,
//   2. o eksik profil "son gerçek profil" olarak diske yazılır,
//   3. WP-609 sonraki her çevrimdışı açılışta onu okur.
// Yani düzeltmenin kendisi bozuk veriyi sabitliyordu.
//
// 🔴 Kaynak ayrımını **depo** yapmak zorunda: satırın sunucudan geldiğini
// yalnız o bilir. Sağlayıcı katmanı iki profili birbirinden ayıramaz — hata da
// tam bu yüzden doğmuştu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('önbellek yazımı YALNIZ sunucu satırında tetiklenir (kaynak sözleşmesi)', () {
    final repo = File(
      'lib/data/repositories/supabase/supabase_auth_repository.dart',
    ).readAsStringSync();

    // Geri çağırım gerçek satırın döndüğü dalda olmalı.
    final rowBranch = repo.indexOf('if (row != null) {');
    expect(rowBranch, isNonNegative, reason: 'Sunucu satırı dalı bulunamadı.');
    final branchBody = repo.substring(rowBranch, rowBranch + 320);
    expect(
      branchBody,
      contains('_onServerProfile('),
      reason:
          'Sunucudan gelen profil önbelleğe bildirilmiyor: çevrimdışı açılış '
          'eski/eksik profili okumaya devam eder.',
    );

    // 🔴 Ters iddia: yedek yolu ASLA çağırmamalı. Bu olmadan "her yerde çağır"
    // çözümü de geçerdi ve hatanın kendisi geri gelirdi.
    final fallbackStart = repo.indexOf('Profile offlineProfileFallback(');
    expect(fallbackStart, isNonNegative);
    final fallbackEnd = repo.indexOf('\n}', fallbackStart);
    expect(
      repo.substring(fallbackStart, fallbackEnd),
      isNot(contains('_onServerProfile')),
      reason:
          'Yedek profil de sunucu profili gibi önbelleğe yazılıyor: günlük '
          'hedefi varsayılana düşmüş profil KALICILAŞIR.',
    );
  });

  test('sağlayıcı, koşulsuz önbellek yazımını artık YAPMIYOR', () {
    final providers = File(
      'lib/data/providers/auth_providers.dart',
    ).readAsStringSync();

    final code = providers
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    // Kabloyu bağladığını göster…
    expect(
      code,
      contains('onServerProfile:'),
      reason: 'Depo geri çağırımı sağlayıcıda bağlanmamış.',
    );

    // …ve eski koşulsuz yazımın geri dönmediğini.
    final remoteStart = code.indexOf('onRemoteProfile:');
    expect(remoteStart, isNonNegative);
    final remoteEnd = code.indexOf('onOfflineOpen:', remoteStart);
    expect(remoteEnd, greaterThan(remoteStart));
    expect(
      code.substring(remoteStart, remoteEnd),
      isNot(contains('saveProfile(')),
      reason:
          'Akıştan geçen HER profil yine önbelleğe yazılıyor: çevrimdışı '
          'üretilen eksik yedek "son gerçek profil" sayılır.',
    );
  });
}
