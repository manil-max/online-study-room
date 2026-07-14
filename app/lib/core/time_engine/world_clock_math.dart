import 'package:timezone/timezone.dart' as tz;
import 'package:online_study_room/l10n/app_localizations.dart';

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
  required AppLocalizations l10n,
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
    0 => l10n.coreBugun,
    1 => l10n.coreYarin,
    -1 => l10n.coreDun,
    _ when dayDelta > 1 => '+$dayDelta',
    _ => '$dayDelta',
  };

  final offsetLabel = hours == 0 ? dayLabel : '$dayLabel, UTC$sign$hourPart';

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
  (label: 'Istanbul', tz: 'Europe/Istanbul'),
  (label: 'London', tz: 'Europe/London'),
  (label: 'Berlin', tz: 'Europe/Berlin'),
  (label: 'Paris', tz: 'Europe/Paris'),
  (label: 'Moscow', tz: 'Europe/Moscow'),
  (label: 'Dubai', tz: 'Asia/Dubai'),
  (label: 'Mumbai', tz: 'Asia/Kolkata'),
  (label: 'Singapore', tz: 'Asia/Singapore'),
  (label: 'Tokyo', tz: 'Asia/Tokyo'),
  (label: 'Seoul', tz: 'Asia/Seoul'),
  (label: 'Sydney', tz: 'Australia/Sydney'),
  (label: 'Auckland', tz: 'Pacific/Auckland'),
  (label: 'New York', tz: 'America/New_York'),
  (label: 'Chicago', tz: 'America/Chicago'),
  (label: 'Denver', tz: 'America/Denver'),
  (label: 'Los Angeles', tz: 'America/Los_Angeles'),
  (label: 'São Paulo', tz: 'America/Sao_Paulo'),
  (label: 'Cairo', tz: 'Africa/Cairo'),
];

String localizedWorldCityLabel(
  String timeZoneId,
  AppLocalizations l10n, {
  String? fallback,
}) => switch (timeZoneId) {
  'Europe/Istanbul' => l10n.coreIstanbul,
  'Europe/London' => l10n.coreLondra,
  'Europe/Berlin' => l10n.coreBerlin,
  'Europe/Paris' => l10n.coreParis,
  'Europe/Moscow' => l10n.coreMoskova,
  'Asia/Dubai' => l10n.coreDubai,
  'Asia/Kolkata' => l10n.coreMumbai,
  'Asia/Singapore' => l10n.coreSingapur,
  'Asia/Tokyo' => l10n.coreTokyo,
  'Asia/Seoul' => l10n.coreSeul,
  'Australia/Sydney' => l10n.coreSidney,
  'Pacific/Auckland' => l10n.coreAuckland,
  'America/New_York' => l10n.coreNewYork,
  'America/Chicago' => l10n.coreChicago,
  'America/Denver' => l10n.coreDenver,
  'America/Los_Angeles' => l10n.coreLosAngeles,
  'America/Sao_Paulo' => l10n.coreSoPaulo,
  'Africa/Cairo' => l10n.coreKahire,
  _ => fallback ?? timeZoneId,
};
