import 'dart:ui';

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
Future<AppLocalizations> loadSystemLocalizations([Locale? requested]) {
  final resolved = requested == null
      ? activeAppLocale
      : resolvePreferredAppLocale(requested, AppLanguage.system);
  return AppLocalizations.delegate.load(resolved);
}
