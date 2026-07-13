import 'package:timezone/timezone.dart' as tz;

/// Dünya saati satırı için türetilmiş görünüm.
class WorldClockReading {
  const WorldClockReading({
    required this.cityLabel,
    required this.timeZoneId,
    required this.localTime,
    required this.isDaytime,
    required this.offsetLabel,
    required this.dayLabel,
  });

  final String cityLabel;
  final String timeZoneId;
  final DateTime localTime;
  final bool isDaytime;

  /// Örn. "Bugün, +3 sa" / "Dün, −5 sa"
  final String offsetLabel;
  final String dayLabel;
}

/// Gündüz: yerel saat 06:00–17:59.
bool isDaytimeHour(int hour) => hour >= 6 && hour < 18;

/// [home] kullanıcının yerel anı; [location] hedef TZ.
WorldClockReading readWorldClock({
  required String cityLabel,
  required String timeZoneId,
  required DateTime homeNow,
  tz.Location? location,
}) {
  final loc = location ?? tz.getLocation(timeZoneId);
  final remote = tz.TZDateTime.from(homeNow.toUtc(), loc);

  final homeOffset = homeNow.timeZoneOffset;
  final remoteOffset = remote.timeZoneOffset;
  final diff = remoteOffset - homeOffset;
  final hours = diff.inMinutes / 60.0;
  final sign = hours >= 0 ? '+' : '−';
  final absH = hours.abs();
  final hourPart = absH == absH.roundToDouble()
      ? absH.toInt().toString()
      : absH.toStringAsFixed(1);

  final homeDate = DateTime(homeNow.year, homeNow.month, homeNow.day);
  final remoteDate = DateTime(remote.year, remote.month, remote.day);
  final dayDelta = remoteDate.difference(homeDate).inDays;
  final dayLabel = switch (dayDelta) {
    0 => 'Bugün',
    1 => 'Yarın',
    -1 => 'Dün',
    _ when dayDelta > 1 => '$dayDelta gün sonra',
    _ => '${-dayDelta} gün önce',
  };

  final offsetLabel = hours == 0
      ? '$dayLabel, aynı saat'
      : '$dayLabel, $sign$hourPart sa';

  return WorldClockReading(
    cityLabel: cityLabel,
    timeZoneId: timeZoneId,
    localTime: remote,
    isDaytime: isDaytimeHour(remote.hour),
    offsetLabel: offsetLabel,
    dayLabel: dayLabel,
  );
}

/// Hazır şehir kataloğu (IANA TZ).
const kWorldCityCatalog = <({String label, String tz})>[
  (label: 'İstanbul', tz: 'Europe/Istanbul'),
  (label: 'Londra', tz: 'Europe/London'),
  (label: 'Berlin', tz: 'Europe/Berlin'),
  (label: 'Paris', tz: 'Europe/Paris'),
  (label: 'Moskova', tz: 'Europe/Moscow'),
  (label: 'Dubai', tz: 'Asia/Dubai'),
  (label: 'Mumbai', tz: 'Asia/Kolkata'),
  (label: 'Singapur', tz: 'Asia/Singapore'),
  (label: 'Tokyo', tz: 'Asia/Tokyo'),
  (label: 'Seul', tz: 'Asia/Seoul'),
  (label: 'Sidney', tz: 'Australia/Sydney'),
  (label: 'Auckland', tz: 'Pacific/Auckland'),
  (label: 'New York', tz: 'America/New_York'),
  (label: 'Chicago', tz: 'America/Chicago'),
  (label: 'Denver', tz: 'America/Denver'),
  (label: 'Los Angeles', tz: 'America/Los_Angeles'),
  (label: 'São Paulo', tz: 'America/Sao_Paulo'),
  (label: 'Kahire', tz: 'Africa/Cairo'),
];
