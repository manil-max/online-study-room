import 'dart:async';

import '../../models/subject.dart';
import '../subject_repository.dart';

/// Bellek-içi (kalıcı olmayan) ders deposu. Supabase'e kadar geçicidir.
class InMemorySubjectRepository implements SubjectRepository {
  InMemorySubjectRepository();

  final List<Subject> _subjects = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<Subject> _userSubjects(String userId) {
    final list = _subjects.where((s) => s.userId == userId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(list);
  }

  @override
  Future<void> addSubject(Subject subject) async {
    _subjects.add(subject);
    _changes.add(null);
  }

  @override
  Future<void> updateSubject(Subject subject) async {
    final i = _subjects.indexWhere((s) => s.id == subject.id);
    if (i != -1) {
      _subjects[i] = subject;
      _changes.add(null);
    }
  }

  @override
  Future<void> deleteSubject(String subjectId) async {
    _subjects.removeWhere((s) => s.id == subjectId);
    _changes.add(null);
  }

  @override
  Stream<List<Subject>> watchUserSubjects(String userId) async* {
    yield _userSubjects(userId);
    await for (final _ in _changes.stream) {
      yield _userSubjects(userId);
    }
  }

  void dispose() => _changes.close();
}
