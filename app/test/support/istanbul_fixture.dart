/// Gece yarısı tuzağına düşmeyen test verisi kurucuları.
///
/// **Neden var:** `v49` sürüm koşumu üç sayaç testi yüzünden kırıldı ve sebep
/// koddaki bir hata değildi — **koşum saatiydi**. Bu testler geçmişi
/// `DateTime.now() - 55 dk` gibi kurar; ürünün gün sınırı ise
/// `Europe/Istanbul` (`istanbulDay`). Koşum 00:00–01:00 arasına denk gelirse
/// kurulan oturum **düne** düşer, "bugünün toplamı" doğal olarak 0 çıkar ve
/// test hatasız kodu suçlar. v49 koşumu tam 00:00 İstanbul'da başlamıştı.
///
/// Buradaki yardımcılar geriye gidişi **bugünün içinde** tutar: gün başından
/// beri yeterli süre geçmişse istenen değer aynen döner, geçmemişse bugüne
/// sığan en büyük değer verilir. Böylece test her saatte anlamlı kalır.
library;

import 'package:online_study_room/core/stats/istanbul_calendar.dart';

/// [instant] anının İstanbul gün başlangıcından beri geçen süre.
Duration sinceIstanbulMidnight(DateTime instant) {
  // `istanbulDay` gün anahtarını yerel takvim alanlarıyla verir; aynı alanlarla
  // kurulan duvar saatinden çıkarmak doğru farkı üretir.
  final wall = istanbulWallClock(instant);
  return Duration(
    hours: wall.hour,
    minutes: wall.minute,
    seconds: wall.second,
    milliseconds: wall.millisecond,
  );
}

/// [desired] kadar geriye gitmek bugünden çıkmıyorsa onu, çıkıyorsa bugüne
/// sığan en büyük geri gidişi verir.
Duration backWithinIstanbulToday(Duration desired, {DateTime? now}) {
  final room = sinceIstanbulMidnight(now ?? DateTime.now());
  return desired <= room ? desired : room;
}

/// [desired] kadar geriye giden, ama bugünden çıkmayan bir an.
DateTime agoWithinIstanbulToday(Duration desired, {DateTime? now}) {
  final t = now ?? DateTime.now();
  return t.subtract(backWithinIstanbulToday(desired, now: t));
}
