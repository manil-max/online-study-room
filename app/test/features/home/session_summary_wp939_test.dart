// WP-939 — seans bitince kısa özet.
//
// Kullanıcı sayacı uygulama içinden durdurduğunda hiçbir şey görünmüyordu.
// Özet, oturum KAYDEDİLDİYSE ve durdurma uygulama içi Durdur'dan geldiyse
// açılır. Bu dosya:
//   * normal durdurmada özetin doğru sayılarla açıldığını (ana sayfa kartlarıyla
//     aynı kaynaklar: `todayDisplayTotalFor`, `dailyGoalMinutesProvider`,
//     kanonik seri projeksiyonu),
//   * kayıt yoksa (süre 0 / mola), bildirimden durdurmada, ayar kapalıyken ve
//     kazara yeniden başlatma korumasında AÇILMADIĞINI,
//   * hedef kutlamasıyla üst üste binmediğini (kutlama önce, özet sonra),
//   * 320×568 + metin ölçeği 1.3 + TR/EN + açık/koyu temada taşmadığını
// ölçer.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/navigation/nav_index.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/core/theme/motion_tokens.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/focus_timer_screen.dart';
import 'package:online_study_room/features/home/widgets/goal_card.dart';
import 'package:online_study_room/features/notifications/notification_center_screen.dart';
import 'package:online_study_room/features/session_summary/session_summary_preference.dart';
import 'package:online_study_room/features/session_summary/session_summary_sheet.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../support/istanbul_fixture.dart';

const _userId = 'u1';
const _goalMinutes = 240; // 4 sa
const _goalSeconds = _goalMinutes * 60;
const _sessionSeconds = 47 * 60;
const _subject = Subject(
  id: 'math',
  userId: _userId,
  name: 'Matematik',
  color: 'chart-1',
);

/// Sayacın gerçek `stop()`'unun kayıt yolunda bıraktığı iz: WP-250 settling*.
StudyTimerState _savedAfter(StudyTimerState before, {int? baseline}) =>
    StudyTimerState(
      settlingSeconds: _sessionSeconds,
      settlingBaseline: baseline ?? 0,
      settlingDay: dayOf(before.startedAt!),
    );

/// Gerçek notifier'ın `build()`'i kanal/dinleyici kurar; sahte yalnız state'i
/// sürer. Ölçülen şey özetin KARARI ve yüzeyin kablosudur.
class _FakeTimer extends StudyTimerNotifier {
  _FakeTimer(this._initial, this._afterStop);

  final StudyTimerState _initial;
  final StudyTimerState Function(StudyTimerState before) _afterStop;
  var stopCalls = 0;
  var startCalls = 0;

  @override
  StudyTimerState build() => _initial;

  @override
  Future<void> stop({DateTime? at, String trigger = 'user_button'}) async {
    stopCalls++;
    state = _afterStop(state);
  }

  /// Kazara yeniden başlatma koruması (WP-598): Başlat reddedilir, açıklama
  /// sinyali yakılır, sayaç durmuş kalır.
  @override
  void start({
    bool guardAccidentalRestart = true,
    String trigger = 'user_button',
  }) {
    startCalls++;
    ref.read(accidentalRestartNoticeProvider.notifier).show();
  }
}

StudyTimerState _running({
  Duration ago = const Duration(minutes: 47),
  TimerPhase phase = TimerPhase.work,
}) => StudyTimerState(
  isRunning: true,
  startedAt: DateTime.now().subtract(backWithinIstanbulToday(ago)),
  subjectId: _subject.id,
  phase: phase,
);

StudySession _session(String id, int seconds) => StudySession(
  id: id,
  userId: _userId,
  start: DateTime.now(),
  end: DateTime.now(),
  durationSeconds: seconds,
  source: StudySource.live,
);

GoalStreakProjection _streak(int days) => GoalStreakProjection(
  scope: const GoalStreakScope.personal(_userId),
  asOfDay: DateTime.utc(2026, 10, 7),
  currentStreak: days,
  completionCount: days,
  state: GoalStreakState.completedToday,
  sourceVersion: 'test',
);

List<String> _recordHaptics(WidgetTester tester) {
  final seen = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        seen.add((call.arguments as String?) ?? 'default');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return seen;
}

