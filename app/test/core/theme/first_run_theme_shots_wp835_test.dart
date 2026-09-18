@Tags(['golden'])
library;

// WP-835 — SAHİP SEÇSİN DİYE ÜRETİLEN ADAY TEMA KARELERİ.
//
// Bu bir golden karşılaştırması DEĞİLDİR: hiçbir şeyi sabitlemez, hiçbir
// fixture üretmez. Karşılama tema adaylarını aynı iki ekranda (ana ekran +
// giriş ekranı) gerçek PNG olarak yazar; sahip bakıp karar verir.
//
// Normal test paketinde koşmaz: dosya `golden` etiketli (paket
// `--exclude-tags=golden` ile koşuyor) ve ayrıca `WP835_SHOT_DIR` ortam
// değişkeni verilmedikçe atlanır — golden kapısı da kare üretmesin.
//
// Kullanım (app/ içinde):
//   WP835_SHOT_DIR=<klasör> flutter test \
//     test/core/theme/first_run_theme_shots_wp835_test.dart \
//     --dart-define-from-file=env.json --tags=golden
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kare üretilecek aile(ler) (`theme_presets.dart`).
///
/// WP-835'te üç sıcak aday vardı (`campfire_night`, `coffee_library`,
/// `soft_cream`); sahip üçünü de beğenmedi ve **açık** bir karşılama istedi:
/// "3. seçenekteki gibi ama logodaki turuncu renkte olsun." WP-841 bunun
/// karşılığı olan `campfire_day`'i üretti; karesi de artık onun.
const _candidates = <String>['campfire_day'];

const _shotKey = ValueKey('wp835-shot');

/// Ana ekrandaki sayaç kartı native widget kanalını çağırır; testte karşılığı
/// yok, boş yanıt yeter (kare çizimini ilgilendirmiyor).
const _homeWidgetChannel = MethodChannel('home_widget');

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final loader = FontLoader(family)
    ..addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  await loader.load();
}

/// Test ortamı ne metin ne de simge yazı tipi yükler; ikisi de kutu çizer.
/// Cihazdaki görünüme en yakın kare için Roboto + Material simgeleri SDK
/// önbelleğinden, yedek olarak uygulamanın gömdüğü Inter alınır.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    const dir = 'bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', '$root/$dir/roboto-regular.ttf');
    await _loadFont('MaterialIcons', '$root/$dir/materialicons-regular.otf');
  }
  await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
}

/// Adayı seçmiş bir kurulumun prefs'i.
Future<SharedPreferences> _prefs(String familyId) async {
  final preset = themePresetById(familyId);
  SharedPreferences.setMockInitialValues({
    'theme_family': familyId,
    'theme_color_source': 'family',
    'theme_mode': preset.brightness == Brightness.dark ? 'dark' : 'light',
  });
  return SharedPreferences.getInstance();
}

/// Yüklenen yazı tipini tüm metin yuvalarına bağlar; renk/şekil token'larına
/// dokunmaz — sahibin baktığı şey renk atmosferi.
ThemeData _readable(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['Inter'],
  ),
);

/// Temayı `main.dart` ile aynı yoldan kurar: `themeSettingsProvider` → aile →
/// `AppTheme.fromFamily`. Kare böylece gerçekten uygulamanın gördüğü tema olur.
class _ShotApp extends ConsumerWidget {
  const _ShotApp(this.screen);

  final Widget screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final family = settings.family;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _readable(AppTheme.fromFamily(family, Brightness.light)),
      darkTheme: _readable(AppTheme.fromFamily(family, Brightness.dark)),
      themeMode: settings.mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: RepaintBoundary(key: _shotKey, child: child),
      ),
      home: screen,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs,
  Widget screen,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: _ShotApp(screen),
    ),
  );
  // Canlı sayaç/animasyon yüzünden ağaç hiç durulmayabilir; kare için birkaç
  // kare yeterli.
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } catch (_) {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }
}

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final outDir = Platform.environment['WP835_SHOT_DIR'];
  // Klasör verilmediyse kare yazılacak yer yok: test atlanır (golden kapısı
  // dâhil hiçbir otomatik koşum dosya üretmez).
  final skip = outDir == null || outDir.isEmpty;

  setUp(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetChannel, null);
  });

  for (final familyId in _candidates) {
    testWidgets('$familyId · ana ekran ve giriş ekranı karesi', (tester) async {
      await tester.runAsync(_loadFonts);
      // Telefon boyu (≈390x844 dp).
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Directory(outDir!).createSync(recursive: true);

      final prefs = await _prefs(familyId);

      await _pump(tester, prefs, const HomeScreen());
      await _shoot(tester, '$outDir/$familyId-home.png');

      await _pump(tester, prefs, const AuthScreen());
      await _shoot(tester, '$outDir/$familyId-auth.png');
    }, skip: skip);
  }
}
