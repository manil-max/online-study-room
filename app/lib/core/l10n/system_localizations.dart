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
/// Türkçe** alıyordu. Kullanıcının kaydettiği tercih önce okunur.
///
/// Tercih okunamazsa (arka plan izolasyonunda eklenti hazır değilse) eski
/// davranışa düşülür: bildirim metinsiz kalmaktansa sistem dilinde çıksın.
Future<AppLocalizations> loadSystemLocalizations([Locale? requested]) async {
  final systemLocale = requested ?? PlatformDispatcher.instance.locale;
  var preference = AppLanguage.system;
  try {
    preference = appLanguageFromPreferences(
      await SharedPreferences.getInstance(),
    );
  } catch (_) {
    // Tercih okunamadı; sistem diline düşülür.
  }
  final resolved = resolvePreferredAppLocale(systemLocale, preference);
  return AppLocalizations.delegate.load(resolved);
}
