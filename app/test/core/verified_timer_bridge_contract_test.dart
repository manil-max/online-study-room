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

  test('running timer uses standard promoted ongoing notification', () {
    final service = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
      'StudyTimerService.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('androidx.core:core-ktx:1.18.0'));
    expect(manifest, contains('POST_PROMOTED_NOTIFICATIONS'));
    expect(service, contains('.setRequestPromotedOngoing(true)'));
    expect(service, contains('.setUsesChronometer(true)'));
    expect(service, contains('.setContentTitle('));
    expect(service, contains('R.drawable.ic_stat_focus_timer'));
    expect(service, contains('hasPromotableCharacteristics'));
    expect(service, contains('canPostPromotedNotifications'));
    expect(service, isNot(contains('.setCustomContentView(')));
    expect(service, isNot(contains('.setCustomBigContentView(')));
    expect(service, isNot(contains('R.layout.timer_notification')));
    expect(
      File(
        'android/app/src/main/res/layout/timer_notification.xml',
      ).existsSync(),
      isFalse,
    );
  });

  test('timer diagnostic bridge is read-only and platform guarded', () {
    final activity = File(
      'android/app/src/main/kotlin/com/manilmax/online_study_room/MainActivity.kt',
    ).readAsStringSync();
    final bridge = File(
      'lib/core/background/timer_foreground_service.dart',
    ).readAsStringSync();

    expect(activity, contains('getTimerNotificationDiagnostics'));
    expect(activity, contains('StudyTimerService.notificationDiagnostics'));
    expect(bridge, contains('TimerLiveNotificationDiagnostics'));
    expect(bridge, contains('invokeMapMethod<String, dynamic>'));
    expect(bridge, contains('TargetPlatform.android'));
  });
}
