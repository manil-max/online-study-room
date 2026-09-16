import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/google_sign_in_config.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/supabase/supabase_auth_repository.dart';

/// WP-831: giriş ekranında "Google ile devam et" düğmesi çizilsin mi?
///
/// Üç koşulun **hepsi** gerekir (fail-closed): Android (web değil),
/// `GOOGLE_WEB_CLIENT_ID` dolu ve depo Supabase deposu. Biri eksikse düğme
/// hiç görünmez — yapılandırılmamış kurulumda çalışmayan düğme gösterilmez.
///
/// Sağlayıcı olarak durur ki widget testleri kararı override edebilsin;
/// kararın kendisi saftır ve `GoogleSignInConfig.resolveEnabled`da sınanır.
final googleSignInEnabledProvider = Provider<bool>((ref) {
  return GoogleSignInConfig.resolveEnabled(
    webClientId: GoogleSignInConfig.webClientId,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    supabaseBackend:
        ref.watch(authRepositoryProvider) is SupabaseAuthRepository,
  );
});
