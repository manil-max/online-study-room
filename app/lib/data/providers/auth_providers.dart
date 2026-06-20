import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/in_memory/in_memory_auth_repository.dart';
import '../repositories/supabase/supabase_auth_repository.dart';

/// Aktif AuthRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAuthRepository(Supabase.instance.client);
  }
  final repo = InMemoryAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Oturum durumu: giriş yapan profil veya null.
final authStateProvider = StreamProvider<Profile?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
