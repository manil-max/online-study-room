import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/group_time_zone_label.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  group('timeZoneOffsetDifference', () {
    test('New York is seven hours behind Istanbul in summer', () {
      final difference = timeZoneOffsetDifference(
        groupTimeZone: 'America/New_York',
        viewerTimeZone: 'Europe/Istanbul',
        at: DateTime.utc(2026, 7, 1, 12),
      );

      expect(difference.minutes, -7 * 60);
      expect(difference.signedHourMinute, '−7');
    });

    test('New York is eight hours behind Istanbul in winter', () {
      final difference = timeZoneOffsetDifference(
        groupTimeZone: 'America/New_York',
        viewerTimeZone: 'Europe/Istanbul',
        at: DateTime.utc(2026, 1, 1, 12),
      );

      expect(difference.minutes, -8 * 60);
      expect(difference.signedHourMinute, '−8');
    });

    test('half-hour offsets keep their minutes', () {
      final difference = timeZoneOffsetDifference(
        groupTimeZone: 'Asia/Kolkata',
        viewerTimeZone: 'UTC',
        at: DateTime.utc(2026, 7, 1, 12),
      );

      expect(difference.minutes, 330);
      expect(difference.signedHourMinute, '+5:30');
    });
  });

  test('same zone has no relative label', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    expect(
      groupTimeZoneRelativeLabel(
        groupTimeZone: 'Europe/Istanbul',
        viewerTimeZone: 'Europe/Istanbul',
        at: DateTime.utc(2026, 7, 1, 12),
        l10n: l10n,
      ),
      isNull,
    );
  });
}
