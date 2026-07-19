import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_integrations/samsung_modes_service.dart';
import '../../core/navigation/nav_index.dart';
import 'study_providers.dart';

@visibleForTesting
AppTab? appTabForDeviceAction(String action) => switch (action) {
  'com.manilmax.online_study_room.OPEN_STATS' => AppTab.stats,
  'com.manilmax.online_study_room.OPEN_CHAT' => AppTab.groups,
  'com.manilmax.online_study_room.OPEN_LEADERBOARD' => AppTab.home,
  _ => null,
};

void _handleDeviceAction(Ref ref, String action) {
  final targetTab = appTabForDeviceAction(action);
  if (targetTab != null) {
    ref.read(navIndexProvider.notifier).setTab(targetTab);
    return;
  }

  final timerNotifier = ref.read(studyTimerProvider.notifier);
  switch (action) {
    case 'com.manilmax.online_study_room.START_TIMER':
      timerNotifier.start();
      break;
    case 'com.manilmax.online_study_room.STOP_TIMER':
      timerNotifier.stop();
      break;
    case 'com.manilmax.online_study_room.START_POMODORO':
      timerNotifier.setMode(TimerMode.pomodoro);
      timerNotifier.start();
      break;
    case 'com.manilmax.online_study_room.START_STOPWATCH':
      timerNotifier.setMode(TimerMode.stopwatch);
      timerNotifier.start();
      break;
    case 'com.manilmax.online_study_room.TAKE_BREAK':
      timerNotifier.stop();
      break;
  }
}

/// Uygulama açıkken veya soğuk başlangıçta gelen cihaz entegrasyonu
/// (App Shortcuts / Samsung Routines) aksiyonlarını dinler ve tetikler.
final deviceIntegrationListenerProvider = Provider<void>((ref) {
  // Windows/web: kanal yok — dinleyiciyi hiç kurma.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  final service = ref.watch(deviceIntegrationServiceProvider);

  // Soğuk başlangıçtaki aksiyonu yakala
  service.getInitialAction().then((action) {
    if (action != null) {
      _handleDeviceAction(ref, action);
    }
  });

  // Uygulama açıkken gelen aksiyonları yakala
  service.onActionReceived = (action) {
    _handleDeviceAction(ref, action);
  };
});
