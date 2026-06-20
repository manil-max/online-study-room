import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;

import '../../core/config/supabase_config.dart';
import '../models/presence.dart';
import '../repositories/presence_repository.dart';
import '../repositories/in_memory/in_memory_presence_repository.dart';
import '../repositories/supabase/supabase_presence_repository.dart';
import 'group_providers.dart';

/// Aktif PresenceRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabasePresenceRepository(Supabase.instance.client);
  }
  final repo = InMemoryPresenceRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Kullanıcının sınıfındaki tüm üyelerin canlı durumu.
final groupPresenceProvider = StreamProvider<List<Presence>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(presenceRepositoryProvider).watchGroupPresence(group.id);
});
