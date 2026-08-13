import 'dart:async' show unawaited;
import 'dart:ui' show Locale, PlatformDispatcher, TextDirection;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException, ServicesBinding;
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

/// Dil tercihi daha once acikca kaydedildi mi?
///
/// `system` hem kayit yokken varsayilandir hem de kullanicinin bilincli bir
/// secimi olabilir. Ilk acilis deneyimi bu iki durumu degerden degil anahtarin
/// varligindan ayirir.
bool hasStoredAppLanguagePreference(SharedPreferences prefs) =>
    prefs.containsKey(_appLanguagePreferenceKey);

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

/// WP-559: uygulama ici dil secimini NATIVE yuzeye tasiyan kanal.
///
/// Neden gerekli: bildirim (`StudyTimerService`), widget
/// (`StudyWidgetProviders`) ve alarm ekrani (`AlarmRingActivity`) metinlerini
/// `getString(R.string...)` ile cozer. O cagri `Configuration.locale`e, yani
/// per-app override yoksa **CIHAZ diline** bakar. WP-526 bunu yalniz Dart
/// tarafinda duzeltmisti; native yuzey hic dokunulmamisti, yani telefonu
/// Turkce olup uygulamada Ingilizce secen kullanici bildirimde "Durdur"
/// goruyordu.
const _localeChannel = MethodChannel(
  'com.manilmax.online_study_room/device_integrations',
);

/// Tercihin native karsiligi (BCP-47 etiketleri).
///
/// 🔴 Tercih UC degerlidir. `system` icin **bos liste** gonderilir: per-app
/// override'i temizler. Buraya cihaz dilinin cozulmus halini (`en`/`tr`)
/// yazmak override'i kilitler ve kullanici telefon dilini degistirdiginde
/// uygulama eski dilde kalir.
List<String> nativeLanguageTagsFor(AppLanguage preference) {
  return switch (preference) {
    AppLanguage.english => const ['en'],
    AppLanguage.turkish => const ['tr'],
    AppLanguage.system => const <String>[],
  };
}

/// Yalniz Android'de anlamli; Windows/web'de kanal yok (MissingPluginException
/// firtinasi olmasin diye pesinen kesilir).
bool _nativeLocaleChannelEnabled =
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

@visibleForTesting
set debugNativeLocaleChannelEnabled(bool value) =>
    _nativeLocaleChannelEnabled = value;

/// Secimi native tarafa iletir.
///
/// Doner: native gercekten uyguladi mi. API 33 altinda `LocaleManager` yoktur
/// -> `false`; o cihazlarda native metinler cihaz dilinde kalir.
Future<bool> applyNativeAppLocale(AppLanguage preference) async {
  if (!_nativeLocaleChannelEnabled) return false;
  // 🔴 Binding kurulmamis olabilir: saf `test()` govdesi ya da arka plan
  // isolate'i. `MethodChannel.binaryMessenger` `ServicesBinding.instance`e
  // bakar ve orada "Binding has not yet been initialized" ile duser --
  // [platformLocale] ile birebir ayni tuzak (WP-526). Once yoklanir; yoksa
  // iletilecek native yuzey de yoktur.
  try {
    ServicesBinding.instance;
  } catch (_) {
    return false;
  }
  try {
    final applied = await _localeChannel.invokeMethod<bool>(
      'setApplicationLocales',
      <String, Object?>{'languageTags': nativeLanguageTagsFor(preference)},
    );
    return applied ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

class AppLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final preference = appLanguageFromPreferences(
      ref.watch(sharedPreferencesProvider),
    );
    setActiveAppLocale(resolvePreferredAppLocale(platformLocale(), preference));
    // WP-559: acilista da uygulanir. Tercih onceki oturumda secilmis olabilir;
    // per-app override yalnizca `setLanguage` aninda yazilsaydi, uygulamayi
    // silip kuran ya da override'i sistem ayarlarindan degistiren kullanicida
    // native metinler yeniden cihaz diline duserdi.
    unawaited(applyNativeAppLocale(preference));
    return preference;
  }

  Future<void> setLanguage(AppLanguage preference) async {
    state = preference;
    setActiveAppLocale(resolvePreferredAppLocale(platformLocale(), preference));
    // WP-734: tercih ONCE kalici yazilir, native override sonra beklenir.
    // Ters sirada `applyNativeAppLocale` bir yanit donmezse (kanal cevapsiz
    // kalirsa) kullanicinin sectigi dil hic kaydedilmez ve uygulama bir
    // sonraki acilista yine dil sorar. Native override en iyi cabadir;
    // kaliciligin ona bagli olmamasi gerekir.
    final native = applyNativeAppLocale(preference);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_appLanguagePreferenceKey, preference.name);
    await native;
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
