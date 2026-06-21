import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/prefs/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const OnlineStudyRoomApp(),
    ),
  );
}

class OnlineStudyRoomApp extends StatelessWidget {
  const OnlineStudyRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Çalışma Sınıfı',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Tasarım referansı (kardeşin) koyu temalı; varsayılan koyu.
      themeMode: ThemeMode.dark,
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
      home: const SelectionArea(child: AuthGate()),
    );
  }
}
