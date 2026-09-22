import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/google_sign_in_config.dart';
import '../../core/config/supabase_config.dart';

/// WP-831: giriş ekranında "Google ile devam et" düğmesi çizilsin mi?
///
/// Üç koşulun **hepsi** gerekir (fail-closed): Android veya Windows (web
/// değil; WP-866 Windows'u tarayıcı + loopback akışıyla ekledi),
/// `GOOGLE_WEB_CLIENT_ID` dolu ve depo Supabase deposu. Biri eksikse düğme
/// hiç görünmez — yapılandırılmamış kurulumda çalışmayan düğme gösterilmez.
/// Tam tablo: `GoogleSignInConfig` belge yorumu.
///
/// Sağlayıcı olarak durur ki widget testleri kararı override edebilsin;
/// kararın kendisi saftır ve `GoogleSignInConfig.resolveEnabled`da sınanır.
///
/// 🔴 Arka uç kararı depo örneğinden DEĞİL, `SupabaseConfig.isConfigured`dan
/// okunur (`authRepositoryProvider` da aynı bayrakla seçer). Depoyu `watch`
/// etmek ekranın her çiziminde `Supabase.instance`a dokunuyordu: v85 release
/// koşumunda (35091694752) define'lar dolu olduğu için başlatılmamış
/// Supabase'e düşen 10 giriş ekranı testi kırıldı; yerel env boş olduğu için
/// kapı bunu göremedi.
final googleSignInEnabledProvider = Provider<bool>((ref) {
  return GoogleSignInConfig.resolveEnabled(
    webClientId: GoogleSignInConfig.webClientId,
    iosClientId: GoogleSignInConfig.iosClientId,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    supabaseBackend: SupabaseConfig.isConfigured,
  );
});
