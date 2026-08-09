// WP-624 — açılışın ilk saniyelerinde profil yazmaları SESSİZCE düşüyordu.
//
// Altı yazma metodu şöyle başlıyordu:
//
//     final cur = _current;
//     if (cur == null) return;      // <-- sessizce başarıyla döner
//
// `_current` ancak ilk `_profileFor(...)` bitince dolar ve **çevrimdışı
// açılışta o tur ~20 saniye sürüyor** (WP-603'te ölçüldü). Yani metroda
// uygulamayı açan kullanıcının ilk yirmi saniyedeki her ayar değişikliği
// (günlük hedef, ad, hayvan, ünvan, aylık rapor, avatar) hiçbir şey yapmadan
// "başarılı" dönüyordu.
//
// 🔴 WP-610/WP-619 bu yolu DAHA KÖTÜ hâle getirmişti: o WP'ler hata dallarını
// düzeltip **başarıda onay göstermeye** başladı, ama bu yol hata atmıyor —
// sessizce dönüyor. Sonuç: ekranda "kaydedildi", diskte hiçbir şey.
// **Sessiz başarısızlıktan beteri, YALAN başarıdır.**
//
// Çözüm: kimliği oturumdan al. Profil satırı henüz okunmamış olabilir ama
// kullanıcı kimliği açılıştan beri bellekte.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/data/repositories/supabase/supabase_auth_repository.dart',
  ).readAsStringSync();

  /// Yorum satırları çıkarılır: kusurun kendisi bu dosyada YORUMLA anlatılıyor
  /// ve onları ihlal saymak testi yanlış kırmızıya düşürürdü.
  final code = source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//') && !line.trimLeft().startsWith('///'))
      .join('\n');

  test('hiçbir yazma yolu artık SESSİZCE dönmüyor', () {
    expect(
      code,
      isNot(contains('if (cur == null) return;')),
      reason:
          'Yazma yolu profil yüklenmeden sessizce başarıyla dönüyor: kullanıcı '
          '"kaydedildi" onayını görüyor, hiçbir şey kaydedilmiyor.',
    );
  });

  test('kimlik OTURUMDAN da alınabiliyor (yalnız _current değil)', () {
    expect(
      code,
      contains('_current?.id ?? _client.auth.currentUser?.id'),
      reason:
          'Kimlik yalnız yüklenmiş profilden alınıyor: profil gelene kadar '
          'yazma yapılamaz.',
    );
  });

  test('oturum GERÇEKTEN yoksa sessiz kalınmaz, hata atılır', () {
    // Ters iddia: "her durumda devam et" çözümü de yanlış olurdu — oturumsuz
    // yazma denemesi sessizce yutulmamalı, görünür bir hata olmalı.
    final helperStart = code.indexOf('String _writeTargetId()');
    expect(helperStart, isNonNegative, reason: 'Yardımcı bulunamadı.');
    final helperEnd = code.indexOf('\n  }', helperStart);
    expect(
      code.substring(helperStart, helperEnd),
      contains('throw const AuthException'),
      reason: 'Oturumsuz yazma sessizce yutuluyor.',
    );
  });

  test('altı yazma yolunun hepsi hedef kimliği KULLANIYOR', () {
    // Kablo iddiası: yardımcıyı yazıp çağırmamak bu depoda tekrarlayan hata.
    final calls = 'final targetId = _writeTargetId();'.allMatches(code).length;
    expect(
      calls,
      6,
      reason:
          'Beklenen altı yazma yolunun hepsi hedef kimliği çözmüyor '
          '(bulunan: $calls). Kalan yol hâlâ sessizce düşer.',
    );
  });
}