/// Uygulama içi Durdur düğmesini temsil eden en küçük yüzey: GERÇEK
/// [stopTimerFromSurface] çağrılır (kart ile odak ekranının ortak yolu).
class _StopHost extends ConsumerWidget {
  const _StopHost({this.withGoalCard = false});

  final bool withGoalCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(studyTimerProvider);
    return Scaffold(
      body: Column(
        children: [
          if (withGoalCard)
            const SizedBox(width: 300, height: 240, child: GoalCard()),
          FilledButton(
            key: const Key('host-stop'),
            onPressed: () => stopTimerFromSurface(context, ref),
            child: const Text('stop'),
          ),
        ],
      ),
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _FakeTimer timer, {
  Widget home = const _StopHost(),
  List<StudySession>? sessions,
  bool? summaryEnabled,
  Locale locale = const Locale('tr'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'timer_background_hint_seen': true,
    kSessionSummaryEnabledKey: ?summaryEnabled,
  });
  final prefs = await SharedPreferences.getInstance();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authStateProvider.overrideWith(
      (ref) => Stream<Profile?>.value(
        Profile(
          id: _userId,
          displayName: 'Ali',
          createdAt: DateTime.utc(2026),
          dailyGoalMinutes: _goalMinutes,
        ),
      ),
    ),
    userSessionsProvider.overrideWith(
      (_) => Stream.value(
        sessions ?? <StudySession>[_session('s0', 2 * 3600 + 35 * 60)],
      ),
    ),
    userSubjectsProvider.overrideWith(
      (_) => Stream.value(const <Subject>[_subject]),
    ),
    dailyGoalMinutesProvider.overrideWithValue(_goalMinutes),
    userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
    goalStreakProjectionProvider(
      const GoalStreakScope.personal(_userId),
    ).overrideWith((ref) => Stream.value(_streak(11))),
    studyTimerProvider.overrideWith(() => timer),
  ];
  // `ProviderScope` (UncontrolledProviderScope değil): ağaç kapanınca kapsam da
  // kapanır, sağlayıcıların gün dönümü zamanlayıcıları askıda kalmaz.
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  // Akışlar (auth, oturumlar, dersler, seri) ilk karede değer yayar.
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> _tapStop(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('host-stop')));
  await tester.pumpAndSettle();
}

final _summary = find.byKey(const Key('session-summary'));

