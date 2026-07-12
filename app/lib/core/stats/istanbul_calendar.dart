import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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

DateTime istanbulNow() => tz.TZDateTime.now(_istanbul);

DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int istanbulHour(DateTime instant) =>
    tz.TZDateTime.from(instant, _istanbul).hour;

int istanbulWeekday(DateTime instant) =>
    tz.TZDateTime.from(instant, _istanbul).weekday;
