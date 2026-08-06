import 'dart:async';

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

/// Signed URL cache key. The version changes whenever a new object path is
/// committed, so Flutter never reuses the previous group image.
class GroupAvatarRequest {
  const GroupAvatarRequest({required this.path, required this.updatedAt});

  final String path;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      other is GroupAvatarRequest &&
      other.path == path &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(path, updatedAt);
}

/// Private Storage URLs expire. Refresh an actively displayed avatar before the
/// one-hour signed URL expires; disposed surfaces keep no background timer.
final groupAvatarUrlProvider = FutureProvider.autoDispose
    .family<String?, GroupAvatarRequest>((ref, request) async {
      final refresh = Timer(const Duration(minutes: 55), ref.invalidateSelf);
      ref.onDispose(refresh.cancel);
      return ref
          .watch(groupRepositoryProvider)
          .createGroupAvatarSignedUrl(request.path);
    });

/// Giriş yapan kullanıcının üyesi olduğu TÜM sınıflar (çoklu sınıf — §3.8).
final userGroupsProvider = StreamProvider<List<StudyGroup>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(groupRepositoryProvider).watchUserGroups(user.id);
});

/// Sunucunun sıraladığı hesap-geneli primary tercih. Cihazdaki class switcher
/// seçimiyle ayrı tutulur; timer/presence bu provider'ı izlememelidir.
final primaryGroupPreferenceProvider = StreamProvider<PrimaryGroupPreference>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(
      const PrimaryGroupPreference(primaryGroupId: null, selectionRevision: 0),
    );
  }
  return ref
      .watch(groupRepositoryProvider)
      .watchPrimaryGroupPreference(user.id);
});

/// WP-352: Üyeliği olup birincil grubu olmayan hesapta grup ilerlemesi HİÇBİR
/// gruba yazılmaz — `groups_for_session_progression` boş küme döner
/// (`0080_session_group_attribution.sql`). Kayıp sessizdir: grup liderlik
/// tablosu ham oturumları topladığı için kullanıcı orada normal görünür. Bu
/// yüzden durum kullanıcıya görünür kılınmalıdır.
///
/// Yükleme/hata sırasında `false` döner; olmayan bir kaybı ilan etmeyiz.
final primaryGroupSelectionMissingProvider = Provider<bool>((ref) {
  final groups = ref.watch(userGroupsProvider).value;
  final preference = ref.watch(primaryGroupPreferenceProvider).value;
  if (groups == null || preference == null) return false;
  return groups.isNotEmpty && preference.primaryGroupId == null;
});

final primaryGroupProvider = Provider<AsyncValue<StudyGroup?>>((ref) {
  final groupsAsync = ref.watch(userGroupsProvider);
  final preferenceAsync = ref.watch(primaryGroupPreferenceProvider);
  return groupsAsync.whenData((groups) {
    final primaryId = preferenceAsync.value?.primaryGroupId;
    if (primaryId == null) return null;
    for (final group in groups) {
      if (group.id == primaryId) return group;
    }
    return null;
  });
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

final activeGroupIdProvider = NotifierProvider<ActiveGroupNotifier, String?>(
  ActiveGroupNotifier.new,
);

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

/// 🔴 WP-494: Kimliği verilen grubun üye akışı.
///
/// Grup detay ekranı bu akışı `StreamBuilder`a **`build()` içinde** kuruyordu:
/// her yeniden çizim yeni bir Supabase realtime aboneliği açıyor, her emisyon
/// bir `group_member_directory` RPC'si atıyordu. Aynı `build()` presence'ı da
/// izlediği için ekran saniyeler mertebesinde yeniden kuruluyor, taze stream
/// henüz veri vermediği için liste spinner'a düşüyordu ("gruplar kısmında
/// sürekli ekran yenilenip geliyordu"). Provider aynı `groupId` için tek akış
/// tutar ve yeniden çizimde son listeyi korur.
final groupMembersByIdProvider = StreamProvider.family<List<Profile>, String>((
  ref,
  groupId,
) {
  return ref.watch(groupRepositoryProvider).watchMembers(groupId);
});

/// Aktif sınıftaki üyeler.
final groupMembersProvider = StreamProvider<List<Profile>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(groupRepositoryProvider).watchMembers(group.id);
});
