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
  // 🔴 WP-859: 2 sn güvenlik payı. Çağıranların çoğu kendi `now`unu ÖNCE
  // yakalayıp sonra bu fonksiyonu `now` vermeden çağırıyor
  // (`now.subtract(backWithinIstanbulToday(...))`). Buradaki `DateTime.now()`
  // birkaç ms SONRA okunduğu için "gün başından beri" payı dışarıdaki
  // `now`dan biraz uzun çıkıyor ve kurulan an gece yarısının milisaniyeler
  // ÖNCESİNE, yani DÜNE düşüyordu. Ölçüldü: beta-v8704 CI koşumu
  // (35397032160, İstanbul 00:36) — kayıtlı 1 saat "bugün"de hiç sayılmadı,
  // ekranda yalnız canlı 36m 50s vardı. Gün içinde pay görünmez; yalnız
  // İstanbul'un ilk saatinde fark eder.
  // Pay YALNIZ saat burada okunduğunda gerekir; `now` veren çağıran tek bir
  // anla çalışır ve kırpma tam gece yarısına iner (WP-565 iddiaları).
  final margin = now == null ? const Duration(seconds: 2) : Duration.zero;
  final since = sinceIstanbulMidnight(now ?? DateTime.now());
  final room = since > margin ? since - margin : Duration.zero;
  return desired <= room ? desired : room;
}

/// [desired] kadar geriye giden, ama bugünden çıkmayan bir an.
DateTime agoWithinIstanbulToday(Duration desired, {DateTime? now}) {
  final t = now ?? DateTime.now();
  return t.subtract(backWithinIstanbulToday(desired, now: t));
}

/// 🔴 İstanbul gününün ilk [window] kadarında mıyız?
///
/// [backWithinIstanbulToday] geriye gidişi bugüne sığdırır; ama bazı testlerin
/// iddiası pencerenin EN AZ belli bir uzunlukta olmasına dayanır (ör. 15 dk'lık
/// canlı kısım hedefi aşsın; ya da canlı süre sapma payından büyük olsun ki
/// "iki kez sayıldı" ayırt edilebilsin). Gün yeni başladıysa pencere o kadar
/// uzun OLAMAZ ve test hatasız kodu suçlar — 2026-09-19 00:01'de tam kapıda
/// iki test böyle kırmızıya düştü, 00:13'te aynı kod yeşildi.
/// Bu testler o aralıkta ölçüm yapamaz; açık gerekçeyle atlanır.
String? skipNearIstanbulMidnight(Duration window, {DateTime? now}) {
  final since = sinceIstanbulMidnight(now ?? DateTime.now());
  if (since >= window) return null;
  return 'İstanbul günü yeni başladı (${since.inSeconds} sn); '
      'test en az ${window.inMinutes} dk geçmiş gün ister';
}
