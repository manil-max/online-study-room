// WP-856 — aynı ekranda iki farklı "bugün" gerçeği.
//
// Mağaza karesinde ölçüldü (sayaç 47 dk çalışıyor, kayıt 2sa 35dk, hedef 4sa):
// sayaç kartı "%84 — 3sa 22dk", aynı ekrandaki günlük hedef kartı
// "%65 — 2sa 35dk", bugünün özeti "2sa 35dk". Kullanıcı hangisinin doğru
// olduğunu bilemiyordu.
//
// Ölçütler: üç kart AYNI toplamı/yüzdeyi gösterir; Durdur akışı boyunca
// (durduruluyor → durdu → kayıt yerleşti) hiçbir karede daha düşük bir sayı
// görünmez (WP-250); yükleme/hata kapıları değişmez (WP-817); canlı kısımla
// eşik geçilince kutlama BİR kez oynar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/home/widgets/card_data_gate.dart';
import 'package:online_study_room/features/home/widgets/goal_card.dart';
import 'package:online_study_room/features/home/widgets/today_summary_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/istanbul_fixture.dart';

const _goalMinutes = 240;
const _goalSeconds = _goalMinutes * 60;

/// Mağaza karesindeki kayıt: 2sa 35dk.
const _recorded = 2 * 3600 + 35 * 60;

class _PushTimer extends StudyTimerNotifier {
  _PushTimer(this._initial);

  final StudyTimerState _initial;

  /// Gerçek notifier gibi: doğduğunda canlı "bugün" sağlayıcısını bir kez
  /// yeniden hesaplatır (sağlayıcı sayacı kendisi kurmaz, yalnız varsa izler).
  @override
  StudyTimerState build() {
    scheduleMicrotask(() => ref.invalidate(todayLiveTotalProvider));
    return _initial;
  }

  void push(StudyTimerState next) => state = next;
}

