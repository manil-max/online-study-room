import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';

/// 🔴 WP-759 KUSUR 4 — bu anahtar 2026-08-26'ya kadar **ÖLÜYDÜ**.
///
/// `StudyTimerService.kt` içindeki `KEY_PANEL_EXPANDED` bu anahtarı okuyordu ve
/// sayaç bildiriminin hangi yüzeyle çizileceği kararını ona bağlıyordu. Ama
/// `app/lib` içinde anahtarı **yazan tek satır yoktu**:
///
/// ```
/// $ grep -rn "timer_panel_expanded" app/lib   ->  0 eslesme
/// ```
///
/// Sonucu ölçüldü: WP-753 Live Update yolunu varsayılan yaptı, o yol cihazda
/// hiç görülmeden v71 ile yayına çıktı ve sahibin Galaxy S23'ünde bildirim
/// `00:00` gösterip Start/Stop düğmesini hiç çizmedi. Yolu **kimse deneyemezdi**
/// — ne kullanıcı, ne cihaz testi: anahtarı açmanın tek yolu `adb` ile
/// `shared_prefs` XML'ini elle düzenlemekti. Ulaşılamayan bir dal, kaçış valfi
/// değildir; sadece ölçülmemiş koddur.
///
/// Nöbetçi: `test/core/timer_panel_switch_wiring_test.dart` — anahtarın
/// `app/lib` içinde gerçek bir yazıcısı olmadığında **kırmızı** düşer.
///
/// 🔴 Ad `flutter.` öneki TAŞIMAZ. `shared_preferences` Android'de her anahtarı
/// `flutter.` ile önekleyerek yazar; native taraf bu yüzden
/// `flutter.timer_panel_expanded` okur. İki adı tek yerde eşleyen sözleşme
/// [kTimerPanelExpandedNativeKey] ve nöbetçi testtedir.
const kTimerPanelExpandedKey = 'timer_panel_expanded';

/// Native tarafın gördüğü tam anahtar (`shared_preferences` öneki dahil).
const kTimerPanelExpandedNativeKey = 'flutter.$kTimerPanelExpandedKey';

/// Sayaç bildiriminin sunum yüzeyi tercihi.
///
/// `true`  = v43 zengin özel panel (VARSAYILAN — 26sp kalın sayaç + gömülü
///           Başlat/Durdur düğmesi; sahip bu görünümü v43'te kabul etti).
/// `false` = Android 16 Live Update yolu (deneysel).
///
/// 🔴 `false` yazmak Live Update'i **garanti etmez**. Native taraf ayrıca
/// sistemin terfiyi gerçekten verip vermediğine bakar
/// (`NotificationManager.canPostPromotedNotifications()` +
/// `Notification.hasPromotableCharacteristics()`); vermiyorsa zengin panele
/// düşer. Kullanıcıya sunulan metin bu yüzden "yok sayılabilir" der.
class TimerPanelPreferenceNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(kTimerPanelExpandedKey) ??
      true;

  /// Kullanıcının gördüğü anahtar "Live Update kullan" yönündedir; diskteki
  /// anahtar ise "zengin paneli kullan" yönünde. Çeviri tek yerde yapılır.
  Future<void> setUseLiveUpdate(bool useLiveUpdate) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kTimerPanelExpandedKey, !useLiveUpdate);
    state = !useLiveUpdate;
  }
}

/// `true` = zengin panel, `false` = Live Update.
final timerPanelExpandedProvider =
    NotifierProvider<TimerPanelPreferenceNotifier, bool>(
      TimerPanelPreferenceNotifier.new,
    );
