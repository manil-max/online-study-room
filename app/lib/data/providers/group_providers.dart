import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/profile.dart';
import '../models/study_group.dart';
import '../repositories/group_repository.dart';
import '../repositories/in_memory/in_memory_group_repository.dart';
import '../repositories/supabase/supabase_group_repository.dart';
import 'auth_providers.dart';

/// Aktif GroupRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseGroupRepository(Supabase.instance.client);
  }
  final repo = InMemoryGroupRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Giriş yapan kullanıcının sınıfı (yoksa null).
final userGroupProvider = StreamProvider<StudyGroup?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(groupRepositoryProvider).watchUserGroup(user.id);
});

/// Kullanıcının sınıfındaki üyeler.
final groupMembersProvider = StreamProvider<List<Profile>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(groupRepositoryProvider).watchMembers(group.id);
});
