import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/nudge.dart';
import 'app_push_notification_service.dart';

final nudgeNotificationServiceProvider = Provider<NudgeNotificationGateway>(
  (ref) => NudgeNotificationService.instance,
);

abstract interface class NudgeNotificationGateway {
  Future<void> requestPermissionIfNeeded();

  Future<void> showNudge(Nudge nudge);
}

class NudgeNotificationService implements NudgeNotificationGateway {
  NudgeNotificationService._();

  static final instance = NudgeNotificationService._();

  @override
  Future<void> requestPermissionIfNeeded() async {
    await AppNotificationCoordinator.instance.requestPermission();
    await AppPushNotificationService.instance.requestPermission();
  }

  @override
  Future<void> showNudge(Nudge nudge) =>
      AppNotificationCoordinator.instance.showNudge(nudge);
}
