import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/notifications/timer_overlay_preference.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/profile/developer_mode.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔴 WP-764 — yüzen sayaç şeridinin **kullanıcı yüzeyi** nöbetçisi.
///
/// Bu dosya iki kusur ailesine karşı yazıldı; ikisi de bu depoda gerçekten
/// oldu ve ikisi de "yeşil test" varken oldu:
///
///  1. **Deneysel yol varsayılan olur.** WP-753 v71'de, WP-762 v74'te tam
///     olarak bunu yaptı ve çalışan bildirimi bozdu. Sahibin kuralı: *"test
///     ederken sadece biz görelim, diğerlerinde normal olsun"*. En önemli tek
///     iddia bu yüzden "sağlayıcı varsayılanı KAPALI"dır.
///  2. **Doğruluk kaynağı doğru ama ekran boş/yanlış.** Bu yüzden sağlayıcıya
///     bakmak yetmez; üç durum da (kapalı · açık+izin var · açık+izin YOK)
///     ayrı `pumpWidget` ile, sahibin gerçekten gördüğü satır üstünden ölçülür.
///
/// Ayrıca izin durumunun **önbelleklenmediği** ölçülür: kullanıcı Ayarlar'dan
/// dönünce satır kendiliğinden tazelenmezse, izni verdiği hâlde ekran "izin
/// yok" der ve kullanıcı uygulamayı bozuk sanır.
const MethodChannel _timerChannel = MethodChannel(
  'com.manilmax.online_study_room/timer',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 🔴 Fikstür OLDUĞU GİBİ kopyalandı: `channel`/`versionName` uyumsuzsa
  // `AppBuildManifest.resolve` `BuildConfigurationException` atar ve dosya hiç
  // yüklenmez — testin tamamı sessizce kaybolur.
  final manifest = AppBuildManifest.resolve(
    channel: 'beta',
    environment: 'staging',
    supabaseUrl: 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
    supabaseAnonKey: 'sb_publishable_test_key',
    selectedProjectRef: 'aaaaaaaaaaaaaaaaaaaa',
    stagingProjectRef: 'aaaaaaaaaaaaaaaaaaaa',
    productionProjectRef: 'bbbbbbbbbbbbbbbbbbbb',
    gitCommitSha: 'abcdef1234567890',
    migrationHead: '0094',
    versionName: '1.0.44-beta.1',
    buildNumber: 4401,
    allowInMemory: false,
    flutterFlavor: 'beta',
  );

  late List<String> calls;

  /// Sistemin o anki cevabı. Test ortasında değiştirilebilir olması şart:
  /// "Ayarlar'dan izni verip geri döndü" senaryosu başka türlü kurulamaz.
  late bool permitted;

  setUp(() {
    calls = <String>[];
    permitted = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_timerChannel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'canDrawOverlays' => permitted,
            // Dönen değer izin VERİLDİĞİNİ değil, yalnız ekranın açılabildiğini
            // söyler. `permitted` bu yüzden bilerek değişmez.
            'requestOverlayPermission' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_timerChannel, null);
  });

  Future<AppLocalizations> tr() =>
      AppLocalizations.delegate.load(const Locale('tr'));

  group('sağlayıcı', () {
    // 🔴 Riverpod 3: dinleyicisi olmayan bir sağlayıcı her `read`de yeniden
    // build olur ve regresyon testini sessizce etkisiz bırakır. Bu yüzden
    // `ProviderScope` altında gerçek bir dinleyici widget ile ölçülür.
    testWidgets('varsayılan KAPALI ve diske hiçbir şey yazmaz', (tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final seen = <bool>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: Consumer(
            builder: (context, ref, _) {
              seen.add(ref.watch(timerOverlayEnabledProvider));
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        seen.single,
        isFalse,
        reason:
            'Serit KAPALI dogmali. Bu turda UC KEZ deneysel bir yol varsayilan '
            'yapildi ve calisan bildirimi bozdu (v71, v74). Sahip kurali: '
            '"test ederken sadece biz gorelim, digerlerinde normal olsun".',
      );
      expect(
        prefs.getBool(kTimerOverlayEnabledKey),
        isNull,
        reason:
            'Varsayilan diske YAZILMAZ; yazilirsa native taraf onu kullanicinin '
            'acik tercihi sanir.',
      );
    });

    test('Dart anahtarı native anahtarla aynı şeyi adlandırır', () {
      // `shared_preferences` Android'de her anahtarı `flutter.` ile önekler.
      expect(kTimerOverlayEnabledNativeKey, 'flutter.$kTimerOverlayEnabledKey');

      final native = File(
        'android/app/src/main/kotlin/com/manilmax/online_study_room/overlay/'
        'TimerOverlay.kt',
      ).readAsStringSync();

      expect(
        native,
        contains('KEY_ENABLED = "$kTimerOverlayEnabledNativeKey"'),
        reason:
            'Native taraf baska bir anahtar okuyorsa Dart anahtari olur: '
            'kullanici anahtari cevirir, ekranda hicbir sey degismez.',
      );
      expect(
        native,
        contains('getBoolean(KEY_ENABLED, false)'),
        reason:
            'Iki taraftan biri `true` varsayilanina kayarsa, anahtari hic '
            'gormemis kullanicida serit kendiliginden belirir.',
      );
    });
  });

  group('ekran — sahibin GÖRDÜĞÜ satır', () {
    /// Dar bir telefon genişliği (360 dp) bilerek seçildi: satırlar burada
    /// taşarsa gerçek cihazda da taşar.
    Future<SharedPreferences> pumpAbout(
      WidgetTester tester, {
      Map<String, Object> initialPrefs = const {},
      double physicalHeight = 7200,
    }) async {
      tester.view.physicalSize = Size(1080, physicalHeight);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({
        kDeveloperModeKey: true,
        ...initialPrefs,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AboutScreen(
              buildManifest: manifest,
              allowsSideloadUpdates: true,
              releaseNotesChannel: 'stable',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // İzin ölçümü method channel üzerinden gelir; cevabın ekrana işlemesi
      // için bir tur daha gerekir.
      await tester.pumpAndSettle();
      return prefs;
    }

    Future<Finder> reveal(WidgetTester tester, String key) async {
      final finder = find.byKey(Key(key));
      await tester.scrollUntilVisible(finder, 240, maxScrolls: 60);
      await tester.pumpAndSettle();
      expect(
        finder,
        findsOneWidget,
        reason:
            '`$key` EKRANDA YOK. Saglayici dogru olsa bile kullanici anahtari '
            'ne gorebilir ne cevirebilir; bu depoda tekrar eden kusur tam '
            'olarak "dogruluk kaynagi dogru ama ekran bos".',
      );
      return finder;
    }

    testWidgets('KAPALI: anahtar kapalı görünür, izin cümlesi suçlamaz', (
      tester,
    ) async {
      final prefs = await pumpAbout(tester);
      final l10n = await tr();

      final strip = await reveal(tester, 'developer-overlay-enabled');
      expect(
        tester.widget<SwitchListTile>(strip).value,
        isFalse,
        reason: 'Serit KAPALI dogar.',
      );
      expect(prefs.getBool(kTimerOverlayEnabledKey), isNull);

      await reveal(tester, 'developer-overlay-permission');
      expect(find.text(l10n.devOverlayPermissionMissingTitle), findsOneWidget);
      expect(
        find.text(l10n.devOverlayPermissionMissingSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.devOverlayPermissionMissingWhileEnabled),
        findsNothing,
        reason: 'Anahtar kapaliyken "acik ama calismiyor" demek yanlis teshis.',
      );
    });

    testWidgets('AÇIK + izin VAR: izin verildiğini söyler', (tester) async {
      permitted = true;
      await pumpAbout(
        tester,
        initialPrefs: const {kTimerOverlayEnabledKey: true},
      );
      final l10n = await tr();

      final strip = await reveal(tester, 'developer-overlay-enabled');
      expect(tester.widget<SwitchListTile>(strip).value, isTrue);

      await reveal(tester, 'developer-overlay-permission');
      expect(find.text(l10n.devOverlayPermissionGrantedTitle), findsOneWidget);
      expect(
        find.text(l10n.devOverlayPermissionMissingTitle),
        findsNothing,
        reason: 'Izin verilmisken uyari cumlesi durursa satir yalan soyler.',
      );
      expect(
        calls,
        contains('canDrawOverlays'),
        reason: 'Izin durumu tahmin edilmez, sisteme SORULUR.',
      );
    });

    testWidgets('AÇIK + izin YOK: sessiz kalmaz ve izin ekranına götürür', (
      tester,
    ) async {
      permitted = false;
      await pumpAbout(
        tester,
        initialPrefs: const {kTimerOverlayEnabledKey: true},
      );
      final l10n = await tr();

      final permission = await reveal(tester, 'developer-overlay-permission');
      expect(find.text(l10n.devOverlayPermissionMissingTitle), findsOneWidget);
      expect(
        find.text(l10n.devOverlayPermissionMissingWhileEnabled),
        findsOneWidget,
        reason:
            'Anahtar acik, izin yok: sessizce hicbir sey yapmayan anahtar OLU '
            'anahtardir. Kullanici actigini sanir, ekranda hicbir sey cizilmez.',
      );

      expect(calls.contains('requestOverlayPermission'), isFalse);
      await tester.tap(permission);
      await tester.pumpAndSettle();
      expect(
        calls,
        contains('requestOverlayPermission'),
        reason:
            'Uyari cumlesi tek basina yetmez; kullanicinin izni verecegi yere '
            'buradan varabilmesi gerekir.',
      );
    });

    testWidgets('uygulama öne dönünce izin YENİDEN sorulur', (tester) async {
      permitted = false;
      await pumpAbout(
        tester,
        initialPrefs: const {kTimerOverlayEnabledKey: true},
      );
      final l10n = await tr();

      await reveal(tester, 'developer-overlay-permission');
      expect(find.text(l10n.devOverlayPermissionMissingTitle), findsOneWidget);

      // Kullanıcı Ayarlar'a gitti, izni verdi ve geri döndü.
      permitted = true;
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.devOverlayPermissionGrantedTitle),
        findsOneWidget,
        reason:
            'ONBELLEKLENMIS izin. Kullanici "Izin ver"e basip Ayarlar\'a gidiyor, '
            'izni veriyor, donuyor -- o anda tazelenmezse satir hala "izin yok" '
            'der ve kullanici izni verdigi halde uygulamayi bozuk sanir.',
      );
    });

    // 🔴 Bu nöbetçi bir kaza sonucu yazıldı ve kazayı ilk yazımda GERÇEKTEN
    // yakaladı: ilk sürümde iki yeni satır 360 dp genişlikte 584 px yer
    // kaplıyordu (uzun alt başlıklar beş satıra sarıyordu) ve geliştirici
    // kartının SONUNDAKİ "Geliştirici modunu kapat" satırını telefon
    // görüntüsünün dışına itiyordu — dokunulamaz hale getiriyordu. Kod
    // "çalışıyordu", ekran taşıyordu.
    testWidgets('yeni satırlar kartın altını ekran dışına itmez', (
      tester,
    ) async {
      // Sıradan bir telefon yüksekliği (2000 dp mantıksal).
      await pumpAbout(tester, physicalHeight: 6000);

      final disable = find.byKey(const Key('developer-mode-disable'));
      expect(disable, findsOneWidget);
      expect(
        tester.getRect(disable).bottom,
        lessThanOrEqualTo(2000.0),
        reason:
            'Kartin son satiri ekranin disinda kaldi: kaydirmadan dokunulamaz. '
            'Yeni satirlarin yuksekligi bir butcedir, sinirsiz degil.',
      );
    });

    testWidgets('anahtar diske native tarafın okuduğu değeri yazar', (
      tester,
    ) async {
      final prefs = await pumpAbout(tester);
      final strip = await reveal(tester, 'developer-overlay-enabled');

      expect(prefs.getBool(kTimerOverlayEnabledKey), isNull);

      await tester.tap(strip);
      await tester.pumpAndSettle();
      expect(
        prefs.getBool(kTimerOverlayEnabledKey),
        isTrue,
        reason: 'Native taraf yalniz diski okur; ekran state\'i onu gormez.',
      );

      await tester.tap(strip);
      await tester.pumpAndSettle();
      expect(prefs.getBool(kTimerOverlayEnabledKey), isFalse);
    });
  });
}
