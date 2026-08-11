// 🔴 WP-697 — "Sure ekle" diyalogu her acilista Genel'e dusuyordu.
//
// Duzeltmeden ONCE olculen davranis: `addManualSessionFlow`
// (`manual_session_dialog.dart:88`) diyalogu `initialSubjectId` VERMEDEN
// aciyordu; `_ManualSessionDialogState.initState` de `_subjectId`'yi null'a
// kuruyordu. Sayacin `selected_study_subject.<uid>` tercihi kalicilastigi halde
// manuel kaydin secimi hicbir yere yazilmiyordu.
//
// Bu dosya kullanicinin GORDUGU seyi olcer: diyalog gercekten acilir, secili
// `ChoiceChip` widget'i uzerinden okunur. Kaynakta `initialSubjectId` gecmesi
// kanit sayilmaz.
//
// Tuzak notu: her iddiadan once diyalog GOVDESININ gercek oldugu dogrulanir
// (baslik + Kaydet dugmesi + iki sayac). Bir hata kabugu da `AlertDialog`
// tipiyle eslesebilir.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/global_timer.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/data/repositories/subject_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/profile/widgets/manual_session_dialog.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

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

class _RecordingStudyRepository extends InMemoryStudyRepository {
  final List<StudySession> added = <StudySession>[];

  @override
  Future<void> addSession(StudySession session) async {
    added.add(session);
    await super.addSession(session);
  }
}

class _FlakySubjectRepository implements SubjectRepository {
  _FlakySubjectRepository(this.subjects);

  List<Subject> subjects;
  Object? error;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void emit(List<Subject> next) {
    subjects = next;
    _changes.add(null);
  }

  @override
  Future<void> addSubject(Subject subject) async {}

  @override
  Future<void> updateSubject(Subject subject) async {}

  @override
  Future<void> deleteSubject(String subjectId) async {}

  @override
  Stream<List<Subject>> watchUserSubjects(String userId) async* {
    if (error != null) throw error!;
    yield subjects.where((s) => s.userId == userId).toList();
    await for (final _ in _changes.stream) {
      if (error != null) throw error!;
      yield subjects.where((s) => s.userId == userId).toList();
    }
  }

  void dispose() => _changes.close();
}

class _OfflineError implements Exception {
  const _OfflineError();

  @override
  String toString() => 'Failed host lookup';
}

/// Diyalogu ACAN ekran. `addManualSessionFlow` gercek cagri yeriyle ayni
/// bicimde cagrilir (`WidgetRef` + `BuildContext`).
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provider'i canli tutan gercek dinleyici (Riverpod 3 auto-dispose).
    ref.watch(userSubjectsProvider);
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('wp697-open'),
          onPressed: () => addManualSessionFlow(context, ref),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Subject _subject(String id, String userId, String name) =>
    Subject(id: id, userId: userId, name: name, color: 'chart-1');

