import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_integrations/samsung_modes_service.dart';
import '../../core/navigation/home_shell.dart';
import 'study_providers.dart';

void _handleDeviceAction(Ref ref, String action) {
  final timerNotifier = ref.read(studyTimerProvider.notifier);
  final navNotifier = ref.read(navIndexProvider.notifier);

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
    case 'com.manilmax.online_study_room.OPEN_STATS':
      navNotifier.setIndex(2);
      break;
    case 'com.manilmax.online_study_room.OPEN_CHAT':
      navNotifier.setIndex(1);
      break;
    case 'com.manilmax.online_study_room.OPEN_LEADERBOARD':
      navNotifier.setIndex(0);
      break;
  }
}

/// Uygulama açıkken veya soğuk başlangıçta gelen cihaz entegrasyonu
/// (App Shortcuts / Samsung Routines) aksiyonlarını dinler ve tetikler.
final deviceIntegrationListenerProvider = Provider<void>((ref) {
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
