@Tags(['golden'])
library;

// WP-839 — PLAY MAĞAZA EKRAN GÖRÜNTÜLERİ (Türkçe).
//
// Bu bir golden karşılaştırması DEĞİLDİR: hiçbir fixture üretmez, hiçbir şeyi
// sabitlemez. Mağaza sayfasına yüklenecek kareleri uygulamanın **gerçek**
// ekranlarından üretir; böylece mağazadaki görsel ile uygulamanın kendisi
// tutarlı olur (sahip isteği: "mağaza görsellerini de ayarlayabiliyorsak
// bundan yapmamız lazım, tutarlı olsun").
//
// Kare üstüne Türkçe kısa bir başlık bandı çizilir — mağaza karelerinde
// alışılmış biçim budur; kullanıcı listede kayarken ne gördüğünü okur.
//
// WP-853: kareler boş hesapla değil, `store_seed.dart`taki örnek hesapla
// (3 haftalık oturum, 4 ders, koşan sayaç, grup, rozetler) çekilir.
//
// Normal pakette koşmaz: `golden` etiketli ve ayrıca `STORE_SHOT_DIR` ortam
// değişkeni verilmedikçe atlanır.
//
// Kullanım (app/ içinde):
//   STORE_SHOT_DIR=<klasör> flutter test test/marketing/store_shots_wp839_test.dart \
//     --dart-define-from-file=env.json --tags=golden
//
// WP-905 — App Store (iPhone 6.9") kareleri: aynı beş kare, 1320x2868 dikey,
// iOS görünümüyle (`debugDefaultTargetPlatformOverride = TargetPlatform.iOS`):
//   STORE_SHOT_TARGET=ios STORE_SHOT_DIR=../docs/app-store-kareleri \
//     flutter test test/marketing/store_shots_wp839_test.dart \
//     --dart-define-from-file=env.json --tags=golden
// `STORE_SHOT_TARGET` verilmezse (ya da `play` ise) Play kareleri eskisi gibi
// 1080x1920 üretilir.
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/features/profile/appearance_screen.dart';
import 'package:online_study_room/features/profile/social_profile_screen.dart';
import 'package:online_study_room/features/stats/stats_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store_seed.dart';

const _shotKey = ValueKey('store-shot');
const _homeWidgetChannel = MethodChannel('home_widget');

/// Mağaza karesinin ölçüsü: Play telefon karesi için 1080x1920 (9:16) yeterli.
/// 540x960 dp × pixelRatio 2 tam bunu verir.
const _frameSize = Size(540, 960);

/// WP-905: App Store 6.9" iPhone karesi 1320x2868 ister; 660x1434 dp ×
/// pixelRatio 2 tam bunu verir.
const _iosFrameSize = Size(660, 1434);

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final loader = FontLoader(family)
    ..addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  await loader.load();
}

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    const dir = 'bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', '$root/$dir/roboto-regular.ttf');
    await _loadFont('MaterialIcons', '$root/$dir/materialicons-regular.otf');
  }
  await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
  // WP-921: tema kartlarının minyatürü hazır temanın kendi yazı ailesini
  // (`AppTypography.standard`: 'serif' / 'monospace') kullanır. Cihazda bunlar
  // sistem fontuna çözülür; test motorunda karşılığı yok ve boş kutu çiziliyor.
  // Uygulamanın paketlediği serif ve eş aralıklı font bu adlarla yüklenir.
  await _loadFont('serif', 'assets/fonts/Literata-Variable.ttf');
  await _loadFont('monospace', 'assets/fonts/JetBrainsMono-Variable.ttf');
  // WP-853: kamp ateşi rozetindeki ve kamp hayvanı satırındaki emoji'ler test
  // fontunda kutu çiziliyordu. Android'in kendi emoji fontu (Noto) Flutter
  // kaynağında var; yoksa Windows'unki denenir.
  if (root != null && root.isNotEmpty) {
    await _loadFont(
      'EmojiFallback',
      '$root/engine/src/flutter/txt/third_party/fonts/NotoColorEmoji.ttf',
    );
  }
  await _loadFont('EmojiFallback', r'C:\Windows\Fonts\seguiemj.ttf');
}