StudySession _session(String id, int seconds) => StudySession(
  id: id,
  userId: 'u1',
  start: DateTime.now(),
  end: DateTime.now(),
  durationSeconds: seconds,
  source: StudySource.live,
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

/// Canlı koşunun başlangıcı: toplam dakikanın TAM ORTASINA (…:30) düşsün diye
/// ayarlanır. Kartlar aynı karede ama birkaç ms arayla "şimdi"yi okur; dakika
/// sınırının dibinde kurulan bir test, kodu değil saati ölçerdi. Geriye gidiş
/// İstanbul gününün içinde kalır (v49 dersi).
DateTime _startedAtForMidMinute(Duration desired) {
  final now = DateTime.now();
  var back = backWithinIstanbulToday(desired, now: now).inSeconds;
  back -= (_recorded + back - 30) % 60;
  if (back < 0) back = 0;
  return now.subtract(Duration(seconds: back));
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Stream<List<StudySession>> sessions,
  required _PushTimer timer,
  bool withTimerCard = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(420, 1700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream<Profile?>.value(null)),
        userSessionsProvider.overrideWith((ref) => sessions),
        userSubjectsProvider.overrideWith(
          (_) => Stream.value(const <Subject>[]),
        ),
        dailyGoalMinutesProvider.overrideWithValue(_goalMinutes),
        userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
        studyTimerProvider.overrideWith(() => timer),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              if (withTimerCard)
                const SizedBox(
                  width: 400,
                  height: 900,
                  child: StudyTimerCard(),
                ),
              const SizedBox(width: 400, height: 320, child: GoalCard()),
              const SizedBox(
                width: 400,
                height: 300,
                child: TodaySummaryCard(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(GoalCard)),
  );
  // Uygulamada sayaç kabuk/sayaç yüzeyleri tarafından kurulur; sayaç kartı
  // olmayan düzende bunu test yapar.
  container.read(studyTimerProvider);
  await tester.pump();
  return container;
}

/// Akış olayı + yeniden çizim + sayı animasyonunun bitişi. Sayaç kartının
/// saniyelik ticker'ı çalıştığı için `pumpAndSettle` yerine sınırlı adım.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

int _pct(int total) => ((total / _goalSeconds).clamp(0.0, 1.0) * 100).round();

Finder _goalLine(int total) =>
    find.text('${formatHuman(total)} / ${formatHuman(_goalSeconds)}');

void main() {
  setUp(() => setActiveAppLocale(const Locale('tr')));

  testWidgets('sayaç çalışırken üç kart aynı toplamı ve yüzdeyi gösterir', (
    tester,
  ) async {
    final startedAt = _startedAtForMidMinute(
      const Duration(minutes: 47, seconds: 30),
    );
    final timer = _PushTimer(
      StudyTimerState(isRunning: true, startedAt: startedAt),
    );
    final container = await _pump(
      tester,
      sessions: Stream.value([_session('r1', _recorded)]),
      timer: timer,
    );
    await _settle(tester);

    final live = container.read(todayLiveTotalProvider)!.seconds;
    expect(
      live,
      greaterThan(_recorded),
      reason: 'Canlı koşu toplamın içinde olmalı; yoksa eski %65 hatası.',
    );
    final pct = _pct(live);
    // Sayaç kartının hedef çubuğu + günlük hedef halkası: aynı yüzde.
    expect(find.text('%$pct'), findsNWidgets(2));
    expect(
      find.text('%${_pct(_recorded)}'),
      findsNothing,
      reason: 'Yalnız kaydı gösteren eski yüzde ekranda kalmamalı.',
    );
    // Günlük hedef: "3sa 22dk / 4sa" ve kalan buna göre.
    expect(_goalLine(live), findsOneWidget);
    expect(
      find.text('Hedefe kalan: ${formatHuman(_goalSeconds - live)}'),
      findsOneWidget,
    );
    // Bugünün özeti başlığı aynı sayı.
    expect(
      find.descendant(
        of: find.byType(TodaySummaryCard),
        matching: find.text(formatHuman(live)),
      ),
      findsWidgets,
    );
    // Sayaç kartı aynı toplamı saniyeli yazar (aynı kare, ±1 sn).
    final timerTexts = {
      for (var s = live - 1; s <= live + 1; s++) formatHumanSeconds(s),
    };
    expect(
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(StudyTimerCard),
              matching: find.byType(Text),
            ),
          )
          .any((t) => timerTexts.contains(t.data)),
      isTrue,
    );
    // Ders dağılımı başlığı yalanlamaz: kaydedilmemiş kısım sayacın dersine
    // (burada derssiz/Genel) eklenir.
    expect(
      find.descendant(
        of: find.byType(TodaySummaryCard),
        matching: find.text(formatHuman(live)),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('Durdur akışı boyunca kartlar eşit kalır, düşük sayı görünmez', (
    tester,
  ) async {
    final startedAt = _startedAtForMidMinute(
      const Duration(minutes: 47, seconds: 30),
    );
    final timer = _PushTimer(
      StudyTimerState(isRunning: true, startedAt: startedAt),
    );
    final sessions = StreamController<List<StudySession>>();
    addTearDown(sessions.close);
    final container = await _pump(
      tester,
      sessions: sessions.stream,
      timer: timer,
    );
    sessions.add([_session('r1', _recorded)]);
    await _settle(tester);

    final before = container.read(todayLiveTotalProvider)!.seconds;
    void expectStill(String step) {
      final now = container.read(todayLiveTotalProvider)!.seconds;
      expect(now, greaterThanOrEqualTo(before), reason: '$step: düştü');
      expect(_goalLine(before), findsOneWidget, reason: step);
      expect(find.text('%${_pct(before)}'), findsNWidgets(2), reason: step);
      expect(
        find.descendant(
          of: find.byType(TodaySummaryCard),
          matching: find.text(formatHuman(before)),
        ),
        findsWidgets,
        reason: step,
      );
    }

    // 1) Durduruluyor: canlı akış kesilir, aralık settling ile taşınır.
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final day = dayOf(DateTime.now());
    timer.push(
      StudyTimerState(
        isRunning: true,
        isStopping: true,
        startedAt: startedAt,
        settlingSeconds: elapsed,
        settlingBaseline: _recorded,
        settlingDay: day,
      ),
    );
    await tester.pump();
    expectStill('durduruluyor (ilk kare)');
    await _settle(tester);
    expectStill('durduruluyor');

    // 2) Durdu, kayıt henüz listeye yansımadı.
    timer.push(
      StudyTimerState(
        settlingSeconds: elapsed,
        settlingBaseline: _recorded,
        settlingDay: day,
      ),
    );
    await tester.pump();
    expectStill('durdu (ilk kare)');
    await _settle(tester);
    expectStill('durdu');

    // 3) Kayıt yerleşti.
    sessions.add([_session('r1', _recorded), _session('r2', elapsed)]);
    await tester.pump();
    expectStill('yerleşti (ilk kare)');
    await _settle(tester);
    expectStill('yerleşti');
  });

  testWidgets('oturumlar yüklenirken canlı koşu sahte sayı üretmez', (
    tester,
  ) async {
    final never = StreamController<List<StudySession>>();
    addTearDown(never.close);
    final container = await _pump(
      tester,
      sessions: never.stream,
      timer: _PushTimer(
        StudyTimerState(
          isRunning: true,
          startedAt: DateTime.now().subtract(const Duration(minutes: 47)),
        ),
      ),
      withTimerCard: false,
    );
    await _settle(tester);

    expect(container.read(todayLiveTotalProvider), isNull);
    expect(find.byKey(kCardSkeletonKey), findsNWidgets(2));
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('oturum akışı hatadayken kartlar hata kapısında kalır', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      sessions: Stream.error(Exception('ağ')),
      timer: _PushTimer(
        StudyTimerState(
          isRunning: true,
          startedAt: DateTime.now().subtract(const Duration(minutes: 47)),
        ),
      ),
      withTimerCard: false,
    );
    await _settle(tester);

    expect(container.read(todayLiveTotalProvider), isNull);
    expect(find.text('Veriler yüklenemedi.'), findsNWidgets(2));
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('canlı kısımla eşik geçilince kutlama BİR kez oynar', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    final timer = _PushTimer(const StudyTimerState());
    final container = await _pump(
      tester,
      // Hedefin 10 dk altı kayıtlı.
      sessions: Stream.value([_session('r1', _goalSeconds - 600)]),
      timer: timer,
      withTimerCard: false,
    );
    await _settle(tester);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(haptics, isEmpty);

    // Sayaç başladı; 15 dk'lık canlı kısım eşiği aşıyor.
    timer.push(
      StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(
          backWithinIstanbulToday(const Duration(minutes: 15)),
        ),
      ),
    );
    await _settle(tester);
    expect(
      container.read(todayLiveTotalProvider)!.seconds,
      greaterThanOrEqualTo(_goalSeconds),
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);

    // Hedef üstünde sağlayıcı birkaç kez yenilenir (gerçek saat ilerlesin ki
    // değer gerçekten değişsin): kutlama tekrar OYNAMAZ.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
    }
    expect(haptics, hasLength(1), reason: 'Her yenilemede kutlama olmaz.');
  });

  testWidgets('eşik sayaç çalışırken ZAMANLA geçilirse de bir kez kutlanır', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    // Hedefin 2 sn altı kayıtlı, sayaç şimdi başladı: eşiği olay değil
    // sağlayıcının kendi yenilemesi geçirecek (kalan < 60 sn → saniyelik).
    final timer = _PushTimer(
      StudyTimerState(isRunning: true, startedAt: DateTime.now()),
    );
    final container = await _pump(
      tester,
      sessions: Stream.value([_session('r1', _goalSeconds - 2)]),
      timer: timer,
      withTimerCard: false,
    );
    await _settle(tester);
    expect(
      container.read(todayLiveTotalProvider)!.seconds,
      lessThan(_goalSeconds),
    );
    expect(haptics, isEmpty);

    // Gerçek saat 3 sn ilerlesin; sahte zamanda sağlayıcının zamanlayıcısı
    // her pump'ta tetiklenir.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }
    expect(
      container.read(todayLiveTotalProvider)!.seconds,
      greaterThanOrEqualTo(_goalSeconds),
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });
}
