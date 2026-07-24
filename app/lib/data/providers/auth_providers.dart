import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/auth_redirect_config.dart';
import '../../core/config/supabase_config.dart';
import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/in_memory/in_memory_auth_repository.dart';
import '../repositories/supabase/supabase_auth_repository.dart';

/// WP-287: Şifre sıfırlama e-postasının derin bağlantı hedefi. Android'de
/// flavor'a uygun scheme (`…://login-callback`), Windows/masaüstü/web'de null
/// (kullanıcı e-postadaki kod ile sıfırlar).
Future<String?> resolveRecoveryRedirect() async {
  if (kIsWeb) return null;
  if (!Platform.isAndroid) return null;
  try {
    final info = await PackageInfo.fromPlatform();
    return authRecoveryRedirectUrl(info.packageName, isAndroid: true);
  } catch (_) {
    return null; // Paket adı okunamazsa güvenli tarafta OTP yoluna düş.
  }
}

/// Aktif AuthRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAuthRepository(
      Supabase.instance.client,
      recoveryRedirect: resolveRecoveryRedirect,
    );
  }
  final repo = InMemoryAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Oturum durumu: giriş yapan profil veya null.
final authStateProvider = StreamProvider<Profile?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
