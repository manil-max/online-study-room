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
  testWidgets('girişli kullanıcı temel V8 yüzeylerine geçebilir', (
    tester,
  ) async {
    final auth = await signedInV8AuthRepository();
    final preferences = await v8SharedPreferences();

    await tester.pumpWidget(
      buildV8TestApp(authRepository: auth, preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Sayfa'), findsWidgets);
    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();
    expect(find.text('İstatistik'), findsWidgets);
    await tester.tap(find.text('Gruplar'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz bir grupta değilsin'), findsOneWidget);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Ayarlar'), findsOneWidget);
  });

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
