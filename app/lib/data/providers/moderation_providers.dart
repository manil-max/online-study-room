import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
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
