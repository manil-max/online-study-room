import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/subject.dart';
import '../subject_repository.dart';

/// Supabase tabanlı ders deposu. UI hiç değişmeden bellek-içi yerine geçer.
/// `subjects` tablosu + RLS 0001 şemasında, Realtime publication 0003 migrasyonunda.
class SupabaseSubjectRepository implements SubjectRepository {
  SupabaseSubjectRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> addSubject(Subject subject) async {
    await _client.from('subjects').insert(subject.toMap());
  }

  @override
  Future<void> updateSubject(Subject subject) async {
    await _client.from('subjects').update(subject.toMap()).eq('id', subject.id);
  }

  @override
  Future<void> deleteSubject(String subjectId) async {
    await _client.from('subjects').delete().eq('id', subjectId);
  }

  @override
  Stream<List<Subject>> watchUserSubjects(String userId) {
    return _client
        .from('subjects')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('name')
        .map((rows) => rows.map(Subject.fromMap).toList());
  }
}
