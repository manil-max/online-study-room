import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';

void main() {
  test(
    'missing or malformed native permission fields are unknown, never granted',
    () {
      final missing = ClockPermissionSnapshot.fromMap({'notifications': true});
      final malformed = ClockPermissionSnapshot.fromMap({
        'notifications': true,
        'exactAlarm': 'yes',
        'batteryUnrestricted': true,
        'fullScreenIntent': true,
      });

      expect(missing.availability, ClockPermissionAvailability.unknown);
      expect(missing.allOk, isFalse);
      expect(malformed.availability, ClockPermissionAvailability.unknown);
      expect(malformed.allOk, isFalse);
    },
  );

  test('complete native snapshot reports available permission state', () {
    final snapshot = ClockPermissionSnapshot.fromMap({
      'notifications': true,
      'exactAlarm': false,
      'batteryUnrestricted': true,
      'fullScreenIntent': true,
    });

    expect(snapshot.availability, ClockPermissionAvailability.available);
    expect(snapshot.missingCount, 1);
    expect(snapshot.allOk, isFalse);
  });
}
