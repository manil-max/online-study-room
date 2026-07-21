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
      final startedAt = now.subtract(const Duration(hours: 1));
      // Bugün zaten kayıtlı 1 saat.
      final recordedSession = StudySession(
        id: 'rec-1',
        userId: 'u1',
        start: now.subtract(const Duration(hours: 3)),
        end: now.subtract(const Duration(hours: 2)),
        durationSeconds: 3600,
        source: StudySource.live,
      );
      // Durdurulan 1 saatlik oturum DB'ye düştüğünde eklenecek satır.
      final stoppedSession = StudySession(
        id: 'rec-2',
        userId: 'u1',
        start: startedAt,
        end: now,
        durationSeconds: 3600,
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
      await tester.pump();

      // 1 saat kayıtlı + 1 saat canlı = 2 saat.
      expect(find.text(formatHumanSeconds(7200)), findsWidgets);

      // --- Durdur'a basıldı: notifier ilk await'ten önce bunu yayınlar. ---
      fake.push(
        running.copyWith(
          isStopping: true,
          settlingSeconds: 3600,
          settlingBaseline: 3600,
          settlingDay: DateTime(now.year, now.month, now.day),
        ),
      );
      await tester.pump();
      expect(
        find.text(formatHumanSeconds(7200)),
        findsWidgets,
        reason: 'durdurma anında toplam değişmemeli',
      );

      // --- RTT penceresi: kayıt yerel cache'e düştü, stream emit etti,
      //     ama `_finish()` HENÜZ çalışmadı (isRunning hâlâ true). ---
      sessions.add([recordedSession, stoppedSession]);
      await tester.pump();
      expect(
        find.text(formatHumanSeconds(7200)),
        findsWidgets,
        reason: 'ASIL BUG: burada 3 saat görünüyordu',
      );
      expect(find.text(formatHumanSeconds(10800)), findsNothing);

      // --- `_finish()` çalıştı. ---
      fake.push(
        const StudyTimerState().copyWith(
          settlingSeconds: 3600,
          settlingBaseline: 3600,
          settlingDay: DateTime(now.year, now.month, now.day),
        ),
      );
      await tester.pump();
      expect(find.text(formatHumanSeconds(7200)), findsWidgets);
    },
  );
}
