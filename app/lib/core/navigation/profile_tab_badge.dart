import 'package:flutter/material.dart';

import '../theme/warning_tokens.dart';

/// Profil sekmesindeki rozetin **tek kaynağı** (WP-594/1).
///
/// 🔴 Neden ayrı bir tip: rozet mantığı `HomeShell` içinde özel bir yardımcı
/// metottu ve yalnız **mobil** kolda çağrılıyordu. Masaüstü kolu
/// (`DesktopHomeShell`) hiçbirini geçmiyordu; yani Windows kullanıcısı
/// bekleyen ödülünü, okunmamış duyurusunu ve eksik birincil grup uyarısını
/// **hiç görmüyordu**. Üçü de sessiz kayıptır: rozet görünmezse kullanıcı
/// ödülünü almaz, duyuruyu okumaz, grup ilerlemesi hiç işlemez.
///
/// Aynı hata WP-550'de yenileme yolunda da yaşandı: masaüstü için **ikinci
/// bir** liste tutulmuştu ve eksikti. Ders aynı: iki kol tek kaynağı çağırır,
/// kopya tutulmaz.
///
/// Bu tip yalnız **durumu** taşır; rengi çağıran yüzey verir, çünkü uyarı
/// rengi zeminden türetilir (`warning_tokens.dart`) ve mobil alt çubuk ile
/// masaüstü sol panelinin zemini aynı değildir.
@immutable
class ProfileTabBadge {
  const ProfileTabBadge({
    required this.pendingRewardCount,
    required this.missingPrimaryGroup,
    required this.unreadProfileSignals,
  });

  /// Rozetsiz durum — testler ve rozet beslenmeyen yüzeyler için.
  static const ProfileTabBadge none = ProfileTabBadge(
    pendingRewardCount: 0,
    missingPrimaryGroup: false,
    unreadProfileSignals: 0,
  );

  final int pendingRewardCount;
  final bool missingPrimaryGroup;
  final int unreadProfileSignals;

  /// Bekleyen ödül sayısı varsa sayı rozeti korunur; yoksa sayısız nokta
  /// gösterilir. İki sinyal aynı sekmede yarışmaz.
  bool get showsCount => pendingRewardCount > 0;

  /// Eksik birincil grup bir **kayıptır** (uyarı rengi); okunmamış duyuru yeni
  /// içeriktir. Kayıp önceliklidir, ikisi aynı anda çizilmez.
  bool get showsWarningDot => !showsCount && missingPrimaryGroup;

  bool get showsAnnouncementDot =>
      !showsCount && !missingPrimaryGroup && unreadProfileSignals > 0;

  bool get isVisible => showsCount || showsWarningDot || showsAnnouncementDot;

  /// [child] ikonunu uygun rozetle sarar.
  ///
  /// [surface] rozetin üstünde durduğu zemindir: uyarı noktası tema
  /// paletinden değil **zeminden** türetilir (WP-358). Yanlış zemini vermek
  /// sessiz bir kontrast hatası olurdu, bu yüzden açıkça geçilir.
  Widget wrap(
    Widget child, {
    required Color surface,
    required Color announcementColor,
  }) {
    if (showsCount) {
      return Badge.count(count: pendingRewardCount, child: child);
    }
    if (showsAnnouncementDot) {
      return Badge(backgroundColor: announcementColor, child: child);
    }
    return Badge(
      isLabelVisible: showsWarningDot,
      backgroundColor: warningColorsOn(surface).container,
      child: child,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileTabBadge &&
      other.pendingRewardCount == pendingRewardCount &&
      other.missingPrimaryGroup == missingPrimaryGroup &&
      other.unreadProfileSignals == unreadProfileSignals;

  @override
  int get hashCode =>
      Object.hash(pendingRewardCount, missingPrimaryGroup, unreadProfileSignals);
}
