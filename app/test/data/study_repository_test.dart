import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';

StudySession _session(
  String id,
  String userId,
  DateTime start,
  int durationSeconds,
) {
  return StudySession(
    id: id,
    userId: userId,
    start: start,
    end: start.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    source: StudySource.live,
  );
}

/// 🔴 WP-840: tarihler SABİT değil, **bugüne göreli**. Eskiden `DateTime(2026, 6, 20)`
/// yazıyordu; `kUserSessionsHotWindowDays` 90 günlük sıcak pencere olduğu için bu dosya
/// 2026-09-18'de kendiliğinden kırmızıya döndü (20 Haziran tam 90 gün geride kaldı ve
/// oturum listeden düştü). Testin ölçtüğü şey pencere değil, süzme ve sıralama.
DateTime _daysAgo(int days, {int hour = 8}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, hour);
  return today.subtract(Duration(days: days));
}

void main() {
  test(
    'watchUserSessions kullanıcıya göre süzer ve yeni→eski sıralar',
    () async {
      final repo = InMemoryStudyRepository();
      await repo.addSession(_session('1', 'u1', _daysAgo(2), 600));
      await repo.addSession(_session('2', 'u1', _daysAgo(1), 600));
      await repo.addSession(_session('3', 'u2', _daysAgo(1, hour: 9), 600));

      final mine = await repo.watchUserSessions('u1').first;
      expect(mine.map((e) => e.id).toList(), ['2', '1']);
    },
  );

  test('watchGroupSessions artık boş döner (group_id kaldırıldı)', () async {
    final repo = InMemoryStudyRepository();
    await repo.addSession(_session('1', 'u1', _daysAgo(1), 600));
    await repo.addSession(_session('2', 'u2', _daysAgo(1, hour: 9), 900));

    final all = await repo.watchGroupSessions('g1').first;
    expect(all, isEmpty);
  });

  test('updateSession süreyi günceller', () async {
    final repo = InMemoryStudyRepository();
    await repo.addSession(_session('1', 'u1', _daysAgo(1), 600));
    await repo.updateSession(
      _session('1', 'u1', _daysAgo(1), 1800),
    );

    final mine = await repo.watchUserSessions('u1').first;
    expect(mine.single.durationSeconds, 1800);
  });

  test(
    'addSession aynı id ile tekrarlandığında ikinci kayıt oluşturmaz',
    () async {
      final repo = InMemoryStudyRepository();
      await repo.addSession(_session('1', 'u1', _daysAgo(1), 600));
      await repo.addSession(
        _session('1', 'u1', _daysAgo(1), 1800),
      );

      final mine = await repo.watchUserSessions('u1').first;
      expect(mine, hasLength(1));
      expect(mine.single.durationSeconds, 1800);
    },
  );

  test('deleteSession oturumu kaldırır', () async {
    final repo = InMemoryStudyRepository();
    await repo.addSession(_session('1', 'u1', _daysAgo(1), 600));
    await repo.addSession(_session('2', 'u1', _daysAgo(1, hour: 9), 900));
    await repo.deleteSession('1');

    final mine = await repo.watchUserSessions('u1').first;
    expect(mine.map((e) => e.id).toList(), ['2']);
  });
}
