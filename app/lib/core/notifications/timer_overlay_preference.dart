/// 🔴 WP-764 — yüzen sayaç şeridinin **kullanıcı anahtarı**.
///
/// Altı tur boyunca "dinamik panel" Android'in bildirim yüzeyinden istendi ve
/// çıkmadı. Sebep tahmin değil, ölçüm: sahibin Galaxy S23'ünde sistem terfiyi
/// VERİYOR (`timer_promotion_verdict.dart` bunu `GRANTED` okuyor) ama Samsung
/// ortada hiçbir şey ÇİZMİYOR. Platformdan bir şey beklemenin sonu buraya
/// kadardı; çözüm kendi penceremizi açmak — ekranın üstünde yüzen bir şerit.
///
/// Şeridi native taraf çizer (`overlay/TimerOverlay.kt`); bu dosya yalnız
/// kullanıcının açıp kapatabildiği anahtarı tutar.
///
/// 🔴 Ad `flutter.` öneki TAŞIMAZ. `shared_preferences` Android'de her anahtarı
/// `flutter.` ile önekleyerek yazar; native taraf bu yüzden tam adı
/// (`flutter.timer_overlay_enabled`) okur. İki adı tek yerde eşleyen sözleşme
/// [kTimerOverlayEnabledNativeKey] ve nöbetçi testtedir. Aynı tuzağın önceki
/// kurbanı `timer_panel_preference.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';

/// Şerit anahtarının Dart'tan görünen adı.
const kTimerOverlayEnabledKey = 'timer_overlay_enabled';

/// Native tarafın gördüğü tam anahtar (`shared_preferences` öneki dahil).
///
/// Karşılığı: `TimerOverlay.KEY_ENABLED`.
const kTimerOverlayEnabledNativeKey = 'flutter.$kTimerOverlayEnabledKey';

/// Yüzen sayaç şeridi açık mı; **varsayılan `false`**.
///
/// 🔴 Varsayılanın kapalı olması bir üslup tercihi değil. Bu turda üç kez
/// deneysel bir yol varsayılan yapıldı ve çalışan bildirimi bozdu (v71, v74).
/// Sahibin kuralı kendi cümlesiyle: *"test ederken sadece biz görelim,
/// diğerlerinde normal olsun"*. Şerit KAPALI doğar; açan kişi onu bilerek
/// açar.
///
/// 🔴 Native taraf da aynı varsayılanı okur (`prefs.getBoolean(KEY_ENABLED,
/// false)`). İki taraftan biri `true`'ya kayarsa anahtarı hiç görmemiş
/// kullanıcıda şerit kendiliğinden belirir.
class TimerOverlayPreferenceNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(kTimerOverlayEnabledKey) ??
      false;

  Future<void> setEnabled(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kTimerOverlayEnabledKey, value);
    state = value;
  }
}

/// Kullanıcının şerit tercihi; varsayılan kapalı.
final timerOverlayEnabledProvider =
    NotifierProvider<TimerOverlayPreferenceNotifier, bool>(
      TimerOverlayPreferenceNotifier.new,
    );
