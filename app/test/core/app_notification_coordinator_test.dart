import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/app_push_notification_service.dart';

void main() {
  testWidgets(
    'Android hedefli test hostunda kayıtsız local notification platformu no-op olur',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await expectLater(
          AppNotificationCoordinator.instance.initialize(),
          completes,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
