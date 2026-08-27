import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_panel_preference.dart';

/// 🔴 WP-759 KUSUR 4 nöbetçisi — **ölü anahtar** kapısı.
///
/// Ölçülen kusur: `StudyTimerService.kt` sayaç bildiriminin hangi yüzeyle
/// çizileceğini `flutter.timer_panel_expanded` anahtarına bağlıyordu, ama
/// `app/lib` içinde o anahtara dokunan **tek bir satır yoktu**:
///
/// ```
/// $ grep -rn "timer_panel_expanded" app/lib   ->  0 eslesme
/// ```
///
/// Bunun bedeli ölçüldü, tahmin değil: WP-753 Live Update yolunu varsayılan
/// yaptı, yol cihazda hiç görülmeden v71 ile yayına çıktı, sahibin Galaxy
/// S23'ünde bildirim `00:00` gösterdi ve Start/Stop düğmesi kayboldu. Yolu
/// açmanın tek yolu `adb` ile `shared_prefs` XML'ini elle düzenlemekti — yani
/// ne bir kullanıcı ne de bir cihaz testi o dalı kendiliğinden koşturamazdı.
///
/// Bu test "kod doğru mu"yu değil **"kullanıcı buraya varabiliyor mu"yu**
/// ölçer. `docs` notu okumak yetmez; anahtarın canlı bir yazıcısı ve canlı bir
/// ekran bağı olmak zorunda (bkz. hafıza: *bitmiş backend + bağlanmamış UI*).
void main() {
  const nativeSource =
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt';

  List<File> dartSourcesUnderLib() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('Dart anahtari native anahtarla ayni seyi adlandirir', () {
    // `shared_preferences` Android'de her anahtari `flutter.` ile onekler.
    expect(kTimerPanelExpandedNativeKey, 'flutter.$kTimerPanelExpandedKey');

    final service = File(nativeSource).readAsStringSync();
    expect(
      service,
      contains('KEY_PANEL_EXPANDED = "$kTimerPanelExpandedNativeKey"'),
      reason:
          'Native taraf baska bir anahtar okuyorsa Dart anahtari yine olur: '
          'kullanici anahtari cevirir, bildirim degismez.',
    );
  });

  test('anahtarin app/lib icinde GERCEK bir yazicisi var', () {
    final writers = <String>[];
    for (final file in dartSourcesUnderLib()) {
      final text = file.readAsStringSync();
      if (text.contains('setBool(kTimerPanelExpandedKey') ||
          text.contains("setBool('$kTimerPanelExpandedKey'") ||
          text.contains('setBool("$kTimerPanelExpandedKey"')) {
        writers.add(file.path);
      }
    }

    expect(
      writers,
      isNotEmpty,
      reason:
          'OLU ANAHTAR. `$kTimerPanelExpandedNativeKey` native tarafta bildirim '
          'yuzeyini seciyor ama app/lib icinde onu yazan kod yok. Bu dala '
          'kullanici da cihaz testi de ULASAMAZ; WP-753 tam olarak bu yuzden '
          'cihazda hic gorulmeden yayina cikti.',
    );
  });

  test('ucuncu durum (otomatik) diske YAZILAMAZ, SILINIR', () {
    // 🔴 WP-760: "otomatik" bir deger degil, degerin YOKLUGUdur. Herhangi bir
    // bool yazmak ucuncu durumu yok eder; `true` yazmak ise dinamik paneli
    // kalici kapatir. Bu yuzden anahtari SILEN bir yazici bulunmak zorunda.
    final removers = <String>[];
    for (final file in dartSourcesUnderLib()) {
      if (file.readAsStringSync().contains('remove(kTimerPanelExpandedKey')) {
        removers.add(file.path);
      }
    }

    expect(
      removers,
      isNotEmpty,
      reason:
          'Anahtari silen kod yok. "Otomatik"e donus `true` yazmaya cevrilmis '
          'demektir; kullanici secimi bir kez acip kapatinca dinamik panel '
          'KALICI kapanir ve geri donus kalmaz.',
    );
  });

  test('anahtar kullanicinin gorebilecegi bir ekrana bagli', () {
    final screens = <String>[];
    for (final file in dartSourcesUnderLib()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.contains('/features/')) continue;
      if (file.readAsStringSync().contains('timerPanelChoiceProvider')) {
        screens.add(path);
      }
    }

    expect(
      screens,
      isNotEmpty,
      reason:
          'Saglayici var ama hicbir ekran onu izlemiyor -- yazici da olsa '
          'kullanici anahtari GOREMEZ. Kusur 4 geri geldi.',
    );
  });
}
