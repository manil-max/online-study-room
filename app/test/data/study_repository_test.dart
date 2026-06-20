import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';

StudySession _session(
  String id,
  String userId,
  String groupId,
  DateTime start,
  int durationSeconds,
) {
  return StudySession(
    id: id,
    userId: userId,
    groupId: groupId,
    start: start,
    end: start.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    source: StudySource.live,
  );
}

void main() {
  test('watchUserSessions kullanıcıya göre süzer ve yeni→eski sıralar', () async {
    final repo = InMemoryStudyRepository();
    await repo.addSession(_session('1', 'u1', 'g1', DateTime(2026, 6, 20, 8), 600));
    await repo.addSession(_session('2', 'u1', 'g1', DateTime(2026, 6, 21, 8), 600));
    await repo.addSession(_session('3', 'u2', 'g1', DateTime(2026, 6, 21, 9), 600));

    final mine = await repo.watchUserSessions('u1').first;
    expect(mine.map((e) => e.id).toList(), ['2', '1']);
  });

  test('watchGroupSessions sınıfın tüm oturumlarını verir', () async {
    final repo = InMemoryStudyRepository();
    await repo.addSession(_session('1', 'u1', 'g1', DateTime(2026, 6, 21, 8), 600));
    await repo.addSession(_session('2', 'u2', 'g1', DateTime(2026, 6, 21, 9), 900));

    final all = await repo.watchGroupSessions('g1').first;
    expect(all, hasLength(2));
  });

  test('updateSession süreyi günceller', () async {
    final repo = InMemoryStudyRepository();
    await repo.addSession(_session('1', 'u1', 'g1', DateTime(2026, 6, 21, 8), 600));
    await repo.updateSession(_session('1', 'u1', 'g1', DateTime(2026, 6, 21, 8), 1800));

    final mine = await repo.watchUserSessions('u1').first;
    expect(mine.single.durationSeconds, 1800);
  });

  test('deleteSession oturumu kaldırır', () async {
    final repo = InMemoryStudyRepository();
    await repo.addSession(_session('1', 'u1', 'g1', DateTime(2026, 6, 21, 8), 600));
    await repo.addSession(_session('2', 'u1', 'g1', DateTime(2026, 6, 21, 9), 900));
    await repo.deleteSession('1');

    final mine = await repo.watchUserSessions('u1').first;
    expect(mine.map((e) => e.id).toList(), ['2']);
  });
}
