import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'package:online_study_room/core/stats/istanbul_calendar.dart';

import '../../support/async_wait.dart';
import '../../support/istanbul_fixture.dart';

/// Gerçek notifier'ın (kanal/dinleyici kurulumu olan) build()'ini atlayan sahte.
/// Testte state'i biz elle sürüyoruz; amaç UI'ın hesabını doğrulamak.
class _FakeTimerNotifier extends StudyTimerNotifier {
  _FakeTimerNotifier(this._initial);

  final StudyTimerState _initial;

  @override
  StudyTimerState build() => _initial;

  void push(StudyTimerState next) => state = next;
}

void main() {
  testWidgets(
    'WP-250: Durdur sırasında "Bugün" toplamı zıplamaz',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      // WP-296 bu testi bir kez saatten kurtarmaya çalıştı ama gün başlangıcını
      // **yerel** takvimle aldı; ürünün gün sınırı ise `Europe/Istanbul`. UTC
      // koşucuda 21:00 = İstanbul 00:00 olduğu için kayıt düne düşüyor,
      // `dailyTotals` bugüne 0 yazıyor ve toplam 2 saat yerine 1 saat çıkıyordu
      // — v49 sürümünü kıran hata buydu. Artık geriye gidiş **İstanbul günü**
      // içinde tutuluyor: gün başından beri 1 saat geçmemişse pencere kısalır,
      // beklenen toplam da ona göre hesaplanır.
      final liveWindow = backWithinIstanbulToday(const Duration(hours: 1));
      final liveSeconds = liveWindow.inSeconds;
      final startedAt = now.subtract(liveWindow);
      const recordedSeconds = 3600;
      final expectedTotal = recordedSeconds + liveSeconds;

      // Bugün zaten kayıtlı bir saat.
      final recordedSession = StudySession(
        id: 'rec-1',
        userId: 'u1',
        start: startedAt,
        end: startedAt.add(const Duration(seconds: recordedSeconds)),
        durationSeconds: recordedSeconds,
        source: StudySource.live,
      );
      // Durdurulan oturum DB'ye düştüğünde eklenecek satır.
      final stoppedSession = StudySession(
        id: 'rec-2',
        userId: 'u1',
        start: startedAt,
        end: now,
        durationSeconds: liveSeconds,
        source: StudySource.live,
      );

      final sessions = StreamController<List<StudySession>>.broadcast();
      addTearDown(sessions.close);

      final running = StudyTimerState(
        isRunning: true,
        startedAt: startedAt,
        phase: TimerPhase.work,
      );
      final fake = _FakeTimerNotifier(running);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userSessionsProvider.overrideWith((ref) => sessions.stream),
            userSubjectsProvider.overrideWith(
              (ref) => Stream.value(const <Subject>[]),
            ),
            dailyGoalMinutesProvider.overrideWithValue(240),
            userGroupProvider.overrideWithValue(
              const AsyncData<StudyGroup?>(null),
            ),
            studyTimerProvider.overrideWith(() => fake),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(width: 380, height: 900, child: StudyTimerCard()),
            ),
          ),
        ),
      );

      sessions.add([recordedSession]);
      // Akış olayı + yeniden çizim iki ayrı tura düşebilir; tek `pump()`
      // hızlı makinede yetiyor ama CI koşucusunda yetmiyordu (v49 kırılması).
      await pumpUntilFound(
        tester,
        find.text(formatHumanSeconds(expectedTotal)),
        reason: 'kayıtlı + canlı toplamı ekranda görünmeli',
      );

      // Kayıtlı süre + canlı süre.
      expect(find.text(formatHumanSeconds(expectedTotal)), findsWidgets);

      // --- Durdur'a basıldı: notifier ilk await'ten önce bunu yayınlar. ---
      fake.push(
        running.copyWith(
          isStopping: true,
          settlingSeconds: liveSeconds,
          settlingBaseline: recordedSeconds,
          settlingDay: istanbulDay(now),
        ),
      );
      await tester.pump();
      expect(
        find.text(formatHumanSeconds(expectedTotal)),
        findsWidgets,
        reason: 'durdurma anında toplam değişmemeli',
      );

      // --- RTT penceresi: kayıt yerel cache'e düştü, stream emit etti,
      //     ama `_finish()` HENÜZ çalışmadı (isRunning hâlâ true). ---
      sessions.add([recordedSession, stoppedSession]);
      // Olumsuz iddia: sayı **değişmemeli**. Tek `pump()` ile yetinilseydi
      // olay henüz işlenmemiş olabilir ve test hatayı kaçırıp boş yere geçerdi.
      await pumpFrames(tester);
      expect(
        find.text(formatHumanSeconds(expectedTotal)),
        findsWidgets,
        reason: 'ASIL BUG: burada canlı süre iki kez sayılıyordu',
      );
      expect(find.text(formatHumanSeconds(expectedTotal + liveSeconds)), findsNothing);

      // --- `_finish()` çalıştı. ---
      fake.push(
        const StudyTimerState().copyWith(
          settlingSeconds: liveSeconds,
          settlingBaseline: recordedSeconds,
          settlingDay: istanbulDay(now),
        ),
      );
      await tester.pump();
      expect(find.text(formatHumanSeconds(expectedTotal)), findsWidgets);
    },
  );
}
