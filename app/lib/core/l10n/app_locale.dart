import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/app_prefs.dart';

/// Kullanıcının uygulama içi dil tercihi. Sistem seçeneği, yalnızca sistem dili
/// Türkçeyse Türkçe; diğer tüm dillerde İngilizce olan ürün sözleşmesini korur.
enum AppLanguage { system, english, turkish }

const _appLanguagePreferenceKey = 'app_language_preference';

AppLanguage appLanguageFromPreferences(SharedPreferences prefs) {
  return switch (prefs.getString(_appLanguagePreferenceKey)) {
    'english' => AppLanguage.english,
    'turkish' => AppLanguage.turkish,
    _ => AppLanguage.system,
  };
}

/// Sistem dilini ve kullanıcı tercihini desteklenen iki dile indirger.
Locale resolvePreferredAppLocale(Locale? systemLocale, AppLanguage preference) {
  return switch (preference) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.turkish => const Locale('tr'),
    AppLanguage.system =>
      systemLocale?.languageCode.toLowerCase() == 'tr'
          ? const Locale('tr')
          : const Locale('en'),
  };
}

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
    setActiveAppLocale(
      resolvePreferredAppLocale(PlatformDispatcher.instance.locale, preference),
    );
    return preference;
  }

  Future<void> setLanguage(AppLanguage preference) async {
    state = preference;
    setActiveAppLocale(
      resolvePreferredAppLocale(PlatformDispatcher.instance.locale, preference),
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(_appLanguagePreferenceKey, preference.name);
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);
