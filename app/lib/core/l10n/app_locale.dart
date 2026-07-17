import 'dart:ui' show Locale, PlatformDispatcher, TextDirection;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/app_prefs.dart';

/// WP-155: sistem + EN/TR + AR (RTL) + DE dil paketleri.
enum AppLanguage { system, english, turkish, arabic, german }

const _appLanguagePreferenceKey = 'app_language_preference';

const kSupportedLanguageCodes = {'en', 'tr', 'ar', 'de'};

AppLanguage appLanguageFromPreferences(SharedPreferences prefs) {
  return switch (prefs.getString(_appLanguagePreferenceKey)) {
    'english' => AppLanguage.english,
    'turkish' => AppLanguage.turkish,
    'arabic' => AppLanguage.arabic,
    'german' => AppLanguage.german,
    _ => AppLanguage.system,
  };
}

/// Kullanıcı tercihi veya sistem dilini desteklenen dillere indirger.
Locale resolvePreferredAppLocale(Locale? systemLocale, AppLanguage preference) {
  return switch (preference) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.turkish => const Locale('tr'),
    AppLanguage.arabic => const Locale('ar'),
    AppLanguage.german => const Locale('de'),
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

/// RTL diller (şimdilik Arapça).
bool isRtlLocale(Locale locale) =>
    locale.languageCode.toLowerCase() == 'ar';

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
