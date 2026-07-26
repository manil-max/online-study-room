import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import 'device_timezone.dart';
import 'world_clock_math.dart';

/// İki IANA zaman diliminin aynı andaki farkı.
///
/// Sabit UTC offset'i saklanmaz ya da yeniden kullanılmaz: [at] anındaki tzdata
/// kuralı okunur. Böylece New York yaz/kış saati değiştiğinde etiket de değişir.
class TimeZoneOffsetDifference {
  const TimeZoneOffsetDifference(this.minutes);

  final int minutes;

  bool get isSame => minutes == 0;

  /// Örn. `+5:30`, `−7`.
  String get signedHourMinute {
    final sign = minutes >= 0 ? '+' : '−';
    final absolute = minutes.abs();
    final hours = absolute ~/ 60;
    final remainder = absolute % 60;
    return remainder == 0
        ? '$sign$hours'
        : '$sign$hours:${remainder.toString().padLeft(2, '0')}';
  }
}

/// [groupTimeZone]'un [viewerTimeZone]'a göre anlık farkını hesaplar.
///
/// Testler [at] ile yaz/kış geçişini sabitler; uygulama ise cihazın bilinen IANA
/// bölgesini kullanır. Geçersiz cihaz bölgesi güvenli UTC yedeğine iner.
TimeZoneOffsetDifference timeZoneOffsetDifference({
  required String groupTimeZone,
  String? viewerTimeZone,
  DateTime? at,
}) {
  tzdata.initializeTimeZones();
  final instant = (at ?? DateTime.now()).toUtc();
  final viewer = _locationOrUtc(viewerTimeZone ?? DeviceTimezone.lastId);
  final group = _locationOrUtc(groupTimeZone);
  final viewerOffset = tz.TZDateTime.from(instant, viewer).timeZoneOffset;
  final groupOffset = tz.TZDateTime.from(instant, group).timeZoneOffset;
  return TimeZoneOffsetDifference(
    groupOffset.inMinutes - viewerOffset.inMinutes,
  );
}

/// Aynı bölgedeyse `null`; aksi halde yerelleştirilmiş kısa açıklama döndürür.
String? groupTimeZoneRelativeLabel({
  required String groupTimeZone,
  required AppLocalizations l10n,
  String? viewerTimeZone,
  DateTime? at,
}) {
  final difference = timeZoneOffsetDifference(
    groupTimeZone: groupTimeZone,
    viewerTimeZone: viewerTimeZone,
    at: at,
  );
  if (difference.isSame) return null;
  return l10n.groupTimeZoneRelative(
    localizedWorldCityLabel(groupTimeZone, l10n, fallback: groupTimeZone),
    difference.signedHourMinute,
  );
}

/// Bölge adı ve varsa anlık farkı tek, açıklayıcı bir diyaloğa taşır.
Future<void> showGroupTimeZoneInfoDialog(
  BuildContext context, {
  required String groupTimeZone,
}) {
  final l10n = AppLocalizations.of(context);
  final city = localizedWorldCityLabel(
    groupTimeZone,
    l10n,
    fallback: groupTimeZone,
  );
  final relative = groupTimeZoneRelativeLabel(
    groupTimeZone: groupTimeZone,
    l10n: l10n,
  );
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.groupTimeZone),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(city),
          if (relative != null) ...[const SizedBox(height: 8), Text(relative)],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.coreKapat),
        ),
      ],
    ),
  );
}

tz.Location _locationOrUtc(String? timeZone) {
  if (timeZone?.trim() == 'UTC') return tz.UTC;
  if (timeZone != null && timeZone.trim().isNotEmpty) {
    try {
      return tz.getLocation(timeZone.trim());
    } catch (_) {
      // Cihaz eklentisi eski/bilinmeyen bir IANA adı döndürmüş olabilir.
    }
  }
  return tz.UTC;
}
