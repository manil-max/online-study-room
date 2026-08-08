import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/study_group.dart';

final tz.Location _istanbul = _loadIstanbul();

tz.Location _loadIstanbul() {
  tz_data.initializeTimeZones();
  return tz.getLocation('Europe/Istanbul');
}

/// 🔴 WP-561: Bir gün anahtarı `DateTime(y, m, d)` ile, yani **cihazın yerel**
/// gece yarısı olarak kurulur. Anahtarın kendisi bir "an"dır ve o an cihaz
/// offset'ine bağlıdır. Kod ise bu anahtarı sürekli **tekrar** bu fonksiyondan
/// geçirir (`dayOf(dayOf(x))`, `inRange` içindeki normalizasyon,
/// `startOfWeek → range → inRange` zinciri, `class_stats_view`'daki açık çift
/// `dayOf`). Cihaz offset'i +03:00'i aştığında (UTC+4 ve doğusu) yerel gece
/// yarısı hâlâ **önceki** İstanbul gününe düşer; ikinci çevrim anahtarı bir gün
/// geri kaydırır ve bütün pencereler bir gün genişler/kayar.
///
/// Çözüm: dönüşüm **idempotent**tir — girdi zaten bir gün anahtarıysa (yerel,
/// saat/dakika/saniye/milisaniye/mikrosaniye = 0) aynen döner. UTC damgaları
/// (DB'den gelen gerçek anlar `DateTime.parse('…Z')` ile `isUtc == true`
/// olur) bu kapıdan geçmez, hep çevrilir.
bool _isDayKey(DateTime value) =>
    !value.isUtc &&
    value.hour == 0 &&
    value.minute == 0 &&
    value.second == 0 &&
    value.millisecond == 0 &&
    value.microsecond == 0;

DateTime _dayKeyIn(DateTime instant, tz.Location location) {
  // Anahtar her hâlükârda **düz** `DateTime` olarak kurulur: `istanbulNow()`
  // gibi kaynaklar `TZDateTime` verir ve `TZDateTime.hashCode` düz `DateTime`
  // ile eşleşmediğinden gün→saniye haritalarında sessizce ıskalanırdı.
  if (_isDayKey(instant)) {
    return DateTime(instant.year, instant.month, instant.day);
  }
  final local = tz.TZDateTime.from(instant, location);
  return DateTime(local.year, local.month, local.day);
}

/// Bir anı, ürünün tek takvim sınırı olan Europe/Istanbul gününe indirger.
/// Dönen değer gün anahtarıdır; saat bilgisi bilerek yoktur.
DateTime istanbulDay(DateTime instant) => _dayKeyIn(instant, _istanbul);

/// WP-326: Bir grubun gün sınırı sabit offset değil IANA bölge adıdır. Böylece
/// New York'ta yaz/kış saati değiştiğinde gece yarısı sessizce kaymaz.
DateTime calendarDayInTimeZone(DateTime instant, String timeZone) {
  _loadIstanbul();
  return _dayKeyIn(instant, tz.getLocation(timeZone));
}

/// WP-561: Bir anın ait olduğu İstanbul gününün **00:00'ının gerçek anı**.
///
/// [istanbulDay] gün *anahtarı* verir (cihaz yerel gece yarısı) — bir zaman
/// aralığını gece yarısında kırpmak için kullanılamaz. Canlı sayaç terimini
/// "yalnız bugüne düşen kısım"a indirmek bu sınırı gerektirir.
DateTime istanbulDayStart(DateTime instant) {
  final local = tz.TZDateTime.from(instant, _istanbul);
  return tz.TZDateTime(_istanbul, local.year, local.month, local.day);
}

/// Birincil grup WP-329'da bağlanana kadar bu saf yardımcı yalnız seçim
/// zincirini tanımlar: birincil grup → cihaz → güvenli İstanbul varsayılanı.
String resolveStudyDayTimeZone({
  String? primaryGroupTimeZone,
  String? deviceTimeZone,
}) {
  for (final candidate in [primaryGroupTimeZone, deviceTimeZone]) {
    final normalized = candidate?.trim();
    if (normalized == null || normalized.isEmpty) continue;
    try {
      _loadIstanbul();
      tz.getLocation(normalized);
      return normalized;
    } catch (_) {
      // Hatalı/eskimiş cihaz adı gün hesabını kırmamalı; sıradaki kaynak denenir.
    }
  }
  return kDefaultGroupTimeZone;
}

DateTime istanbulNow() => tz.TZDateTime.now(_istanbul);

DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// WP-254: bir anın **Europe/Istanbul duvar saati** karşılığı (saat/dakika
/// göstermek için tek doğru kaynak).
///
/// DB'den gelen zaman damgaları `DateTime.parse('…Z')` ile **UTC** DateTime
/// olur; üzerlerinde doğrudan `.hour` çağırmak yaz saatinde **3 saat geri**
/// gösterir. `.toLocal()` de kullanılmaz — ürün cihaz TZ'sinden bağımsız
/// olarak İstanbul takvimine göre çalışır (bkz. [istanbulDay]).
DateTime istanbulWallClock(DateTime instant) =>
    tz.TZDateTime.from(instant, _istanbul);

/// `HH:MM` (iki haneli, İstanbul duvar saati).
String istanbulHm(DateTime instant) {
  final local = istanbulWallClock(instant);
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

int istanbulHour(DateTime instant) =>
    tz.TZDateTime.from(instant, _istanbul).hour;

int istanbulWeekday(DateTime instant) =>
    tz.TZDateTime.from(instant, _istanbul).weekday;
