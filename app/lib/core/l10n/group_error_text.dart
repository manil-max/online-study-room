import '../../data/repositories/group_repository.dart';
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
