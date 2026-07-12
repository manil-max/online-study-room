import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/desktop/desktop_window.dart';
import 'core/notifications/timer_notification_service.dart';
import 'core/observability/observability_service.dart';
import 'core/prefs/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_settings.dart';
import 'features/auth/auth_gate.dart';

import 'package:home_widget/home_widget.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android'e özgü servisler (kalıcı bildirim + ana ekran widget'ı) yalnız
  // Android'de başlatılır; masaüstü/web'de bu eklentiler bulunmaz (çökme önlenir).
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (isAndroid) {
    await TimerNotificationService.instance.initialize();
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  }

  // Masaüstünde (Windows/macOS/Linux) pencere boyutu/başlığı hazırlanır;
  // web/mobilde no-op.
  await initDesktopWindow();

  // Anahtarlar verilmişse Supabase'i başlat; verilmemişse uygulama bellek-içi
  // modda açılır (Supabase'siz hızlı deneme için). Bkz. core/config/supabase_config.dart
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // "publishable" = eski "anon public" anahtarın yeni adı (aynı anahtar).
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  // Yerel kalıcı ayarlar (Ana Sayfa yerleşimi, saat stili vb. için).
  final prefs = await SharedPreferences.getInstance();
  await ObservabilityService.instance.initialize(prefs);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const OnlineStudyRoomApp(),
    ),
  );
}

class OnlineStudyRoomApp extends ConsumerWidget {
  const OnlineStudyRoomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tema tercihleri (palet + mod) kişiye özel, cihazda kalıcı.
    final settings = ref.watch(themeSettingsProvider);
    return MaterialApp(
      title: 'Odak Kampı',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.palette),
      darkTheme: AppTheme.dark(settings.palette),
      themeMode: settings.mode,
      // UI metinleri Türkçe; tarih seçici vb. yerleşik bileşenler de Türkçe görünür.
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Metinler fare ile seçilebilsin (web). SelectionArea, Navigator'ın
      // Overlay'inin altında olmalı; bu yüzden builder yerine home'u sarıyoruz.
      // Masaüstünde uygulamanın etrafına "üstte tut / mini pencere" kontrol
      // kümesi eklenir; web/mobilde child olduğu gibi döner.
      builder: (context, child) =>
          desktopChrome(child ?? const SizedBox.shrink()),
      home: const SelectionArea(child: AuthGate()),
    );
  }
}
