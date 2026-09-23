import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-927: istatistik "bugün"ü, Ana Sayfa ile aynı canlı toplamı kullanır.
///
/// 🔴 Kusur (UX denetimi `s01` / `s06`, mağaza karesi): sayaç 47 dk
/// çalışırken Ana Sayfa "3sa 22dk · %84" (WP-856: kayıt + süregelen koşu,
/// [todayLiveTotalProvider]) yazıyordu; aynı anda İstatistik → Gün "Toplam
/// 2sa 35dk", "Hedef durumu %65" (yalnız kayıtlı oturumlar). Kullanıcı hangi
/// sayının doğru olduğunu bilemiyordu — WP-856'nın Ana Sayfa'da kapattığı
/// çelişkinin istatistik ekranındaki eşi.
///
/// Saat enjekte edilir: 23 Eylül 2026 (Çarşamba) 12:00 İstanbul.
final _now = DateTime.utc(2026, 9, 23, 9);
const _userId = 'u1';
const _recorded = 2 * 3600 + 35 * 60; // 2sa 35dk
const _live = 47 * 60; // sayaçta süregelen, henüz kaydedilmemiş
const _goalMinutes = 240;

List<StudySession> _sessions() => [
  // Bugün (23 Eyl) 2sa 35dk kayıtlı.
  StudySession(
    id: 'today',
    userId: _userId,
    subjectId: 'mat',
    start: DateTime.utc(2026, 9, 23, 5),
    end: DateTime.utc(2026, 9, 23, 5).add(const Duration(seconds: _recorded)),
    durationSeconds: _recorded,
    source: StudySource.manual,
    recordedDay: DateTime(2026, 9, 23),
  ),
  // Dün (22 Eyl) 1 saat.
  StudySession(
    id: 'yesterday',
    userId: _userId,
    subjectId: 'mat',
    start: DateTime.utc(2026, 9, 22, 7),
    end: DateTime.utc(2026, 9, 22, 8),
    durationSeconds: 3600,
    source: StudySource.manual,
    recordedDay: DateTime(2026, 9, 22),
  ),
];

class _StaticStudyTimer extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

Future<void> _pump(
  WidgetTester tester,
  StatsPeriod period, {
  int offset = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSubjectsProvider.overrideWith(
        (ref) => Stream.value(const <Subject>[
          Subject(id: 'mat', userId: _userId, name: 'Mat', color: 'chart-1'),
        ]),
      ),
      dailyGoalMinutesProvider.overrideWithValue(_goalMinutes),
      // Uygulamada sayaç kartı açılışta sayacı kurar; burada durağan bir eşi.
      studyTimerProvider.overrideWith(_StaticStudyTimer.new),
      // Sayaç kartıyla aynı kaynak (WP-856): kayıt + canlı koşu.
      todayLiveTotalProvider.overrideWithValue((
        seconds: _recorded + _live,
        unrecordedSeconds: _live,
        subjectId: 'mat',
      )),
    ],
  );
  addTearDown(container.dispose);
  final notifier = container.read(statsPeriodProvider.notifier);
  notifier.setPeriod(period);
  if (offset != 0) notifier.shift(offset);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(statsPeriodProvider);
              ref.watch(studyTimerProvider);
              return PersonalStatsView(
                sessions: _sessions(),
                clock: () => _now,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('"Gün" (bugün): Toplam ve Hedef durumu süregelen koşuyu sayar '
      '(Ana Sayfa ile aynı: 3sa 22dk, %84)', (tester) async {
    await _pump(tester, StatsPeriod.day);
    expect(find.text(formatHuman(_recorded + _live)), findsOneWidget);
    expect(find.text('%84'), findsOneWidget);
    expect(find.text('%65'), findsNothing);
  });

  testWidgets('"Hafta" (bu hafta): Toplam ve Hafta içi canlı koşuyu içerir', (
    tester,
  ) async {
    await _pump(tester, StatsPeriod.week);
    // 22 Eyl 1sa + 23 Eyl 2sa 35dk kayıtlı + 47 dk canlı; ikisi de hafta içi.
    final expected = formatHuman(3600 + _recorded + _live);
    // Toplam + Hafta içi + "Seçili hafta vs önceki" kartındaki "Bu hafta".
    // (WP-927 ilk hâlinde kıyas kartı canlıyı saymıyordu: aynı ekranda
    // "Toplam 14sa 46dk" ile "Bu hafta 13sa 59dk" yan yana çıktı.)
    await tester.scrollUntilVisible(
      find.text(expected).last,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(expected), findsNWidgets(3));
  });

  testWidgets('geçmiş gün (dün): canlı koşu EKLENMEZ', (tester) async {
    await _pump(tester, StatsPeriod.day, offset: -1);
    // Dün 1 saat / 4 saat hedef = %25; canlı eklenseydi %45 olurdu.
    expect(find.text('%25'), findsOneWidget);
    expect(find.text('%45'), findsNothing);
    expect(find.text(formatHuman(3600 + _live)), findsNothing);
  });
}
