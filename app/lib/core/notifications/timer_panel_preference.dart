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

/// Sayaç bildiriminin sunum yüzeyi tercihi — **üç durumlu**.
///
/// 🔴 WP-760: burası iki durumluydu ve o yüzden bir tuzak taşıyordu.
/// `build()` `?? true` diyordu, yani "anahtar yazılmamış" ile "kullanıcı zengin
/// panel istedi" aynı sayılıyordu. Native taraf da aynı varsayımla okuyunca
/// sonuç şu oluyordu: anahtarı bir kez açıp kapatan kullanıcı diske `true`
/// yazdırıyor ve **dinamik paneli kalıcı olarak kapatıyordu** — üstelik geri
/// dönüşü yok, çünkü "otomatik"i ifade eden bir değer kalmamıştı.
///
/// Üç durum artık diskte de ayrıdır:
/// - anahtar **yok**  → [TimerPanelChoice.auto]: cihaz terfiyi veriyorsa Live
///   Update, vermiyorsa zengin panel. Varsayılan budur.
/// - `true`           → [TimerPanelChoice.richPanel]: terfi eden cihazda bile
///   v43 zengin paneli zorla.
/// - `false`          → [TimerPanelChoice.liveUpdate]: terfiyi zorla iste.
///
/// 🔴 Zorlamak **garanti etmez**. Sistem terfiyi vermezse native taraf yine
/// zengin panele düşer; sonucu [timerPromotionVerdictProvider] söyler.
enum TimerPanelChoice {
  /// Kullanıcı seçmedi; cihaz ne yapabiliyorsa o. (Anahtar diskte YOK.)
  auto,

  /// v43 zengin özel panel zorlanır. (Diskte `true`.)
  richPanel,

  /// Android 16 Live Update yolu zorlanır. (Diskte `false`.)
  liveUpdate,
}

/// Diskteki ham değeri seçime çevirir. **Saf.**
///
/// `null` (anahtar yok) [TimerPanelChoice.auto] demektir — "zengin panel"
/// DEĞİL. Bu ayrımı kaybetmek WP-760'ın kök nedeniydi.
TimerPanelChoice timerPanelChoiceFrom(bool? stored) => switch (stored) {
  null => TimerPanelChoice.auto,
  true => TimerPanelChoice.richPanel,
  false => TimerPanelChoice.liveUpdate,
};

class TimerPanelPreferenceNotifier extends Notifier<TimerPanelChoice> {
  @override
  TimerPanelChoice build() => timerPanelChoiceFrom(
    ref.watch(sharedPreferencesProvider).getBool(kTimerPanelExpandedKey),
  );

  Future<void> choose(TimerPanelChoice choice) async {
    final prefs = ref.read(sharedPreferencesProvider);
    switch (choice) {
      // 🔴 `auto` anahtarı SİLER, `false` yazmaz. Bir değer yazmak üçüncü
      // durumu yok eder ve tuzağı geri getirir.
      case TimerPanelChoice.auto:
        await prefs.remove(kTimerPanelExpandedKey);
      case TimerPanelChoice.richPanel:
        await prefs.setBool(kTimerPanelExpandedKey, true);
      case TimerPanelChoice.liveUpdate:
        await prefs.setBool(kTimerPanelExpandedKey, false);
    }
    state = choice;
  }
}

/// Kullanıcının sunum yüzeyi seçimi; varsayılan [TimerPanelChoice.auto].
final timerPanelChoiceProvider =
    NotifierProvider<TimerPanelPreferenceNotifier, TimerPanelChoice>(
      TimerPanelPreferenceNotifier.new,
    );
