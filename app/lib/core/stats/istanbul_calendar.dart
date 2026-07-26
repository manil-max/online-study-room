import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/study_group.dart';

final tz.Location _istanbul = _loadIstanbul();

tz.Location _loadIstanbul() {
  tz_data.initializeTimeZones();
  return tz.getLocation('Europe/Istanbul');
}

/// Bir anı, ürünün tek takvim sınırı olan Europe/Istanbul gününe indirger.
/// Dönen değer gün anahtarıdır; saat bilgisi bilerek yoktur.
DateTime istanbulDay(DateTime instant) {
  final local = tz.TZDateTime.from(instant, _istanbul);
  return DateTime(local.year, local.month, local.day);
}

/// WP-326: Bir grubun gün sınırı sabit offset değil IANA bölge adıdır. Böylece
/// New York'ta yaz/kış saati değiştiğinde gece yarısı sessizce kaymaz.
DateTime calendarDayInTimeZone(DateTime instant, String timeZone) {
  _loadIstanbul();
  final location = tz.getLocation(timeZone);
  final local = tz.TZDateTime.from(instant, location);
  return DateTime(local.year, local.month, local.day);
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