void main() {
  const userId = 'u-a';
  late SharedPreferences prefs;
  late AppLocalizations tr;

  setUpAll(() async {
    tz_data.initializeTimeZones();
    tr = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_RecordingStudyRepository> pump(
    WidgetTester tester, {
    required SubjectRepository subjects,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final study = _RecordingStudyRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              Profile(
                id: userId,
                displayName: 'Ben',
                createdAt: DateTime(2026),
              ),
            ),
          ),
          subjectRepositoryProvider.overrideWithValue(subjects),
          studyRepositoryProvider.overrideWithValue(study),
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
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _Host(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return study;
  }

  /// Diyalogun GOVDESI gercekten cizildi mi? Hata kabugu bu uc isareti birden
  /// tasiyamaz.
  void expectRealDialogBody(WidgetTester tester) {
    expect(find.text(tr.profileManuelSureEkle), findsOneWidget);
    expect(find.text(tr.profileKaydet), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNWidgets(2));
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('wp697-open')));
    await tester.pumpAndSettle();
    expectRealDialogBody(tester);
  }

  bool chipSelected(WidgetTester tester, String label) {
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byType(ChoiceChip),
    );
    expect(finder, findsOneWidget, reason: '"$label" secenegi ekranda yok');
    return tester.widget<ChoiceChip>(finder).selected;
  }

  Future<void> saveOneMinute(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add).at(1)); // dakika +1
    await tester.pump();
    await tester.tap(find.text(tr.profileKaydet));
    await tester.pumpAndSettle();
  }

  group('1 - son secilen ders hatirlanir', () {
    testWidgets('secim kaydedilir, diyalog tekrar acilinca secili gelir', (
      tester,
    ) async {
      final repo = _FlakySubjectRepository([
        _subject('math', userId, 'Matematik'),
        _subject('physics', userId, 'Fizik'),
      ]);
      addTearDown(repo.dispose);
      final study = await pump(tester, subjects: repo);

      await openDialog(tester);
      expect(chipSelected(tester, tr.profileGenel), isTrue);

      await tester.tap(find.text('Fizik'));
      await tester.pump();
      expect(chipSelected(tester, 'Fizik'), isTrue);
      await saveOneMinute(tester);
      expect(study.added.single.subjectId, 'physics');

      await openDialog(tester);
      expect(
        chipSelected(tester, 'Fizik'),
        isTrue,
        reason: 'ikinci acilis Genel\'e dusmemeli',
      );
      expect(chipSelected(tester, tr.profileGenel), isFalse);
    });

    testWidgets('uygulama yeniden acilinca da ayni ders secili', (
      tester,
    ) async {
      final repo = _FlakySubjectRepository([
        _subject('math', userId, 'Matematik'),
        _subject('physics', userId, 'Fizik'),
      ]);
      addTearDown(repo.dispose);
      await pump(tester, subjects: repo);
      await openDialog(tester);
      await tester.tap(find.text('Fizik'));
      await tester.pump();
      await saveOneMinute(tester);

      // Yeniden acilis: yepyeni ProviderScope, ayni cihaz depolamasi.
      final repo2 = _FlakySubjectRepository([
        _subject('math', userId, 'Matematik'),
        _subject('physics', userId, 'Fizik'),
      ]);
      addTearDown(repo2.dispose);
      await pump(tester, subjects: repo2);
      await openDialog(tester);
      expect(chipSelected(tester, 'Fizik'), isTrue);
    });

    testWidgets('Genel\'e donus de hatirlanir', (tester) async {
      final repo = _FlakySubjectRepository([
        _subject('math', userId, 'Matematik'),
      ]);
      addTearDown(repo.dispose);
      final study = await pump(tester, subjects: repo);

      await openDialog(tester);
      await tester.tap(find.text('Matematik'));
      await tester.pump();
      await saveOneMinute(tester);

      await openDialog(tester);
      expect(chipSelected(tester, 'Matematik'), isTrue);
      await tester.tap(find.text(tr.profileGenel));
      await tester.pump();
      await saveOneMinute(tester);
      expect(study.added.last.subjectId, isNull);

      await openDialog(tester);
      expect(chipSelected(tester, tr.profileGenel), isTrue);
      expect(chipSelected(tester, 'Matematik'), isFalse);
    });

    testWidgets('silinmis ders hatirlanmaz, Genel secili acilir', (
      tester,
    ) async {
      await prefs.setString(manualSessionSubjectKey(userId), 'deleted-subject');
      final repo = _FlakySubjectRepository([
        _subject('math', userId, 'Matematik'),
      ]);
      addTearDown(repo.dispose);
      await pump(tester, subjects: repo);

      await openDialog(tester);
      expect(chipSelected(tester, tr.profileGenel), isTrue);
      expect(chipSelected(tester, 'Matematik'), isFalse);
    });
  });

  group('2 - sayacin tercihi ayri kalir', () {
    testWidgets('manuel secim `selected_study_subject` anahtarini EZMEZ', (
      tester,
    ) async {
      await prefs.setString('selected_study_subject.$userId', 'math');
      final repo = _FlakySubjectRepository([
        _subject('math', userId, 'Matematik'),
        _subject('physics', userId, 'Fizik'),
      ]);
      addTearDown(repo.dispose);
      await pump(tester, subjects: repo);

      await openDialog(tester);
      await tester.tap(find.text('Fizik'));
      await tester.pump();
      await saveOneMinute(tester);

      expect(
        prefs.getString('selected_study_subject.$userId'),
        'math',
        reason: 'elle gecmis kaydi girmek calisan sayacin dersini degistirmez',
      );
      expect(prefs.getString(manualSessionSubjectKey(userId)), 'physics');
    });
  });

  group('3 - cevrimdisi ders secimi', () {
    testWidgets('ag yokken liste onbellekten gelir ve secilebilir', (
      tester,
    ) async {
      await prefs.setString(
        subjectsCacheKey(userId),
        jsonEncode([
          _subject('math', userId, 'Matematik').toMap(),
          _subject('physics', userId, 'Fizik').toMap(),
        ]),
      );
      final repo = _FlakySubjectRepository([])..error = const _OfflineError();
      addTearDown(repo.dispose);
      final study = await pump(tester, subjects: repo);

      await openDialog(tester);
      expect(find.text('Matematik'), findsOneWidget);
      await tester.tap(find.text('Fizik'));
      await tester.pump();
      expect(chipSelected(tester, 'Fizik'), isTrue);
      await saveOneMinute(tester);
      expect(study.added.single.subjectId, 'physics');
    });

    testWidgets('onbellek de yokken ekran sessizce bos kalmaz', (tester) async {
      final repo = _FlakySubjectRepository([])..error = const _OfflineError();
      addTearDown(repo.dispose);
      await pump(tester, subjects: repo);

      await openDialog(tester);
      expect(
        find.textContaining('Dersler yüklenemedi'),
        findsOneWidget,
        reason: 'ders bolumu yoksa sebebi yazilmali',
      );
    });
  });

  group('4 - sunucuda silinmis ders sessiz kayba yol acmaz', () {
    testWidgets('gecersiz ders Genel\'e dusurulur ve kullaniciya soylenir', (
      tester,
    ) async {
      final repo = _FlakySubjectRepository([
        _subject('math', userId, 'Matematik'),
        _subject('physics', userId, 'Fizik'),
      ]);
      addTearDown(repo.dispose);
      final study = await pump(tester, subjects: repo);

      await openDialog(tester);
      await tester.tap(find.text('Fizik'));
      await tester.pump();

      // Diyalog acikken baska cihaz `physics`i sildi.
      repo.emit([_subject('math', userId, 'Matematik')]);
      await tester.pumpAndSettle();

      await saveOneMinute(tester);
      expect(
        study.added.single.subjectId,
        isNull,
        reason: 'yabanci ders kimligi sunucuda FK ihlali olur, kayit dusurulur',
      );
      expect(find.text(tr.studySelectedSubjectUnavailable), findsOneWidget);
    });
  });
}
