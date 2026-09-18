// WP-856 — "bugün, süregelen koşu DAHİL" tek kaynağı.
//
// Mağaza karesinde aynı ekranda sayaç kartı "%84 — 3sa 22dk", günlük hedef
// kartı "%65 — 2sa 35dk" yazıyordu: biri canlı koşuyu ekliyor, öteki yalnız
// kaydı okuyordu. Bu dosya kuralın kendisini (sağlayıcı + yenileme ritmi)
// ölçer; kartlar `test/features/home/today_live_total_wp856_test.dart`da.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/study_providers.dart';

class _FixedTimer extends StudyTimerNotifier {
  _FixedTimer(this._initial);

  final StudyTimerState _initial;

  @override
  StudyTimerState build() => _initial;
}

StudySession _today(int seconds) => StudySession(
  id: 'r1',
  userId: 'u1',
  start: DateTime.now(),
  end: DateTime.now(),
  durationSeconds: seconds,
  source: StudySource.live,
);

ProviderContainer _container({
  required Stream<List<StudySession>> sessions,
  required StudyTimerState timer,
}) {
  final c = ProviderContainer(
    overrides: [
      userSessionsProvider.overrideWith((ref) => sessions),
      dailyGoalMinutesProvider.overrideWithValue(240),
      studyTimerProvider.overrideWith(() => _FixedTimer(timer)),
    ],
  );
  addTearDown(c.dispose);
  // Sağlayıcı sayacı kendisi KURMAZ, yalnız varsa izler; uygulamada sayacı
  // kabuk/sayaç yüzeyleri kurar.
  c.read(studyTimerProvider);
  // Riverpod 3 dinleyicisiz sağlayıcıyı duraklatır; kartlar gibi dinle.
  final sub = c.listen(todayLiveTotalProvider, (_, _) {});
  addTearDown(sub.close);
  return c;
}

