import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/providers/study_providers.dart';

void main() {
  test('verified timer state requires both server run id and token', () {
    const pending = StudyTimerState(
      isRunning: true,
      liveRunId: 'run-1',
      verification: TimerVerification.pending,
    );
    final verified = pending.copyWith(
      liveRunToken: 'token-1',
      verification: TimerVerification.verified,
    );

    expect(pending.isVerifiedRun, isFalse);
    expect(verified.isVerifiedRun, isTrue);
    expect(verified.copyWith(clearLiveRun: true).isVerifiedRun, isFalse);
  });

  test('Dart bridge carries only scoped run identity, never auth tokens', () {
    final bridge = File(
      'lib/core/background/timer_foreground_service.dart',
    ).readAsStringSync();
    expect(bridge, contains("'liveRunId': liveRunId"));
    expect(bridge, contains("'liveRunToken': liveRunToken"));
    expect(bridge, isNot(contains('accessToken')));
    expect(bridge, isNot(contains('refreshToken')));
  });

  test('native outbox preserves verified pause/resume/finalize ordering', () {
    final store = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'TimerStateStore.kt',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();

    expect(store, contains('appendPendingVerifiedCommand'));
    expect(store, contains('.put("runToken", runToken)'));
    expect(service, contains('p, "pause", liveRunToken, startOrigin'));
    expect(service, contains('p, "resume", liveRunToken, startOrigin'));
    expect(service, contains('p, "finalize", liveRunToken, startOrigin'));
    expect(service, contains('START_NOT_STICKY'));
  });

  test('saf-native fallback originleri ayrı ve unverified kalır', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();
    final provider = File(
      'lib/data/providers/study_providers.dart',
    ).readAsStringSync();

    expect(service, contains('startOrigin = "native_widget"'));
    expect(service, contains('"native_notification"'));
    expect(provider, contains('LiveRolloutOutcome.unverifiedFallback'));
    expect(provider, contains('TimerVerification.statisticsOnly'));
  });

  test('Android manifest FGS sözleşmesi değiştirilmeden uyumlu kalır', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:foregroundServiceType="dataSync"'));
    expect(
      manifest,
      contains('android:foregroundServiceType="dataSync|specialUse"'),
    );
  });

  test('running timer uses the stable custom One UI notification panel', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('androidx.core:core-ktx:1.18.0'));
    expect(manifest, isNot(contains('POST_PROMOTED_NOTIFICATIONS')));
    expect(
      service,
      contains('RemoteViews(packageName, R.layout.timer_notification)'),
    );
    expect(service, contains('.setCustomContentView(custom)'));
    expect(service, contains('.setCustomBigContentView(custom)'));
    expect(service, contains('KEY_PANEL_EXPANDED'));
    expect(service, contains('prefs().getBoolean(KEY_PANEL_EXPANDED, true)'));
    expect(service, contains('PRESENTATION_V43_CUSTOM'));
    expect(service, contains('PRESENTATION_STANDARD_FALLBACK'));
    expect(
      service,
      contains('views.setChronometer(\n            R.id.notif_timer_elapsed,\n            base,\n            null,\n            true,'),
    );
    expect(service, contains('R.mipmap.ic_launcher'));
    expect(service, isNot(contains('.setRequestPromotedOngoing(true)')));
    expect(service, isNot(contains('hasPromotableCharacteristics')));
    expect(
      File(
        'android/app/src/main/res/layout/timer_notification.xml',
      ).readAsStringSync(),
      allOf(contains('notif_timer_elapsed'), contains('notif_timer_action')),
    );
  });

  test('v43 fixture keeps the custom main path and standard fallback separate', () {
    final fixture = File(
      'test/fixtures/timer_notification_v43_contract.json',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();

    expect(fixture, contains('"defaultPresentation": "v43_custom_panel"'));
    expect(fixture, contains('"fallbackPresentation": "standard_fallback"'));
    expect(fixture, contains('"promotedNowBar": "not_requested"'));
    expect(fixture, contains('"hourBoundaryFormat"'));
    expect(service, isNot(contains('"00:%s"')));
    expect(service, isNot(contains('chronometerFormatHandler')));
    expect(service, contains('.setUsesChronometer(true)'));
    expect(service, contains('.setChronometerCountDown(false)'));
    expect(service, contains('EXTRA_PROMOTED_NOW_BAR'));
    expect(service, contains('PROMOTED_NOW_BAR_NOT_REQUESTED'));
  });
}
