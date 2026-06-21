import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/prefs/app_prefs.dart';
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

/// Giriş yapan kullanıcının üyesi olduğu TÜM sınıflar (çoklu sınıf — §3.8).
final userGroupsProvider = StreamProvider<List<StudyGroup>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(groupRepositoryProvider).watchUserGroups(user.id);
});

/// Aktif (görüntülenen) sınıfın id'si. Sınıf değiştirici buradan değiştirir.
/// Cihazda kalıcı (uygulama yeniden açılınca son aktif sınıf hatırlanır).
class ActiveGroupNotifier extends Notifier<String?> {
  static const _key = 'active_group_id';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  void select(String? groupId) {
    state = groupId;
    final prefs = ref.read(sharedPreferencesProvider);
    if (groupId == null) {
      prefs.remove(_key);
    } else {
      prefs.setString(_key, groupId);
    }
  }
}

final activeGroupIdProvider =
    NotifierProvider<ActiveGroupNotifier, String?>(ActiveGroupNotifier.new);

/// Aktif sınıf: seçili id varsa o, yoksa ilk sınıf (yoksa null).
/// `AsyncValue` döndürür ki mevcut `.value` / `.when` kullanan ekranlar değişmesin.
final userGroupProvider = Provider<AsyncValue<StudyGroup?>>((ref) {
  final groupsAsync = ref.watch(userGroupsProvider);
  final activeId = ref.watch(activeGroupIdProvider);
  return groupsAsync.whenData((groups) {
    if (groups.isEmpty) return null;
    if (activeId != null) {
      for (final g in groups) {
        if (g.id == activeId) return g;
      }
    }
    return groups.first;
  });
});

/// Aktif sınıftaki üyeler.
final groupMembersProvider = StreamProvider<List<Profile>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(groupRepositoryProvider).watchMembers(group.id);
});
