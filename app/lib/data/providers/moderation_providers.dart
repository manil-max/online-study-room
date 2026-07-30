import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/moderation_appeal.dart';
import '../models/moderation_sanction.dart';
import '../models/profile.dart';
import '../repositories/in_memory/in_memory_moderation_repository.dart';
import '../repositories/moderation_repository.dart';
import '../repositories/supabase/supabase_moderation_repository.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseModerationRepository(Supabase.instance.client);
  }
  return InMemoryModerationRepository();
});

/// WP-125/126: engellenen kullanıcı id seti (sohbet + presence filtre).
final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final ids = await ref.watch(moderationRepositoryProvider).listBlockedUserIds();
  return ids.toSet();
});

/// WP-129: engellenen kullanıcılar ekranı (profil özeti).
final blockedProfilesProvider =
    FutureProvider.autoDispose<List<Profile>>((ref) async {
  // ids değişince liste de yenilensin.
  ref.watch(blockedUserIdsProvider);
  return ref.watch(moderationRepositoryProvider).fetchBlockedProfiles();
});

/// WP-442: Kullanıcının kendi hakkındaki yaptırımları — nedeni ve süresi.
final mySanctionsProvider = FutureProvider<List<ModerationSanction>>((
  ref,
) async {
  return ref.watch(moderationRepositoryProvider).fetchMySanctions();
});

/// Kullanıcının kendi itirazları; yaptırım kartı durumunu buradan okur.
final myAppealsProvider = FutureProvider<List<ModerationAppeal>>((ref) async {
  return ref.watch(moderationRepositoryProvider).fetchMyAppeals();
});
