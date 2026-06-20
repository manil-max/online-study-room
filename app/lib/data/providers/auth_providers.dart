import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/in_memory/in_memory_auth_repository.dart';

/// Aktif AuthRepository. Şimdilik bellek-içi; Supabase entegrasyonunda burası
/// SupabaseAuthRepository ile değiştirilecek (tek satır).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = InMemoryAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Oturum durumu: giriş yapan profil veya null.
final authStateProvider = StreamProvider<Profile?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
