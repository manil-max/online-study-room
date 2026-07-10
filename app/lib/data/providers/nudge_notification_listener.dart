import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/nudge_notification_service.dart';
import 'auth_providers.dart';
import 'nudge_providers.dart';

final nudgeNotificationListenerProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).value;
  final preferences = ref.watch(notificationPreferencesProvider);
  if (user == null || !preferences.nudgeNotificationsEnabled) return;

  ref.listen(receivedNudgesProvider(user.id), (previous, next) {
    final previousNudges = previous?.value ?? const [];
    final currentNudges = next.value ?? const [];
    if (previous == null || currentNudges.isEmpty) return;

    final previousIds = previousNudges.map((n) => n.id).toSet();
    for (final nudge in currentNudges) {
      if (nudge.readAt != null || previousIds.contains(nudge.id)) continue;
      unawaited(ref.read(nudgeNotificationServiceProvider).showNudge(nudge));
    }
  });
});
