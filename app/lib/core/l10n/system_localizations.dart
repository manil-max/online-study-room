import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// BuildContext bulunmayan bildirim/widget arka planlarında uygulamanın etkin
/// dilini yükler.
///
/// 🔴 "Sistem dili" YETMEZ (WP-526). Bu fonksiyon eskiden daima
/// [AppLanguage.system] ile çözüyordu; yani telefonu Türkçe olup uygulamada
/// İngilizceyi seçen kullanıcı arayüzü İngilizce görürken **bildirimleri
/// Türkçe** alıyordu. Artık [activeAppLocale] kullanılır — kullanıcının
/// tercihi [AppLanguageNotifier] tarafından oraya yazılır.
///
/// 🔴 Tercih burada **SharedPreferences'tan okunmaz.** İlk düzeltme öyle
/// yapıyordu ve bildirim testlerini kilitledi: eklenti sahte değerlerle
/// kurulmadığında `SharedPreferences.getInstance()` hiç tamamlanmıyor,
/// çağıran da sonsuza kadar bekliyor (`app_notification_coordinator_test`
/// 10 dakikada zaman aşımına düştü). Bellekteki çözülmüş dili okumak hem
/// senkron hem eklentisizdir.
///
/// Bilinen sınır: FCM arka plan isolate'i ayrı bir bellek alanıdır ve orada
/// [activeAppLocale] varsayılan değerindedir, yani o yoldaki bildirim cihazın
/// diline düşer. Bu, düzeltme öncesi davranışın aynısıdır — kötüleşme yok.
///
/// 🔴 Bu dosyanın kapsamı YALNIZ Dart'tır. Native yüzeyler — sayaç bildirimi
/// (`StudyTimerService`), widget (`StudyWidgetProviders`), alarm ekranı
/// (`AlarmRingActivity`) — metnini buradan değil `getString(R.string…)` ile
/// alır ve o çağrı `Configuration.locale`e bakar. WP-526 bu sınırı yanlışlıkla
/// "yalnız FCM isolate'i" sanıyordu; gerçekte native yüzeyin tamamı cihaz
/// dilindeydi. Çözüm WP-559'da native tarafa taşındı: `localeConfig` +
/// `LocaleManager.setApplicationLocales` (bkz. [applyNativeAppLocale]).
Future<AppLocalizations> loadSystemLocalizations([Locale? requested]) {
  final resolved = requested == null
      ? activeAppLocale
      : resolvePreferredAppLocale(requested, AppLanguage.system);
  return AppLocalizations.delegate.load(resolved);
}

/// Kullanicinin uygulamada SECTIGI dil — bellekteki global degil, diskteki
/// tercih.
///
/// 🔴 WP-719: [activeAppLocale] **degisken bir global**dir ve ilk degeri
/// cihazin dilinden ([AppLanguage.system]) tohumlanir; kullanicinin tercihine
/// ancak `AppLanguageNotifier` kurulunca ya da `MaterialApp`in
/// `localeResolutionCallback`i kosunca duzeltilir. Ana ekran widget'larinin
/// metnini yazan yollar bundan once (acilis turu) veya baska bir bellek
/// alaninda (arka plan isolate'i) kosabilir; o zaman diske YANLIS dil yazilir
/// ve kart bir daha yazilana kadar orada kalir. Sahibin cihazinda olculen
/// celiski buydu: uygulama Turkce, widget "Tasks / No tasks yet".
///
/// 🔴 Burada `SharedPreferences.getInstance()` **cagrilmaz** — cagiran zaten
/// yuklenmis ornegi verir. Eklenti sahte degerlerle kurulmadiginda o cagri hic
/// tamamlanmaz ve cagirani sonsuza kadar bekletir (dosyanin ustundeki not).
Locale appLocaleFromPrefs(SharedPreferences prefs) => resolvePreferredAppLocale(
  platformLocale(),
  appLanguageFromPreferences(prefs),
);

/// Prefs elde varken dogru dili yukler **ve** [activeAppLocale]'i tohumlar.
///
/// Tohumlama isin yarisidir: ayni turda `loadSystemLocalizations()` ile metin
/// ureten diger widget yollari (siralama/hedef anlik goruntuleri,
/// `study_providers.dart`) da boylece uygulama dilini konusur.
Future<AppLocalizations> loadAppLocalizations(SharedPreferences prefs) {
  final resolved = appLocaleFromPrefs(prefs);
  setActiveAppLocale(resolved);
  return AppLocalizations.delegate.load(resolved);
}
