import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, FlutterError;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_build_manifest.dart';
import 'core/config/build_configuration_error_app.dart';
import 'core/config/supabase_config.dart';
import 'core/desktop/desktop_window.dart';
import 'core/l10n/system_localizations.dart';
import 'core/l10n/app_locale.dart';
import 'core/notifications/alarm_notification_service.dart';
import 'core/notifications/app_push_notification_service.dart';
import 'core/notifications/native_alarm_bridge.dart';
import 'core/notifications/timer_notification_service.dart';
import 'core/observability/observability_service.dart';
import 'core/prefs/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_settings.dart';
import 'core/time_engine/device_timezone.dart';
import 'features/auth/auth_gate.dart';
import 'features/desktop/compact_focus_view.dart';
import 'l10n/app_localizations.dart';

import 'package:home_widget/home_widget.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WP-227: Kanal/backend kimliği bütün veri ve native servislerden önce
  // doğrulanır. Beta→production veya stable→staging (ya da eksik release env)
  // hiçbir Supabase/native write başlatmadan güvenli hata yüzeyine düşer.
  final AppBuildManifest buildManifest;
  try {
    buildManifest = AppBuildManifest.current;
  } on BuildConfigurationException catch (error) {
    runApp(BuildConfigurationErrorApp(errorCode: error.code));
    return;
  }

  // BuildContext oluşmadan da sistem dil sözleşmesini koru. Bu değer yalnız
  // Windows cold-start hata yüzeyinde kullanılır.
  final systemL10n = await loadSystemLocalizations();

  // Windows cold-start: framework hatalarını boş beyaz yüzey yerine okunur
  // metinle göster (debug + release profil).
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    ErrorWidget.builder = (details) {
      return Material(
        color: const Color(0xFF1A1020),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              systemL10n.authBeklenmeyenBirHataOlustu,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      );
    };
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
  }

  // Android'e özgü servisler (kalıcı bildirim + ana ekran widget'ı) yalnız
  // Android'de başlatılır; masaüstü/web'de bu eklentiler bulunmaz (çökme önlenir).
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  if (isAndroid) {
    await TimerNotificationService.instance.initialize();
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  }

  // Masaüstü: bounds hazırlanır ama pencere henüz show edilmez (beyaz HWND önlemi).
  await initDesktopWindow();

  // InMemory yalnız açıkça local+ALLOW_IN_MEMORY=true derlemesinde mümkündür.
  // Beta/stable için eksik anahtar veya yanlış backend yukarıdaki kapıda kapanır.
  if (buildManifest.usesSupabase) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // "publishable" = eski "anon public" anahtarın yeni adı (aynı anahtar).
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  // Yerel kalıcı ayarlar (Ana Sayfa yerleşimi, saat stili vb. için).
  final prefs = await SharedPreferences.getInstance();
  await ObservabilityService.instance.initialize(prefs);
  // WP-266: Yalnız Android + eksiksiz Firebase config'te FCM'i başlatır.
  // Config yok/yarımsa uygulama açılır; Bildirim Sağlığı açık nedeni gösterir.
  await AppPushNotificationService.instance.bootstrap(prefs);

  // Saat P0: cihaz TZ + alarm servisi; boot sonrası native mirror reschedule.
  await DeviceTimezone.ensureInitialized();
  // Windows'ta yalnızca Android ayarlı FLN init bazı ortamlarda takılabiliyor;
  // masaüstünde try/catch + atla (alarm UI yine de güvenli no-op).
  try {
    await AlarmNotificationService.instance.initialize();
  } catch (e, st) {
    debugPrint('AlarmNotificationService.initialize failed: $e\n$st');
  }
  if (isAndroid) {
    final bridge = NativeAlarmBridge.instance;
    if (bridge.consumeRescheduleFlag(prefs)) {
      // Boot/timezone: native zaten mirror'dan kurdu; bayrağı temizle.
    }
    await bridge.rescheduleFromMirror();
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const OnlineStudyRoomApp(),
    ),
  );

  // İlk frame sonrası pencereyi göster (Windows cold-start / WP-53-debug).
  if (isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(showDesktopWindowWhenReady());
    });
  }
}

class OnlineStudyRoomApp extends ConsumerWidget {
  const OnlineStudyRoomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WP-54/55: seçili sanat ailesi hem açık hem koyu moda uygulanır.
    // Eski yol (karşı moda sabit nordic/campfire) seçimi yok sayıyordu.
    final settings = ref.watch(themeSettingsProvider);
    final language = ref.watch(appLanguageProvider);
    // Sistem seçeneğinde locale'i MaterialApp belirler. Bu, Android'in çalışma
    // anında değişen sistem dilini ve widget testlerindeki platform locale'ini
    // doğru geçirir; manuel seçimde ise açık locale ile kullanıcı tercihi sabit
    // kalır.
    final locale = language == AppLanguage.system
        ? null
        : resolvePreferredAppLocale(
            PlatformDispatcher.instance.locale,
            language,
          );
    final family = settings.family;
    final ThemeData lightTheme;
    final ThemeData darkTheme;
    // Hazır/özel palet seçildiyse AppPalette renkleri; Tema Stüdyosu ailesi değil.
    // (navy palet → campfire_night turuncu bug'ı WP-71 ile kapatıldı.)
    if (settings.usePaletteColors) {
      lightTheme = AppTheme.light(settings.palette);
      darkTheme = AppTheme.dark(settings.palette);
    } else {
      lightTheme = AppTheme.fromFamily(family, Brightness.light);
      darkTheme = AppTheme.fromFamily(family, Brightness.dark);
    }
    return MaterialApp(
      locale: locale,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settings.mode,
      // Yalnız birincil sistem dili Türkçeyse TR; diğer tüm diller EN'e düşer.
      localeResolutionCallback: (systemLocale, supportedLocales) {
        final resolved = resolvePreferredAppLocale(systemLocale, language);
        setActiveAppLocale(resolved);
        return resolved;
      },
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Masaüstünde uygulamanın etrafına "üstte tut / mini pencere" kontrol
      // kümesi eklenir; web/mobilde child olduğu gibi döner.
      // child null iken shrink yerine koyu zemin (beyaz flaş yok).
      // WP-155: RTL dillerde (ar) Directionality MaterialApp locale ile gelir;
      // builder'da ekstra sarmalama gerekmez. Icon mirroring: Icons.*_outlined
      // çoğunluk simetrik; chevron/back Navigation otomatik RTL.
      builder: (context, child) {
        // beta-v41 WP-G: uygulama geneli aşağı-çek-yenile kaldırıldı (kullanıcı
        // isteği). Veri realtime/provider + oturum bitince olay bazlı tazelenir;
        // başarım sayfasında yanlışlıkla tetiklenen yenileme/scroll zıplaması biter.
        final wrapped = desktopChrome(
          child ??
              const ColoredBox(
                color: Color(0xFF0B1020),
                child: SizedBox.expand(),
              ),
          compactChild: const CompactFocusView(),
        );
        return wrapped;
      },
      home: const AuthGate(),
    );
  }
}

/// Uygulamanın açık EN/TR sözleşmesi: Türkçe sistemlerde TR, diğer her yerde EN.
///
/// [supportedLocales] callback imzasının parçasıdır; destek kümesi üretilen
/// [AppLocalizations.supportedLocales] üzerinden MaterialApp'e verilir.
Locale resolveAppLocale(
  Locale? systemLocale,
  Iterable<Locale> supportedLocales,
) {
  return resolvePreferredAppLocale(systemLocale, AppLanguage.system);
}
