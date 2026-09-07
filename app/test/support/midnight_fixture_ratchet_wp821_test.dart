// WP-821 — GECE YARISI FİKSTÜR CIRCIRI.
//
// 🔴 Ölçülmüş olay, 2026-09-08 saat 00:16. Tam kapı üç testte birden kırmızı
// döndü:
//
//   * `android_widgets/published_widget_data_wp707_test.dart` — günlük hedef
//     `%75` yerine `%0`
//   * `android_widgets/stats_streak_wp707_test.dart` — aynı veri
//   * `home/first_run_empty_states_wp799_test.dart` — kaydı olan kullanıcıya
//     "Bugün henüz çalışma kaydın yok" cümlesi
//
// Sebep bir regresyon **değildi**: fikstürler oturumu `DateTime.now()`dan
// geriye sayarak kuruyordu. Gece 00:16'da `now - 45dk` = dün 23:31, yani
// oturum bugüne düşmüyor, bugünün toplamı 0 çıkıyor. Aynı testler saat 12'de
// yeşil geçer.
//
// Maliyeti gerçek: kırmızıyı önce "benim değişikliğim bozdu" sanıp ayrı bir
// çalışma ağacı kurup ölçmeye kalktım. Doğru cevabı `date` komutu verdi.
//
// `agoWithinIstanbulToday` (WP-565) tam bunun için yazılmıştı ve o üç dosya
// onu kullanmıyordu. Bu test, aynı desenin **yayılmasını** engeller.
//
// 🔴 Neden yasak değil de CIRCIR: aşağıdaki altı dosya bugün bu deseni
// kullanıyor ve **kırmızı değil** — çünkü hiçbiri "bugünün toplamı" üzerine
// iddia kurmuyor. Onları zorla değiştirmek, ölçülmemiş bir kural uğruna
// çalışan testleri elle geçirmek olurdu (0140'ın dersi: çağrılmıyor olmak tek
// başına kaldırma gerekçesi değildir). Yeni bir dosyanın listeye girmesi ise
// bilinçli bir karar olmalı: ya günü sabitle, ya `agoWithinIstanbulToday`
// kullan, ya da bu listeye adını ve gerekçesini yaz.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Oturum fikstürünü canlı saatten türeten, bugün **tolere edilen** dosyalar.
///
/// Her satır bir borçtur; listeye ekleme yapmak gerekçe ister.
const Map<String, String> _tolerated = {
  'test/core/stats/achievement_engine_test.dart':
      'Başarım motoru gün SINIRLARINI değil aralık toplamlarını ölçer.',
  'test/data/session_write_ahead_wp613_test.dart':
      'Yazma-önce kuyruğu günle ilgilenmez; 25 dk sadece bir süre.',
  'test/features/desktop_wp683_midband_test.dart':
      'Düzen (orta bant) ölçülür; hangi güne düştüğü iddiaya girmez.',
  'test/features/profile/data_export_test.dart':
      'Dışa aktarım satır SAYISINI ölçer, bugünün toplamını değil.',
  'test/features/stats/personal_stats_enrichment_test.dart':
      'Çok günlü seri üretir; tek bir günün kayması iddiayı değiştirmez.',
  'test/features/stats/stats_desktop_layout_wp673_test.dart':
      'Masaüstü yerleşimi ölçülür; gün anahtarı iddiaya girmez.',
};

/// `start: now.subtract(...)` / `start: end.subtract(...)` /
/// `start: DateTime.now().subtract(...)`
final _liveClockFixture = RegExp(
  r'start:\s*(now|end|DateTime\.now\(\))\.subtract',
);

/// Bu dosyanın KENDİ adı.
///
/// 🔴 İlk hâli kendini yakaladı: aranan deseni tarif eden `RegExp` metni de
/// desene uyuyor. Test, ölçmek istediği şeyi değil KENDİ METNİNİ ölçüyordu —
/// aynı tuzak bugün WP-820'de de yaşandı. Kendini dışarıda bırakmak şart.
const String _selfPath =
    'test/support/midnight_fixture_ratchet_wp821_test.dart';

List<String> _testFiles() => Directory('test')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('_test.dart'))
    .map((f) => f.path.replaceAll(r'\', '/'))
    .where((p) => !p.endsWith(_selfPath))
    .toList();

void main() {
  test('🔴 canli saatten turetilen oturum fiksturu YAYILMAZ', () {
    final offenders = <String>[];
    for (final path in _testFiles()) {
      if (!_liveClockFixture.hasMatch(File(path).readAsStringSync())) continue;
      final rel = path.substring(path.indexOf('test/'));
      if (!_tolerated.containsKey(rel)) offenders.add(rel);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosyalar oturumu canli saatten geriye sayarak kuruyor:\n'
          '${offenders.join('\n')}\n\n'
          'Gece 00:00 ile geri sayilan sure kadar sonrasi arasinda oturum '
          'DUNE duser; "bugunun toplami" uzerine iddia kuran her test o '
          'saatlerde kirmizi doner ve sebebi bir regresyon sanilir.\n\n'
          'Cozum siralamasi:\n'
          '  1. Gunu SABITLE (DateTime(2026, 9, 8, 12)) -- en saglami.\n'
          '  2. `agoWithinIstanbulToday` kullan (test/support/istanbul_fixture).\n'
          '  3. Testin gune BAKMADIGINDAN eminsen `_tolerated` listesine adini '
          've tek cumlelik gerekceni yaz.',
    );
  });

  test('tolere edilenler listesi BAYATLAMAZ', () {
    // Listedeki bir dosya duzeltilir ya da silinirse satiri da gitmeli;
    // yoksa liste zamanla anlamsiz bir muafiyet yiginina doner.
    for (final entry in _tolerated.entries) {
      final file = File(entry.key);
      expect(
        file.existsSync(),
        isTrue,
        reason: '${entry.key} artik yok; `_tolerated` satirini da sil.',
      );
      expect(
        _liveClockFixture.hasMatch(file.readAsStringSync()),
        isTrue,
        reason:
            '${entry.key} artik canli saat kullanmiyor -- duzeltilmis. '
            'Muafiyet satirini sil, yoksa liste gercegi anlatmaz.',
      );
      expect(
        entry.value.trim(),
        isNotEmpty,
        reason: '${entry.key} icin gerekce yazilmamis.',
      );
    }
  });
}
