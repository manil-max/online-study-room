import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/subject.dart';
import '../repositories/subject_repository.dart';
import '../repositories/in_memory/in_memory_subject_repository.dart';
import '../repositories/supabase/supabase_subject_repository.dart';
import 'auth_providers.dart';

/// Aktif SubjectRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseSubjectRepository(Supabase.instance.client);
  }
  final repo = InMemorySubjectRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Giriş yapan kullanıcının dersleri (ada göre sıralı).
final userSubjectsProvider = StreamProvider<List<Subject>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(subjectRepositoryProvider).watchUserSubjects(user.id);
});
