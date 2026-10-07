import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/group_repository.dart';
import '../../data/repositories/supabase/resilient_stream.dart';
import '../../l10n/app_localizations.dart';

// WP-551: `groupActionErrorText` bu dosyaya `class_detail_screen.dart`ten
// **davranisi degistirilmeden** tasindi. Gerekce: bir ekran dosyasi ortak
// ceviriciye ev sahipligi yapiyordu ve iki ayri ekran (`class_switcher`,
// `group_discovery_screen`) 1500 satirlik o ekrani import etmek zorundaydi.
// Kardes desen: `core/l10n/nudge_error_text.dart`.

/// WP-540: `GroupException` (ve ağ hatası) → kullanıcı metni.
///
/// Desen `core/l10n/nudge_error_text.dart`ten alındı: hata **kimliği** tek
/// yerde metne çevrilir, böylece aynı sebep her ekranda aynı cümleyi üretir.
/// Eskiden grup tarafında beş ayrı sebep tek bir "Beklenmeyen bir hata oluştu."
/// cümlesine iniyordu.
///
/// 🔴 Kimlik `message` üzerinden okunuyor çünkü `GroupException` bir `code`
/// alanı taşımıyor ve iki repository de bu WP'nin sahip listesinde değil.
/// Eşleşen belirteçler bilerek **ASCII**: l10n kapısı `app/lib` içindeki Türkçe
/// karakterli literal'leri reddediyor, ayrıca ASCII belirteç iki uçta da aynen
/// duruyor. Kaynakları:
///   * `public_name_not_allowed` → `0094_public_name_filter.sql:47` +
///     `in_memory_group_repository.dart:127`
///   * `group_banned`            → `0093_group_bans.sql:185`
///   * `engellendi`              → `in_memory_group_repository.dart:256`
///     (bellek-içi uç kod yerine cümle taşıyor, ikisi de eşleşmeli)
///   * `Grup dolu`               → `0093_group_bans.sql` (SQL bu dizeyi kendisi
///     raise ediyor) + `in_memory_group_repository.dart:261`
///   * `Bu koda ait grup`        → iki repository de aynen üretir
///   * `not_authenticated`       → `0093_group_bans.sql`
///
/// `GroupException` **olmayan** hata ağ katmanından gelir: Supabase repository
/// yalnız `PostgrestException`ı sarıyor, bağlantı kopunca `SocketException` /
/// `ClientException` sarılmadan yukarı çıkar. Eski `on GroupException`
/// blokları bunu hiç yakalamıyordu.
String groupActionErrorText(Object error, AppLocalizations l10n) {
  if (error is! GroupException) return l10n.profileSunucuyaUlasilamadi;
  final message = error.message;
  if (message.contains('public_name_not_allowed')) {
    return l10n.moderationPublicNameRejected;
  }
  if (message.contains('group_banned') || message.contains('engellendi')) {
    return l10n.classroomGrubaKatilmanEngellendi;
  }
  if (message.contains('Grup dolu')) return l10n.classroomGrupDolu;
  if (message.contains('Bu koda ait grup')) return l10n.commonBuKodaAitGrup;
  if (message.contains('not_authenticated')) {
    return l10n.profileOturumBulunamadiGirisYap;
  }
  return l10n.authBeklenmeyenBirHataOlustu;
}

/// WP-938: genel yükleme hatasının altındaki teşhis ipucunun kimliği.
const Key kLoadErrorCauseHintKey = Key('loadErrorCauseHint');

/// Sunucunun "yetki/oturum" anlamına gelen PostgREST/Postgres kodları.
const Set<String> _authErrorCodes = {
  '401',
  '403',
  '42501', // insufficient_privilege (RLS)
  'PGRST301', // JWT süresi dolmuş / geçersiz
  'PGRST302',
};

/// WP-938: yükleme hatasının **kaynak sınıfı** — genel hata cümlesinin altına
/// konan kısa ipucu.
///
/// 🔴 Neden var: sahip "Beklenmeyen bir hata oluştu" ekran görüntüsünden
/// sebebi okuyamıyordu; kök neden Realtime soketiydi, REST sağlıklıydı ve bu
/// ancak sunucu taraması ile bulundu. Bir sonraki sefer ekran görüntüsü tek
/// başına "canlı güncelleme mi, ağ mı, yetki mi, sunucu mu" sorusunu cevaplar.
///
/// `SocketException`/`HandshakeException` `dart:io` türleridir ve web derlemesi
/// bu dosyayı da derler; o yüzden tür adıyla tanınırlar.
String loadErrorCauseHint(Object? error, AppLocalizations l10n) {
  if (error == null) return l10n.streamErrorCauseApp;
  if (isRealtimeTransportError(error)) return l10n.streamErrorCauseRealtime;
  if (error is AuthException) return l10n.streamErrorCauseAuth;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (_authErrorCodes.contains(code)) return l10n.streamErrorCauseAuth;
    return l10n.streamErrorCauseServer(code.isEmpty ? '?' : code);
  }
  if (error is http.ClientException || error is TimeoutException) {
    return l10n.streamErrorCauseNetwork;
  }
  final type = error.runtimeType.toString();
  if (type.contains('SocketException') || type.contains('HandshakeException')) {
    return l10n.streamErrorCauseNetwork;
  }
  if (error is GroupException) {
    if (error.message.contains('not_authenticated')) {
      return l10n.streamErrorCauseAuth;
    }
    return l10n.streamErrorCauseServer('group');
  }
  return l10n.streamErrorCauseApp;
}
