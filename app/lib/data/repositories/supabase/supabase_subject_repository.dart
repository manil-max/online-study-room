import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/subject.dart';
import '../subject_repository.dart';

/// Supabase tabanlı ders deposu. UI hiç değişmeden bellek-içi yerine geçer.
///
/// Dersler kişiye özel ve nadiren değişir; bu yüzden Realtime'a BAĞLI DEĞİLDİR.
/// Liste açılışta bir kez çekilir, her ekleme/düzenleme/silmeden sonra yeniden
/// çekilir (`_changes` tetikleyicisi). Böylece `0003_subjects_realtime.sql`
/// çalıştırılmamış olsa bile ders ekleme anında listede görünür.
class SupabaseSubjectRepository implements SubjectRepository {
  SupabaseSubjectRepository(this._client);

  final SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Future<List<Subject>> _fetch(String userId) async {
    final rows = await _client
        .from('subjects')
        .select()
        .eq('user_id', userId)
        .order('name');
    return (rows as List)
        .map((r) => Subject.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addSubject(Subject subject) async {
    await _client.from('subjects').insert(subject.toMap());
    _changes.add(null);
  }

  @override
  Future<void> updateSubject(Subject subject) async {
    await _client.from('subjects').update(subject.toMap()).eq('id', subject.id);
    _changes.add(null);
  }

  @override
  Future<void> deleteSubject(String subjectId) async {
    await _client.from('subjects').delete().eq('id', subjectId);
    _changes.add(null);
  }

  @override
  Stream<List<Subject>> watchUserSubjects(String userId) async* {
    yield await _fetch(userId);
    await for (final _ in _changes.stream) {
      yield await _fetch(userId);
    }
  }
}
