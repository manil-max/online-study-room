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
// Normal pakette koşmaz: `golden` etiketli ve ayrıca `STORE_SHOT_DIR` ortam
// değişkeni verilmedikçe atlanır.
//
// Kullanım (app/ içinde):
//   STORE_SHOT_DIR=<klasör> flutter test test/marketing/store_shots_wp839_test.dart \
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
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/features/profile/appearance_screen.dart';
import 'package:online_study_room/features/stats/stats_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shotKey = ValueKey('store-shot');
const _homeWidgetChannel = MethodChannel('home_widget');

/// Mağaza karesinin ölçüsü: Play telefon karesi için 1080x1920 (9:16) yeterli.
/// 540x960 dp × pixelRatio 2 tam bunu verir.
const _frameSize = Size(540, 960);

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

ThemeData _readable(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['Inter'],
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
  String caption,
  Widget screen,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

  testWidgets('mağaza kareleri (tr)', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = _frameSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Directory(outDir!).createSync(recursive: true);

    final prefs = await _prefs();

    await _pump(tester, prefs, 'Süreni ölç, panonu kendin kur', const HomeScreen());
    await _shoot(tester, '$outDir/01-ana-ekran.png');

    await _pump(tester, prefs, 'İlerlemeni gör', const StatsScreen());
    await _shoot(tester, '$outDir/02-istatistik.png');

    await _pump(tester, prefs, 'Kendine göre ayarla', const AppearanceScreen());
    await _shoot(tester, '$outDir/03-tema.png');
  }, skip: skip);
}
