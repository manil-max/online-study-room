import 'dart:ui' show Locale, PlatformDispatcher, TextDirection;

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/app_prefs.dart';

/// WP-457 release contract: system + EN/TR.
///
/// Legacy DE/AR preferences remain readable and safely fall back to EN.
enum AppLanguage { system, english, turkish }

const _appLanguagePreferenceKey = 'app_language_preference';

/// Must stay aligned with the generated `AppLocalizations.supportedLocales`.
const kSupportedLanguageCodes = {'en', 'tr'};

AppLanguage appLanguageFromPreferences(SharedPreferences prefs) {
  return switch (prefs.getString(_appLanguagePreferenceKey)) {
    'english' => AppLanguage.english,
    'turkish' => AppLanguage.turkish,
    'arabic' || 'german' => AppLanguage.english,
    _ => AppLanguage.system,
  };
}

/// Kullanıcı tercihi veya sistem dilini desteklenen dillere indirger.
Locale resolvePreferredAppLocale(Locale? systemLocale, AppLanguage preference) {
  return switch (preference) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.turkish => const Locale('tr'),
    AppLanguage.system => _fromSystem(systemLocale),
  };
}

Locale _fromSystem(Locale? systemLocale) {
  final code = systemLocale?.languageCode.toLowerCase() ?? 'en';
  if (kSupportedLanguageCodes.contains(code)) {
    return Locale(code);
  }
  // Eski sözleşme: bilinmeyen → EN (TR yalnız tr).
  return const Locale('en');
}

/// Cihazin dili.
///
/// 🔴 `PlatformDispatcher.instance` DEGIL, binding uzerinden okunur. Test
/// binding'i `PlatformDispatcher.instance`'i degistirmez; dogrudan ona bakan
/// kod testte cihaz dili ayarlanamaz hale gelir ve "sistem dili" davranisi
/// hic sinanamaz. WP-526'da tam bu oldu: sistem+Turkce testi, kod dogru olsa
/// bile host dilini okuyup kirmizi dustu.
Locale platformLocale() {
  try {
    return WidgetsBinding.instance.platformDispatcher.locale;
  } catch (_) {
    // Binding hic kurulmamis olabilir: saf `test()` govdesi ya da arka plan
    // isolate'i. `WidgetsBinding.instance` o durumda "Binding has not yet been
    // initialized" ile duser -- WP-526'nin ilk halinde tam bu oldu ve dort
    // test kirildi. Burada platforma dogrudan dusmek dogru davranistir:
    // test binding'i yoksa ezilecek bir deger de yoktur.
    return PlatformDispatcher.instance.locale;
  }
}

bool isRtlLocale(Locale locale) => false;

TextDirection textDirectionForLocale(Locale locale) =>
    isRtlLocale(locale) ? TextDirection.rtl : TextDirection.ltr;

Locale _activeAppLocale = resolvePreferredAppLocale(
  PlatformDispatcher.instance.locale,
  AppLanguage.system,
);

/// BuildContext olmayan ortak biçimleyiciler için uygulamanın etkin dili.
Locale get activeAppLocale => _activeAppLocale;

void setActiveAppLocale(Locale locale) {
  _activeAppLocale = locale;
}

class AppLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final preference = appLanguageFromPreferences(
      ref.watch(sharedPreferencesProvider),
    );
    setActiveAppLocale(resolvePreferredAppLocale(platformLocale(), preference));
    return preference;
  }

  Future<void> setLanguage(AppLanguage preference) async {
    state = preference;
    setActiveAppLocale(resolvePreferredAppLocale(platformLocale(), preference));
    await ref
        .read(sharedPreferencesProvider)
        .setString(_appLanguagePreferenceKey, preference.name);
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);

/// Sunucudan gelen İÇERİĞİN (SSS gibi) hangi dilde istendiği.
///
/// 🔴 Bunu `appLanguageProvider`'dan doğrudan türetme. O provider kullanıcının
/// **tercihini** tutar ve tercih üç değerlidir: `system`, `english`, `turkish`.
/// `preference == AppLanguage.english ? 'en' : 'tr'` yazmak `system`'i sessizce
/// Türkçe sayar — telefonu İngilizce olan kullanıcı arayüzü İngilizce görür
/// ama içeriği Türkçe alır. Sahip bunu 2026-08-08'de sahada yakaladı (SSS
/// soruları İngilizce dilde Türkçe geliyordu).
///
/// Etkin dil daima [resolvePreferredAppLocale] üzerinden çözülür; `system`
/// seçiliyken cihazın dili kullanılır.
final contentLanguageCodeProvider = Provider<String>((ref) {
  final preference = ref.watch(appLanguageProvider);
  return resolvePreferredAppLocale(platformLocale(), preference).languageCode;
});
