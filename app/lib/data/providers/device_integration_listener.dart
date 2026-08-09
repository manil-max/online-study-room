import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_integrations/samsung_modes_service.dart';
import '../../core/navigation/nav_index.dart';
import '../../core/observability/timer_diagnostic_journal.dart';
import 'study_providers.dart';

@visibleForTesting
AppTab? appTabForDeviceAction(String action) => switch (action) {
  'com.manilmax.online_study_room.OPEN_STATS' => AppTab.stats,
  'com.manilmax.online_study_room.OPEN_CHAT' => AppTab.groups,
  'com.manilmax.online_study_room.OPEN_LEADERBOARD' => AppTab.home,
  _ => null,
};

/// WP-599: intent adı → günlüğe yazılacak kısa aksiyon slug'ı.
///
/// Ham intent adı (`com.manilmax...START_TIMER`) günlüğe **giremez**: slug
/// kapısı (`[a-z0-9_]{1,48}`) onu `unknown`a düşürürdü. Eşleme burada durur ki
/// yeni bir kısayol eklendiğinde adı da tek yerde eklensin.
@visibleForTesting
const deviceTimerActionSlugs = <String, String>{
  'com.manilmax.online_study_room.START_TIMER': 'start_timer',
  'com.manilmax.online_study_room.STOP_TIMER': 'stop_timer',
  'com.manilmax.online_study_room.START_POMODORO': 'start_pomodoro',
  'com.manilmax.online_study_room.START_STOPWATCH': 'start_stopwatch',
  'com.manilmax.online_study_room.TAKE_BREAK': 'take_break',
};

/// WP-599: bu aksiyonun günlük damgası.
///
/// [coldStart] `true` → süreç bu intentle **doğdu** (`getInitialAction`),
/// `false` → uygulama zaten açıktı (`onIntentAction`). Ayrımı tutmak şart:
/// "uygulamayı hiç açmadım" anlatısını yalnız `cold` doğrular.
@visibleForTesting
String deviceIntegrationTrigger(String action, {required bool coldStart}) =>
    TimerJournalTriggers.deviceIntegration(
      action: deviceTimerActionSlugs[action] ?? TimerJournalSlug.unknown,
      coldStart: coldStart,
    );

/// WP-599 (açık): bu yol sayacı **kullanıcı düğmesiyle aynı** satırı yazarak
/// başlatıyordu (`start_requested / user_action / app`). Yani bir Samsung
/// Routine gece 03:00'te sayacı açsa günlükte parmakla başlatmadan ayırt
/// edilemezdi — sahibin "sayacı gerçekten kardeşim mi başlattı" sorusu
/// (`docs/analiz/WP-595-sayac-xp-teshis.md`) bu yüzden cevapsız kaldı.
///
/// Davranış aynı kaldı; değişen tek şey **iz bırakması**.
void _handleDeviceAction(Ref ref, String action, {required bool coldStart}) {
  final targetTab = appTabForDeviceAction(action);
  if (targetTab != null) {
    ref.read(navIndexProvider.notifier).setTab(targetTab);
    return;
  }

  final timerNotifier = ref.read(studyTimerProvider.notifier);
  final trigger = deviceIntegrationTrigger(action, coldStart: coldStart);
  switch (action) {
    case 'com.manilmax.online_study_room.START_TIMER':
      timerNotifier.start(trigger: trigger);
      break;
    case 'com.manilmax.online_study_room.STOP_TIMER':
      timerNotifier.stop(trigger: trigger);
      break;
    case 'com.manilmax.online_study_room.START_POMODORO':
      timerNotifier.setMode(TimerMode.pomodoro);
      timerNotifier.start(trigger: trigger);
      break;
    case 'com.manilmax.online_study_room.START_STOPWATCH':
      timerNotifier.setMode(TimerMode.stopwatch);
      timerNotifier.start(trigger: trigger);
      break;
    case 'com.manilmax.online_study_room.TAKE_BREAK':
      timerNotifier.stop(trigger: trigger);
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
      _handleDeviceAction(ref, action, coldStart: true);
    }
  });

  // Uygulama açıkken gelen aksiyonları yakala
  service.onActionReceived = (action) {
    _handleDeviceAction(ref, action, coldStart: false);
  };
});
