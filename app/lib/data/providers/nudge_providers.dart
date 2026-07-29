import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/nudge.dart';
import '../models/nudge_mute.dart';
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

/// WP-444: çağıranın dürtmesini susturduğu kimlikler.
///
/// Yaptırım sunucudadır; bu set istemci tarafında **ikinci katman**dır
/// (susturmadan önce yola çıkmış ya da çevrimdışı kuyrukta beklemiş bir satır
/// bildirime dönüşmesin). Susturma listesi hesap kapsamlı olduğu için ikinci
/// cihazda da aynı sonucu verir.
final mutedNudgeSenderIdsProvider = FutureProvider<Set<String>>((ref) async {
  final ids = await ref
      .watch(nudgeRepositoryProvider)
      .listMutedNudgeSenderIds();
  return ids.toSet();
});

/// WP-444: "dürtmesi kapalı kişiler" yönetim listesi (ad/avatar ile).
final nudgeMutesProvider = FutureProvider.autoDispose<List<NudgeMute>>((
  ref,
) async {
  // Tercih değişince liste de tazelenir.
  ref.watch(mutedNudgeSenderIdsProvider);
  return ref.watch(nudgeRepositoryProvider).fetchNudgeMutes();
});