void main() {
  group('sessionSummarySeconds (saf karar)', () {
    final before = _running();

    test('kayıt yolu: settling süresi döner', () {
      expect(
        sessionSummarySeconds(before: before, after: _savedAfter(before)),
        _sessionSeconds,
      );
    });

    test('süre 0 / kaydedilmeyen oturum: null', () {
      expect(
        sessionSummarySeconds(before: before, after: const StudyTimerState()),
        isNull,
      );
    });

    test('mola fazında durdurma: null', () {
      final rest = _running(phase: TimerPhase.rest);
      expect(
        sessionSummarySeconds(before: rest, after: _savedAfter(rest)),
        isNull,
      );
    });

    test('ayna koşusu: null (bu cihazda oturum yazılmaz)', () {
      final mirror = StudyTimerState(
        isRunning: true,
        startedAt: before.startedAt,
        isGlobalTimerMirror: true,
      );
      expect(
        sessionSummarySeconds(before: mirror, after: _savedAfter(mirror)),
        isNull,
      );
    });

    test('durdurma reddedildi (hâlâ çalışıyor): null', () {
      expect(sessionSummarySeconds(before: before, after: before), isNull);
    });

    test('sayaç zaten durmuştu: null', () {
      expect(
        sessionSummarySeconds(
          before: const StudyTimerState(),
          after: const StudyTimerState(),
        ),
        isNull,
      );
    });
  });

  testWidgets('normal Durdur: özet doğru sayılarla açılır (TR)', (
    tester,
  ) async {
    final timer = _FakeTimer(
      _running(),
      (b) => _savedAfter(b, baseline: 2 * 3600 + 35 * 60),
    );
    final container = await _pump(tester, timer);

    expect(_summary, findsNothing);
    await _tapStop(tester);

    expect(timer.stopCalls, 1);
    expect(_summary, findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('47dk Matematik kaydedildi'), findsOneWidget);
    // 2sa 35dk kayıtlı + 47dk = 3sa 22dk; 12120 / 14400 = %84 (hedef kartıyla
    // aynı yuvarlama).
    expect(find.text('Günlük hedef: %84 (3sa 22dk / 4sa)'), findsOneWidget);
    expect(find.text('Seri: 11 gün'), findsOneWidget);
    expect(find.text('Tamam'), findsOneWidget);
    expect(find.text('İstatistiğe git'), findsOneWidget);

    // Aynı sayı ana sayfa kartlarının kaynağından: sapma olmamalı.
    final cardTotal = container.read(todayLiveTotalProvider)!.seconds;
    expect(cardTotal, 2 * 3600 + 35 * 60 + _sessionSeconds);

    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(_summary, findsNothing);
  });

  testWidgets('EN: aynı özet İngilizce, hedef tamamsa "Goal complete"', (
    tester,
  ) async {
    final timer = _FakeTimer(
      _running(),
      (b) => _savedAfter(b, baseline: 4 * 3600),
    );
    await _pump(
      tester,
      timer,
      locale: const Locale('en'),
      sessions: [_session('s0', 4 * 3600)],
    );
    await _tapStop(tester);

    expect(find.text('47m of Matematik saved'), findsOneWidget);
    expect(find.text('Goal complete! 🎉 (4h 47m / 4h)'), findsOneWidget);
    expect(find.text('Streak: 11 days'), findsOneWidget);
    expect(find.text('Go to stats'), findsOneWidget);
  });

  testWidgets('"İstatistiğe git" İstatistik sekmesini açar', (tester) async {
    final timer = _FakeTimer(_running(), (b) => _savedAfter(b));
    final container = await _pump(tester, timer);
    expect(container.read(navIndexProvider), AppTab.home.index);

    await _tapStop(tester);
    await tester.tap(find.text('İstatistiğe git'));
    await tester.pumpAndSettle();

    expect(_summary, findsNothing);
    expect(container.read(navIndexProvider), AppTab.stats.index);
  });

  testWidgets('kaydedilmeyen kısa oturum (süre 0): özet AÇILMAZ', (
    tester,
  ) async {
    final timer = _FakeTimer(
      _running(ago: const Duration(seconds: 1)),
      (_) => const StudyTimerState(),
    );
    await _pump(tester, timer);
    await _tapStop(tester);

    expect(timer.stopCalls, 1);
    expect(_summary, findsNothing);
  });

  testWidgets('mola fazında Durdur: özet AÇILMAZ', (tester) async {
    final timer = _FakeTimer(
      _running(phase: TimerPhase.rest),
      (_) => const StudyTimerState(),
    );
    await _pump(tester, timer);
    await _tapStop(tester);

    expect(timer.stopCalls, 1);
    expect(_summary, findsNothing);
  });

  testWidgets('bildirimden durdurma (yüzey dışı yol): özet AÇILMAZ', (
    tester,
  ) async {
    final timer = _FakeTimer(_running(), (b) => _savedAfter(b));
    final container = await _pump(tester, timer);

    // Bildirim/widget/rutin durdurması notifier'a doğrudan gelir; oturum yine
    // kaydedilir ama kullanıcı uygulamada değildir.
    await container
        .read(studyTimerProvider.notifier)
        .stop(trigger: 'notification_button');
    await tester.pumpAndSettle();

    expect(container.read(studyTimerProvider).settlingSeconds, _sessionSeconds);
    expect(_summary, findsNothing);
  });

  testWidgets('ayar kapalıyken özet AÇILMAZ', (tester) async {
    final timer = _FakeTimer(_running(), (b) => _savedAfter(b));
    final container = await _pump(tester, timer, summaryEnabled: false);
    expect(container.read(sessionSummaryEnabledProvider), isFalse);

    await _tapStop(tester);
    expect(timer.stopCalls, 1);
    expect(_summary, findsNothing);
  });

  test('ayar varsayılanı AÇIK', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(sessionSummaryEnabledProvider), isTrue);
    await container
        .read(sessionSummaryEnabledProvider.notifier)
        .setEnabled(false);
    expect(prefs.getBool(kSessionSummaryEnabledKey), isFalse);
  });

  testWidgets('Bildirim Merkezi anahtarı tercihi yazar (varsayılan açık)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(
            (ref) => Stream<Profile?>.value(
              Profile(
                id: _userId,
                displayName: 'Ali',
                createdAt: DateTime.utc(2026),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationCenterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('notification_session_summary_switch'));
    expect(find.text('Seans sonu özeti göster'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(prefs.getBool(kSessionSummaryEnabledKey), isFalse);
  });

  testWidgets(
    'odak ekranı: Durdur özeti açar; ardından kazara yeniden başlatma '
    'koruması özeti TEKRAR açmaz',
    (tester) async {
      final timer = _FakeTimer(_running(), (b) => _savedAfter(b));
      await _pump(tester, timer, home: const FocusTimerScreen());

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();
      expect(_summary, findsOneWidget);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(_summary, findsNothing);

      // Durdurduktan hemen sonra Başlat: koruma reddeder ve açıklar.
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump();
      expect(timer.startCalls, 1);
      expect(
        find.text(
          'Az önce durdurdun; sayaç yeniden başlatılmadı. Yeni bir oturum '
          'başlatmak istiyorsan tekrar dokun.',
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(_summary, findsNothing);
      // Odak ekranının saniyelik zamanlayıcısı test sonunda askıda kalmasın.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('masaüstünde özet diyalog olarak açılır', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final timer = _FakeTimer(_running(), (b) => _savedAfter(b));
      await _pump(tester, timer);
      await _tapStop(tester);

      expect(_summary, findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'hedef kutlamasıyla ÜST ÜSTE BİNMEZ: kutlama önce, özet sonra; özet '
    'ikinci bir titreşim üretmez',
    (tester) async {
      final haptics = _recordHaptics(tester);
      // Kayıtlı 3sa 50dk; koşu 5 sn → durdurmadan ÖNCE toplam hedefin altında.
      const recorded = _goalSeconds - 600;
      final timer = _FakeTimer(
        _running(ago: const Duration(seconds: 5)),
        (b) => _savedAfter(b, baseline: recorded),
      );
      await _pump(
        tester,
        timer,
        home: const _StopHost(withGoalCard: true),
        sessions: [_session('s0', recorded)],
      );
      expect(find.byType(GoalCard), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(haptics, isEmpty);

      await tester.tap(find.byKey(const Key('host-stop')));
      await tester.pump();
      await tester.pump();

      // Durdurma eşiği geçirdi: kart kutluyor (✓ + titreşim), özet HENÜZ yok.
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(
        haptics.length,
        2,
        reason: 'Durdur darbesi + kutlama darbesi; başka bir şey değil.',
      );
      expect(
        _summary,
        findsNothing,
        reason: 'Özet kutlama oynarken üstüne açılmamalı.',
      );

      await tester.pump(MotionTokens.celebration);
      await tester.pumpAndSettle();
      expect(_summary, findsOneWidget);
      expect(find.textContaining('Hedef tamam! 🎉'), findsOneWidget);
      expect(
        haptics.length,
        2,
        reason: 'Özet ikinci bir kutlama (titreşim) oynatmaz.',
      );
    },
  );

  group('taşma yok: 320×568, metin ölçeği 1.3', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('${locale.languageCode} / ${mode.name}', (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final timer = _FakeTimer(
            _running(),
            (b) => _savedAfter(b, baseline: 2 * 3600 + 35 * 60),
          );
          await _pump(
            tester,
            timer,
            locale: locale,
            themeMode: mode,
            textScale: 1.3,
          );
          await _tapStop(tester);

          expect(_summary, findsOneWidget);
          expect(tester.takeException(), isNull);
          // Düğmeler ekranda ve dokunulabilir.
          for (final key in const [
            'session-summary-ok',
            'session-summary-stats',
          ]) {
            final rect = tester.getRect(find.byKey(Key(key)));
            expect(rect.right, lessThanOrEqualTo(320));
            expect(rect.bottom, lessThanOrEqualTo(568));
          }
        });
      }
    }
  });
}
