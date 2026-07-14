import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';

import '../support/v8_test_setup.dart';

StudySession _session(String id, DateTime start, int seconds) => StudySession(
  id: id,
  userId: 'v8-qa-user',
  start: start,
  end: start.add(Duration(seconds: seconds)),
  durationSeconds: seconds,
  source: StudySource.live,
);

void main() {
  for (final labels in const [
    (
      locale: Locale('en'),
      home: 'Home',
      statistics: 'Statistics',
      groups: 'Groups',
      noGroup: "You're not in a group yet",
      profile: 'Profile',
      settings: 'Settings',
    ),
    (
      locale: Locale('tr'),
      home: 'Ana Sayfa',
      statistics: 'İstatistik',
      groups: 'Gruplar',
      noGroup: 'Henüz bir grupta değilsin',
      profile: 'Profil',
      settings: 'Ayarlar',
    ),
  ]) {
    testWidgets(
      'girişli kullanıcı ${labels.locale.languageCode} temel V8 yüzeylerine geçebilir',
      (tester) async {
        tester.binding.platformDispatcher.localesTestValue = [labels.locale];
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

        final auth = await signedInV8AuthRepository();
        final preferences = await v8SharedPreferences();

        await tester.pumpWidget(
          buildV8TestApp(authRepository: auth, preferences: preferences),
        );
        await tester.pumpAndSettle();

        expect(find.text(labels.home), findsWidgets);
        await tester.tap(find.text(labels.statistics));
        await tester.pumpAndSettle();
        expect(find.text(labels.statistics), findsWidgets);
        await tester.tap(find.text(labels.groups));
        await tester.pumpAndSettle();
        expect(find.text(labels.noGroup), findsOneWidget);
        await tester.tap(find.text(labels.profile));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(labels.settings),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(labels.settings), findsOneWidget);
      },
    );
  }

  test(
    'session ekle-güncelle-sil ve Istanbul gün sınırı deterministiktir',
    () async {
      final repository = InMemoryStudyRepository();
      final beforeMidnight = _session(
        'before',
        DateTime.utc(2026, 7, 11, 20, 59),
        60,
      );
      final afterMidnight = _session(
        'after',
        DateTime.utc(2026, 7, 11, 21, 1),
        120,
      );

      await repository.addSession(beforeMidnight);
      await repository.addSession(afterMidnight);
      await repository.updateSession(
        _session('after', DateTime.utc(2026, 7, 11, 21, 1), 180),
      );

      var sessions = await repository.watchUserSessions('v8-qa-user').first;
      expect(dailyTotals(sessions)[DateTime(2026, 7, 11)], 60);
      expect(dailyTotals(sessions)[DateTime(2026, 7, 12)], 180);

      await repository.deleteSession('before');
      sessions = await repository.watchUserSessions('v8-qa-user').first;
      expect(sessions.map((session) => session.id), ['after']);
    },
  );
}
