import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/nudge.dart';
import '../repositories/in_memory/in_memory_nudge_repository.dart';
import '../repositories/nudge_repository.dart';
import '../repositories/supabase/supabase_nudge_repository.dart';

final nudgeRepositoryProvider = Provider<NudgeRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseNudgeRepository(Supabase.instance.client);
  }
  final repo = InMemoryNudgeRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final receivedNudgesProvider = StreamProvider.family<List<Nudge>, String>((
  ref,
  userId,
) {
  return ref.watch(nudgeRepositoryProvider).watchReceivedNudges(userId);
});