void main() {
  group('secondsUntilTodayDisplayChange (yenileme ritmi)', () {
    test('dakika sınırına kadar bekler; saniyede bir değil', () {
      // 3sa 22dk 30sn, hedef yok: bir sonraki dakikaya 30 sn.
      expect(
        secondsUntilTodayDisplayChange(totalSeconds: 12150, goalSeconds: 0),
        30,
      );
    });

    test('1 dk altında "45sn" gösterildiği için saniyelik', () {
      expect(
        secondsUntilTodayDisplayChange(totalSeconds: 45, goalSeconds: 0),
        1,
      );
    });

    test('yüzde sınırını kaçırmaz (%84 → %85 = 12168 sn, hedef 4 sa)', () {
      // 12150 sn = %84.375; round %85'e 12168 sn'de (%84.5) geçer.
      expect(
        secondsUntilTodayDisplayChange(totalSeconds: 12150, goalSeconds: 14400),
        18,
      );
    });

    test('hedef eşiği tam saniyesinde yenilenir (kutlama gecikmez)', () {
      expect(
        secondsUntilTodayDisplayChange(
          totalSeconds: 14400 - 7,
          goalSeconds: 14400,
        ),
        1, // "Hedefe kalan: 7sn" saniyelik biçimde
      );
      expect(
        secondsUntilTodayDisplayChange(
          totalSeconds: 14400 - 70,
          goalSeconds: 14400,
        ),
        lessThanOrEqualTo(70),
      );
    });

    test('her girdi için 1..60 aralığında kalır', () {
      for (var t = 0; t < 20000; t += 7) {
        final s = secondsUntilTodayDisplayChange(
          totalSeconds: t,
          goalSeconds: 14400,
        );
        expect(s, inInclusiveRange(1, 60), reason: 'total=$t');
      }
    });

    test(
      'sınır gerçekten gösterilen metni/yüzdeyi değiştirir; öncesi değil',
      () {
        String shown(int t) =>
            '${formatHumanTr(t)}|${formatHumanTr(14400 - t)}|'
            '${(((t / 14400).clamp(0.0, 1.0)) * 100).round()}';
        for (var t = 0; t < 14400; t += 13) {
          final step = secondsUntilTodayDisplayChange(
            totalSeconds: t,
            goalSeconds: 14400,
          );
          for (var d = 1; d < step; d++) {
            expect(shown(t + d), shown(t), reason: 't=$t d=$d kaçırıldı');
          }
        }
      },
    );
  });

  group('todayLiveTotalProvider', () {
    test('sayaç çalışırken kayıt + canlı çalışma = sayaç kartının kuralı', () {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 47));
      final timer = StudyTimerState(isRunning: true, startedAt: startedAt);
      final c = _container(
        sessions: Stream.value([_today(9300)]),
        timer: timer,
      );
      return c.read(userSessionsProvider.future).then((_) {
        final live = c.read(todayLiveTotalProvider)!;
        final expected = todayDisplayTotalFor(
          recordedToday: 9300,
          timer: timer,
          now: DateTime.now(),
        );
        expect((live.seconds - expected).abs(), lessThanOrEqualTo(1));
        expect(live.unrecordedSeconds, live.seconds - 9300);
      });
    });

    test('oturumlar YÜKLENİRKEN null: canlı kısım sahte sayı üretmez', () {
      final never = StreamController<List<StudySession>>();
      addTearDown(never.close);
      final c = _container(
        sessions: never.stream,
        timer: StudyTimerState(
          isRunning: true,
          startedAt: DateTime.now().subtract(const Duration(minutes: 47)),
        ),
      );
      expect(c.read(todayLiveTotalProvider), isNull);
    });

    test('oturum akışı HATADA null', () async {
      final c = _container(
        sessions: Stream.error(Exception('ağ')),
        timer: StudyTimerState(
          isRunning: true,
          startedAt: DateTime.now().subtract(const Duration(minutes: 47)),
        ),
      );
      final sub = c.listen(userSessionsProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(userSessionsProvider).hasError, isTrue);
      expect(c.read(todayLiveTotalProvider), isNull);
    });

    test('dünden başlayan koşu yalnız BUGÜNE düşen kısmı sayar (WP-561)', () {
      final now = DateTime.now();
      final dayStart = istanbulDayStart(now);
      final timer = StudyTimerState(
        isRunning: true,
        startedAt: dayStart.subtract(const Duration(hours: 2)),
      );
      final c = _container(sessions: Stream.value(const []), timer: timer);
      return c.read(userSessionsProvider.future).then((_) {
        final live = c.read(todayLiveTotalProvider)!;
        final todayPart = DateTime.now().difference(dayStart).inSeconds;
        expect((live.seconds - todayPart).abs(), lessThanOrEqualTo(1));
      });
    });

    test('sayaç hiç kurulmamışsa kurmaz; kayıtlı toplamı verir', () async {
      var built = 0;
      final c = ProviderContainer(
        overrides: [
          userSessionsProvider.overrideWith(
            (ref) => Stream.value([_today(600)]),
          ),
          dailyGoalMinutesProvider.overrideWithValue(240),
          studyTimerProvider.overrideWith(() {
            built++;
            return _FixedTimer(const StudyTimerState());
          }),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(todayLiveTotalProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(userSessionsProvider.future);
      expect(c.read(todayLiveTotalProvider)!.seconds, 600);
      expect(built, 0, reason: 'Bilgi kartı sayaç makinesini kurmamalı.');
    });

    test('mola fazında canlı kısım eklenmez', () {
      final c = _container(
        sessions: Stream.value([_today(600)]),
        timer: StudyTimerState(
          isRunning: true,
          phase: TimerPhase.rest,
          startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      return c.read(userSessionsProvider.future).then((_) {
        expect(c.read(todayLiveTotalProvider)!.seconds, 600);
      });
    });
  });
}

String formatHumanTr(int s) => formatHumanForLocale(s, 'tr');
