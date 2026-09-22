import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';

/// WP-902: "Apple ile giriş yap" hangi derlemede açık?
///
/// App Store Kuralı 4.8: iOS uygulaması Google girişi sunuyorsa Apple ile
/// girişi de sunmalı. v1'de yalnız iOS (Android/Windows'ta Apple'ın web
/// akışı ayrı bir Services ID + dönüş adresi ister; kapsam dışı).
///
/// | platform              | Supabase | sonuç  |
/// |-----------------------|----------|--------|
/// | iOS (web değil)       | var      | açık   |
/// | iOS                   | yok      | kapalı |
/// | Android/Windows/diğer | —        | kapalı |
/// | web                   | —        | kapalı |
///
/// Bellek-içi (demo/offline) modda Apple token'ını doğrulayacak sunucu yok;
/// düğme orada çizilmez (fail-closed, Google ile aynı).
bool resolveAppleSignInEnabled({
  required bool isWeb,
  required TargetPlatform platform,
  required bool supabaseBackend,
}) {
  if (isWeb || !supabaseBackend) return false;
  return platform == TargetPlatform.iOS;
}

/// WP-902: giriş ekranında Apple düğmesi çizilsin mi?
///
/// Sağlayıcı olarak durur ki widget testleri kararı override edebilsin.
/// Arka uç kararı depo örneğinden değil `SupabaseConfig.isConfigured`dan
/// okunur (gerekçe: `googleSignInEnabledProvider` notu, v85 kırığı).
final appleSignInEnabledProvider = Provider<bool>((ref) {
  return resolveAppleSignInEnabled(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    supabaseBackend: SupabaseConfig.isConfigured,
  );
});
