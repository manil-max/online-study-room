import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_subject_repository.dart';

Subject _subject(String id, String userId, String name, String color) {
  return Subject(id: id, userId: userId, name: name, color: color);
}

void main() {
  test('watchUserSubjects kullanıcıya göre süzer ve ada göre sıralar', () async {
    final repo = InMemorySubjectRepository();
    await repo.addSubject(_subject('1', 'u1', 'Matematik', 'chart-1'));
    await repo.addSubject(_subject('2', 'u1', 'Fizik', 'chart-2'));
    await repo.addSubject(_subject('3', 'u2', 'Kimya', 'chart-3'));

    final mine = await repo.watchUserSubjects('u1').first;
    expect(mine.map((e) => e.name).toList(), ['Fizik', 'Matematik']);
  });

  test('updateSubject ad ve rengi günceller', () async {
    final repo = InMemorySubjectRepository();
    await repo.addSubject(_subject('1', 'u1', 'Matematik', 'chart-1'));
    await repo
        .updateSubject(_subject('1', 'u1', 'İleri Matematik', 'chart-4'));

    final mine = await repo.watchUserSubjects('u1').first;
    expect(mine.single.name, 'İleri Matematik');
    expect(mine.single.color, 'chart-4');
  });

  test('deleteSubject dersi kaldırır', () async {
    final repo = InMemorySubjectRepository();
    await repo.addSubject(_subject('1', 'u1', 'Matematik', 'chart-1'));
    await repo.addSubject(_subject('2', 'u1', 'Fizik', 'chart-2'));
    await repo.deleteSubject('1');

    final mine = await repo.watchUserSubjects('u1').first;
    expect(mine.map((e) => e.id).toList(), ['2']);
  });

  test('Subject toMap/fromMap gidiş-dönüş tutarlı', () {
    final s = _subject('1', 'u1', 'Türkçe', 'chart-5');
    expect(Subject.fromMap(s.toMap()), s);
  });

  test('fromMap renk boşsa varsayılan ilk palet rengine düşer', () {
    final s = Subject.fromMap({'id': '1', 'user_id': 'u1', 'name': 'Tarih'});
    expect(s.color, kSubjectColorTokens.first);
  });
}
