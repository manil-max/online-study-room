import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/global_timer.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopTimerNotificationService implements TimerNotificationGateway {
  const _NoopTimerNotificationService();

  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}
}

class _NoopAndroidWidgetService implements AndroidWidgetGateway {
  const _NoopAndroidWidgetService();

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {}

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {}

  @override
  Future<void> seedPlaceholder() async {}
}

class _NoopGlobalTimerCoordinator extends GlobalTimerCoordinator {
  _NoopGlobalTimerCoordinator(super.ref);

  @override
  Future<void> flushShadow() async {}

  @override
  Future<void> heartbeat() async {}

  @override
  Future<GlobalTimerForegroundDirective?> reconcileForeground({
    required bool localRunning,
    required bool localIsMirror,
    required String? localMirrorRunId,
  }) async => null;
}

Profile _profile(String id) =>
    Profile(id: id, displayName: id, createdAt: DateTime(2026));

Subject _subject(String id, String userId) =>
    Subject(id: id, userId: userId, name: id, color: 'chart-1');

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WP-448 seçilen ders tercihi', () {
    late SharedPreferences prefs;
    late StreamController<Profile?> auth;
    late StreamController<List<Subject>> subjects;
    late ProviderContainer container;

    Future<void> open({
      required String userId,
      required List<Subject> list,
    }) async {
      auth = StreamController<Profile?>.broadcast();
      subjects = StreamController<List<Subject>>.broadcast();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => auth.stream),
          userSubjectsProvider.overrideWith((ref) => subjects.stream),
          timerNotificationServiceProvider.overrideWithValue(
            const _NoopTimerNotificationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(
            const _NoopAndroidWidgetService(),
          ),
          globalTimerCoordinatorProvider.overrideWith(
            (ref) => _NoopGlobalTimerCoordinator(ref),
          ),
        ],
      );
      container.listen(authStateProvider, (_, _) {});
      container.listen(studyTimerProvider, (_, _) {});
      container.listen(userSubjectsProvider, (_, _) {});
      auth.add(_profile(userId));
      subjects.add(list);
      await _waitUntil(
        () => container.read(authStateProvider).value?.id == userId,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      container.dispose();
      await auth.close();
      await subjects.close();
    });

    test(
      'özel ders seçimi restart sonrası aynı hesapta geri yüklenir',
      () async {
        final math = _subject('math', 'u-a');
        await open(userId: 'u-a', list: [math]);

        container.read(studyTimerProvider.notifier).selectSubject(math.id);
        await _waitUntil(
          () => prefs.getString('selected_study_subject.u-a') == math.id,
        );
        expect(prefs.getString('timer_active_subject'), isNull);

        container.dispose();
        await auth.close();
        await subjects.close();
        await open(userId: 'u-a', list: [math]);

        await _waitUntil(
          () => container.read(studyTimerProvider).subjectId == math.id,
        );
      },
    );

    test('Genel seçimi de restart sonrası korunur', () async {
      final math = _subject('math', 'u-a');
      await open(userId: 'u-a', list: [math]);
      container.read(studyTimerProvider.notifier).selectSubject(math.id);
      container.read(studyTimerProvider.notifier).selectSubject(null);
      await _waitUntil(
        () => prefs.getString('selected_study_subject.u-a') == '__general__',
      );

      container.dispose();
      await auth.close();
      await subjects.close();
      await open(userId: 'u-a', list: [math]);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(studyTimerProvider).subjectId, isNull);
    });

    test('başka hesap önceki hesabın yerel tercihini görmez', () async {
      await prefs.setString('selected_study_subject.u-a', 'math');
      await open(userId: 'u-b', list: [_subject('math', 'u-b')]);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(studyTimerProvider).subjectId, isNull);
      expect(prefs.getString('selected_study_subject.u-a'), 'math');
      expect(prefs.getString('selected_study_subject.u-b'), isNull);
    });

    test('silinen ders bir kez açıklamayla Genel seçimine düşer', () async {
      await prefs.setString('selected_study_subject.u-a', 'deleted-subject');
      await open(userId: 'u-a', list: [_subject('physics', 'u-a')]);

      await _waitUntil(
        () => prefs.getString('selected_study_subject.u-a') == '__general__',
      );
      expect(container.read(studyTimerProvider).subjectId, isNull);
      // WP-468: provider metin değil sinyal taşır; cümleyi gösteren yüzey
      // kendi AppLocalizations'ından okur.
      expect(container.read(selectedStudySubjectFallbackNoticeProvider), isTrue);

      container
          .read(selectedStudySubjectFallbackNoticeProvider.notifier)
          .clear();
      subjects.add([_subject('physics', 'u-a')]);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(selectedStudySubjectFallbackNoticeProvider),
        isFalse,
        reason: 'aynı düşüş ikinci kez anlatılmamalı',
      );
    });
  });
}