Future<SharedPreferences> _prefs() async {
  // Mağaza karesi yeni kullanıcının göreceği hâli göstermeli: WP-841
  // karşılama teması.
  SharedPreferences.setMockInitialValues({
    'theme_family': kFirstRunFamilyId,
    'theme_color_source': 'family',
    'theme_mode': 'light',
  });
  return SharedPreferences.getInstance();
}

const _fallback = ['Inter', 'EmojiFallback'];

ThemeData _readable(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(
    fontFamily: 'Roboto',
    fontFamilyFallback: _fallback,
  ),
  // WP-853: uygulama çubuğu başlığı `textTheme`den değil kendi stilinden
  // okunur; ailesi boş kalınca test fontu (siyah kutular) çiziliyordu.
  appBarTheme: theme.appBarTheme.copyWith(
    titleTextStyle: (theme.appBarTheme.titleTextStyle ?? const TextStyle())
        .copyWith(fontFamily: 'Roboto', fontFamilyFallback: _fallback),
  ),
);

/// Başlık bandı + telefon ekranı. Bant rengi temanın kendi turuncusudur;
/// mağaza karesi ile uygulama aynı kimliği taşır.
class _StoreFrame extends ConsumerWidget {
  const _StoreFrame({required this.caption, required this.screen});

  final String caption;
  final Widget screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final family = settings.family;
    final theme = _readable(AppTheme.fromFamily(family, Brightness.light));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      themeMode: ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: RepaintBoundary(
          key: _shotKey,
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                SizedBox(
                  height: 132,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          // Bant `MaterialApp`in home agacinin DISINDA cizilir;
                          // oradaki varsayilan stil sari alt cizgi koyar.
                          decoration: TextDecoration.none,
                          fontFamily: 'Roboto',
                          fontSize: 30,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      home: screen,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs,
  StoreSeed seed,
  String caption,
  Widget screen,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: seed.overrides(prefs),
      child: _StoreFrame(caption: caption, screen: screen),
    ),
  );
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
  final outDir = Platform.environment['STORE_SHOT_DIR'];
  final skip = outDir == null || outDir.isEmpty;
  final ios = Platform.environment['STORE_SHOT_TARGET'] == 'ios';

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

  testWidgets('mağaza kareleri (tr${ios ? ', ios' : ''})', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = ios ? _iosFrameSize : _frameSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Directory(outDir!).createSync(recursive: true);

    final prefs = await _prefs();
    // WP-853: süre biçimleyicisi (`formatHuman`) `BuildContext` değil
    // uygulamanın etkin dilini okur; ayarlanmazsa Türkçe arayüzde "2h 35m"
    // gibi İngilizce birimler çiziliyordu.
    setActiveAppLocale(const Locale('tr'));
    addTearDown(() => setActiveAppLocale(const Locale('en')));
    final seed = StoreSeed.build(DateTime.now());
    seed.markToursSeen(prefs);

    final frames = <(String, String, Widget)>[
      ('01-ana-ekran', 'Süreni ölç, panonu kendin kur', const HomeScreen()),
      ('02-kamp-atesi', 'Birlikte çalış', const ClassroomScreen()),
      ('03-istatistik', 'İlerlemeni gör', const StatsScreen()),
      (
        '04-rozetler',
        'Emeğin kayıtlı kalsın',
        SocialProfileScreen(profile: seed.me),
      ),
      ('05-tema', 'Kendine göre ayarla', const AppearanceScreen()),
    ];
    // iOS görünümü (Cupertino kaydırma/geçişler, platforma bağlı dallar).
    // Test bitmeden sıfırlanmalı: çerçeve test sonunda foundation
    // değişkenlerinin boş olduğunu doğrular.
    if (ios) debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      for (final (file, caption, screen) in frames) {
        await _pump(tester, prefs, seed, caption, screen);
        await _shoot(tester, '$outDir/$file.png');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}
