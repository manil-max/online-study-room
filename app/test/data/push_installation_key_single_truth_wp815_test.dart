// WP-815 — kurulum kimliginin `SharedPreferences` anahtari TEK yerde yasar.
//
// 🔴 OLCULEN KUSUR. `'push_installation_id_v1'` dizesi iki yerde yaziliydi:
//
//   * `data/providers/push_notification_providers.dart` — `_pushInstallationIdKey`
//     adiyla, **private** (alt cizgi) olarak. Kimligi bu dosya yazar.
//   * `data/repositories/supabase/supabase_auth_repository.dart` — `signOut`
//     icinde ELLE yazilmis bir dize olarak. Private sabiti import edemedigi
//     icin kopyalanmisti.
//
// Bugun ikisi ayni. Ama biri degisirse — diyelim `_v2` — cikis yolu SESSIZCE
// bozulur: `prefs.getString(...)` `null` doner, `unregister_push_device` hic
// cagrilmaz, cihaz kaydi sunucuda kalir ve **eski hesabin bildirimleri o
// cihaza dusmeye devam eder**. Uc sey birden bu hatayi gorunmez yapiyordu:
// derleyici uyarmaz (iki gecerli dize), `signOut` push temizligini
// `try/catch (_) {}` ile yutar (bilerek: cikis engellenmemeli), ve hicbir test
// iki dizeyi karsilastirmiyordu.
//
// Bu dosyanin olctugu sey davranis degil **YAPI**: dizenin `app/lib` icinde
// KAC KEZ gectigi. Davranis testi burada daha zayif olurdu, cunku iki kopya
// esitken davranis dogrudur; kusur ancak biri degistiginde dogar ve o ani
// yakalayan tek sey sayimdir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/repositories/push_registration_repository.dart';

/// `app/lib` altindaki tum Dart kaynaklari.
List<File> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('anahtar dizesi `lib/` icinde YALNIZ BIR KEZ yazilir', () {
    const literal = "'push_installation_id_v1'";
    final hits = <String>[];
    for (final file in _libSources()) {
      final source = file.readAsStringSync();
      if (source.contains(literal)) {
        hits.add(file.path.replaceAll(r'\', '/'));
      }
    }

    expect(
      hits,
      hasLength(1),
      reason:
          'Anahtar ${hits.length} dosyada yaziliyor: $hits\n'
          'Ikinci bir kopya, biri degistiginde cikis yolunu SESSIZCE bozar: '
          'cihaz kaydi sunucuda kalir ve eski hesabin bildirimleri o cihaza '
          'dusmeye devam eder. Dizeyi yazma, '
          '`kPushInstallationIdPrefsKey` sabitini kullan.',
    );
    expect(
      hits.single,
      endsWith('lib/data/repositories/push_registration_repository.dart'),
      reason:
          'Kanonik yer arayuz dosyasidir: hem kimligi yazan saglayici hem de '
          'cikis yolundaki auth deposu oraya bagimlidir, yani ikisi de ayni '
          'yerden okuyabilir.',
    );
  });

  test('cikis yolu sabiti ADIYLA okur, kendi kopyasini uretmez', () {
    final source = File(
      'lib/data/repositories/supabase/supabase_auth_repository.dart',
    ).readAsStringSync();

    expect(
      source.contains('kPushInstallationIdPrefsKey'),
      isTrue,
      reason:
          '`signOut` kurulum kimligini kanonik sabitle okumali. Yerel bir '
          'kopya sabit tanimlamak da ayni kusurdur: adi degisir, degeri '
          'ayrisir.',
    );
    expect(
      RegExp(r"const\s+\w*[Ii]nstallation\w*\s*=").hasMatch(source),
      isFalse,
      reason: 'Bu dosya kendi kurulum-anahtari sabitini TANIMLAMAMALI.',
    );
  });

  test('sabitin degeri degismedi — eski kurulumlar kimligini kaybetmez', () {
    // 🔴 Bu iddia bilerek DEGERI cakiyor. Anahtari yeniden adlandirmak
    // zararsiz gorunur ama sahadaki her cihazin diskindeki kayit o eski adla
    // duruyor: ad degisince kimlik "yok" sayilir, yeni bir kurulum kimligi
    // uretilir ve ESKI kayit sunucuda sahipsiz kalir — yani tam olarak
    // onlemeye calistigimiz hâl.
    expect(
      kPushInstallationIdPrefsKey,
      'push_installation_id_v1',
      reason:
          'Anahtari yeniden adlandirmak, sahadaki cihazlarin kayitli kimligini '
          'gorunmez kilar. Gerekiyorsa gecis yazilmali, ad sessizce '
          'degistirilmemeli.',
    );
  });
}
