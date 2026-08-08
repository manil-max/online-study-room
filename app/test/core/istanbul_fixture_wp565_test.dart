// WP-565: `test/support/istanbul_fixture.dart` DORT test dosyasini gece yarisi
// tuzagindan koruyor ama KENDISI test edilmiyordu.
//
// Tuzak somut: bu testler gecmisi `DateTime.now() - 1 saat` ile kurar, urunun
// gun siniri ise `Europe/Istanbul`. Kosum 00:00-01:00 arasina denk gelirse
// oturum DUNE duser, "bugunun toplami" 0 cikar ve test HATASIZ kodu suclar.
// Iki kez oldu: v49 surum kosumu (00:00 Istanbul) ve 2026-08-09 gecesi
// (`today_summary_unbounded_wp515` 4 test + `ux_quick_wins_wp555` 1 test
// 00:5x'te kirmizi, 01:04'te hicbir kod degismeden yesil).
//
// Yardimcinin sozlesmesi tek cumle: geri gidis BUGUNUN ICINDE kalir. Asagisi
// onu enjekte edilen anlarla olcer -- kosum saatinden bagimsiz, yani bu dosya
// gece yarisi penceresini beklemeden sinar.
//
// 🔴 Bu testler enjekte `now` kullanir; `DateTime.now()` cagirmazlar. Yoksa
// dosya korumaya calistigi hatanin aynisina dusrdu.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';

import '../support/istanbul_fixture.dart';

void main() {
  // Istanbul UTC+3: 21:30Z = ertesi gun 00:30 Istanbul.
  final justAfterMidnight = DateTime.utc(2026, 8, 9, 21, 30);
  // 09:00Z = 12:00 Istanbul, gunun ortasi.
  final midday = DateTime.utc(2026, 8, 10, 9);

  test('gece yarisindan hemen sonra geri gidis BUGUNDEN cikmaz', () {
    final start = agoWithinIstanbulToday(
      const Duration(hours: 1),
      now: justAfterMidnight,
    );

    // Asil iddia: oturum bugune dusuyor. Kirpma olmasaydi `dayOf` dun olurdu
    // ve "bugunun ozeti" bos cikardi -- korunan hatanin tam kendisi.
    expect(
      istanbulDay(start),
      istanbulDay(justAfterMidnight),
      reason:
          'Gece yarisindan 30 dk sonra 1 saat geri gitmek DUNE dusuyor; '
          'yardimci kirpmiyor demektir.',
    );
    // Kirpma bugunun basina kadar: 00:30 - 30 dk = 00:00.
    expect(start, justAfterMidnight.subtract(const Duration(minutes: 30)));
  });

  test('gun ortasinda istenen geri gidis AYNEN uygulanir (kirpma sessizce yalan soylemez)', () {
    final start = agoWithinIstanbulToday(const Duration(hours: 1), now: midday);

    expect(start, midday.subtract(const Duration(hours: 1)));
    expect(istanbulDay(start), istanbulDay(midday));
  });

  test('gun basindan beri gecen sure Istanbul duvar saatinden okunur', () {
    // Cihaz hangi bolgede olursa olsun olculen sey Istanbul duvar saatidir;
    // bu yuzden UTC damgasi veriyoruz ve beklenen deger sabit.
    expect(sinceIstanbulMidnight(justAfterMidnight), const Duration(minutes: 30));
    expect(sinceIstanbulMidnight(midday), const Duration(hours: 12));
  });

  test('backWithinIstanbulToday sadece TASAN kismi kirpar', () {
    // Sigan istek dokunulmadan doner.
    expect(
      backWithinIstanbulToday(const Duration(minutes: 10), now: justAfterMidnight),
      const Duration(minutes: 10),
    );
    // Tasan istek gunun basina kadar kisalir -- daha fazlasina degil.
    expect(
      backWithinIstanbulToday(const Duration(hours: 5), now: justAfterMidnight),
      const Duration(minutes: 30),
    );
    // Gun ortasinda 5 saat zaten siger.
    expect(
      backWithinIstanbulToday(const Duration(hours: 5), now: midday),
      const Duration(hours: 5),
    );
  });

  test('gun basinin kendisinde geri gidis SIFIRDIR (negatif gune tasma yok)', () {
    final atMidnight = DateTime.utc(2026, 8, 9, 21);

    expect(
      backWithinIstanbulToday(const Duration(hours: 1), now: atMidnight),
      Duration.zero,
    );
    expect(
      istanbulDay(agoWithinIstanbulToday(const Duration(hours: 1), now: atMidnight)),
      istanbulDay(atMidnight),
    );
  });
}
