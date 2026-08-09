// WP-595: makul olmayan kosu suresi korkulugu — saf kural.
//
// Olay: gercek kullanici 2026-08-08 22:40'ta sayaci basaltti (gunlukteki son
// kullanici eylemi START'ti), sabah 10:02'de durdurdu; tek parca 11 sa 22 dk
// "calisma" kaydedildi, XP ve basarim verildi, XP geri alinamadi.
//
// 🔴 Bu dosya zamani ENJEKTE eder, `DateTime.now()` cagirmaz. Bu repoda gece
// yarisi flake'i iki kez surum kosumunu kirdi; ayrica olcmek istedigimiz sey
// "su an saat kac" degil, "kosu ne kadardir suruyor".
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/implausible_run_guard.dart';

void main() {
  // Sabit bir baslangic ani. Takvim gunune bagli hicbir iddia yok.
  final startedAt = DateTime.utc(2026, 8, 8, 19, 40, 28);

  group('implausibleRunElapsed', () {
    test('esigin ALTINDA uyarmaz (5 sa 59 dk)', () {
      final elapsed = implausibleRunElapsed(
        isRunning: true,
        startedAt: startedAt,
        now: startedAt.add(const Duration(hours: 5, minutes: 59)),
      );
      expect(elapsed, isNull);
    });

    test('esigin TAM UZERINDE uyarir (6 sa)', () {
      final elapsed = implausibleRunElapsed(
        isRunning: true,
        startedAt: startedAt,
        now: startedAt.add(kImplausibleRunThreshold),
      );
      expect(elapsed, kImplausibleRunThreshold);
    });

    test('gercek olayin suresini bildirir (11 sa 22 dk 19 sn)', () {
      // Gunlukten: stop_requested elapsed_seconds = 40938.
      const real = Duration(seconds: 40938);
      final elapsed = implausibleRunElapsed(
        isRunning: true,
        startedAt: startedAt,
        now: startedAt.add(real),
      );
      expect(elapsed, real);
      expect(elapsed!.inHours, 11);
    });

    test('sayac DURUYORSA eski bir baslangic bile uyarmaz', () {
      // 🔴 Ters yon: bu iddia olmadan "her zaman uyar" diyen bozuk bir kural
      // da yesil gecerdi.
      final elapsed = implausibleRunElapsed(
        isRunning: false,
        startedAt: startedAt,
        now: startedAt.add(const Duration(hours: 20)),
      );
      expect(elapsed, isNull);
    });

    test('baslangic yoksa uyarmaz', () {
      final elapsed = implausibleRunElapsed(
        isRunning: true,
        startedAt: null,
        now: startedAt.add(const Duration(hours: 20)),
      );
      expect(elapsed, isNull);
    });

    test('saat GERIYE gittiyse uyarmaz (WP-542 arizasiyla karistirma)', () {
      final elapsed = implausibleRunElapsed(
        isRunning: true,
        startedAt: startedAt,
        now: startedAt.subtract(const Duration(hours: 9)),
      );
      expect(elapsed, isNull);
    });

    test('esik cagri basina degistirilebilir', () {
      expect(
        implausibleRunElapsed(
          isRunning: true,
          startedAt: startedAt,
          now: startedAt.add(const Duration(minutes: 90)),
          threshold: const Duration(hours: 1),
        ),
        const Duration(minutes: 90),
      );
    });
  });

  test('esik urun kararidir: 6 saat', () {
    // Esigi sessizce buyutmek bu WP'nin tamamini etkisizlestirir; degistiren
    // kisi bu testi de degistirmek zorunda kalsin.
    expect(kImplausibleRunThreshold, const Duration(hours: 6));
  });
}
