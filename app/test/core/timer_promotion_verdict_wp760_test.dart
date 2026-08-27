import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/notifications/timer_panel_preference.dart';
import 'package:online_study_room/core/notifications/timer_promotion_verdict.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/profile/developer_mode.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔴 WP-760 — "dinamik panel neden çıkmıyor?" artık **ekranda** cevaplanır.
///
/// Altı tur boyunca aynı soru tahminle cevaplandı: ölçüm her Başlat'ta
/// yapılıyordu ama sonucunu kimse göremiyordu. Bu dosya iki şeyi ölçer:
///
///  1. Diskteki ham değerin doğru çözüldüğünü (saf, cihazsız).
///  2. **Sahibin gerçekten gördüğü satırın** doğru cümleyi yazdığını.
///
/// İkincisi olmadan birincisi bu depoda hiçbir şey ispat etmez: burada
/// tekrar eden kusur "doğruluk kaynağı doğru ama ekran boş"tur.
void main() {
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

  group('çözümleyici — saf', () {
    test('yalnız damgalı ve tanınan bir verdict okunur', () {
      // Gerçek biçim: "<VERDICT>|<Build.FINGERPRINT>".
      expect(
        parseTimerPromotionVerdict('GRANTED|samsung/dm1q/dm1q:16/UP1A/x:user'),
        TimerPromotionVerdict.granted,
      );
      expect(
        parseTimerPromotionVerdict('DENIED|google/sdk_gphone64/emu:16/x:userdebug'),
        TimerPromotionVerdict.denied,
      );

      // 🔴 Aşağıdakilerin hepsi "henüz ölçülmedi"dir — **RED DEĞİL**. İkisini
      // birleştirmek "cihazın desteklemiyor" diye yanlış teşhis üretir.
      expect(parseTimerPromotionVerdict(null), isNull, reason: 'anahtar yok');
      expect(parseTimerPromotionVerdict(''), isNull, reason: 'boş kayıt');
      expect(
        parseTimerPromotionVerdict('GRANTED'),
        isNull,
        reason:
            'Damgasız kayıt hangi yapıda ölçüldüğünü söylemez. Damgasız bir '
            'DENIED, terfiyi açan bir sistem güncellemesinden sonra bile '
            'sonsuza kadar yapışırdı: tek ölçüm kalıcı bir tavana dönerdi.',
      );
      expect(parseTimerPromotionVerdict('GRANTED|'), isNull, reason: 'boş damga');
      expect(parseTimerPromotionVerdict('HAYIR|x'), isNull, reason: 'tanınmayan');
    });

    test('damgada beklenmedik ayraç olsa da verdict okunur', () {
      // Kotlin tarafı `split(SEPARATOR, limit = 2)` kullanır; Dart tarafı da
      // yalnız İLK ayraçtan böler. İkisi ayrışırsa cihaz sessizce "ölçülmedi"
      // görünürdü.
      expect(
        parseTimerPromotionVerdict('DENIED|a|b|c'),
        TimerPromotionVerdict.denied,
      );
    });

    test('panel seçimi üç durumu ayırır', () {
      // 🔴 WP-760 kök nedeni: `null` "zengin panel" SAYILIYORDU. Anahtarın
      // yokluğu bir tercih değildir.
      expect(timerPanelChoiceFrom(null), TimerPanelChoice.auto);
      expect(timerPanelChoiceFrom(true), TimerPanelChoice.richPanel);
      expect(timerPanelChoiceFrom(false), TimerPanelChoice.liveUpdate);
    });
  });

  group('ekran — sahibin GÖRDÜĞÜ satır', () {
    /// Dar bir telefon genişliği (360 dp) bilerek seçildi: üç segmentli seçim
    /// şeridi burada taşarsa gerçek cihazda da taşar.
    Future<SharedPreferences> pumpAbout(
      WidgetTester tester, {
      Map<String, Object> initialPrefs = const {},
    }) async {
      tester.view.physicalSize = const Size(1080, 7200);
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
      return prefs;
    }

    Future<Widget> revealVerdict(WidgetTester tester) async {
      final tile = find.byKey(const Key('developer-promotion-verdict'));
      await tester.scrollUntilVisible(tile, 240, maxScrolls: 60);
      await tester.pumpAndSettle();
      expect(
        tile,
        findsOneWidget,
        reason:
            'Teşhis satırı ekranda YOK. Sağlayıcı doğru olsa bile sahip '
            'cihazda ne olduğunu göremez; kapatılan döngü tam olarak buydu.',
      );
      return tester.widget(tile);
    }

    testWidgets('ölçüm yokken "henüz ölçülmedi" der, RED demez', (tester) async {
      await pumpAbout(tester);
      await revealVerdict(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.devPromotionVerdictUnknownTitle), findsOneWidget);
      expect(
        find.text(l10n.devPromotionVerdictDeniedTitle),
        findsNothing,
        reason: 'Ölçülmemiş olmak reddedilmiş olmak DEĞİLDİR.',
      );
    });

    testWidgets('sistem verdiyse verdiğini yazar', (tester) async {
      await pumpAbout(
        tester,
        initialPrefs: const {
          kTimerPromotionVerdictKey: 'GRANTED|samsung/dm1q:16/x:user',
        },
      );
      await revealVerdict(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.devPromotionVerdictGrantedTitle), findsOneWidget);
    });

    testWidgets('sistem vermediyse bunun uygulama hatası olmadığını söyler', (
      tester,
    ) async {
      await pumpAbout(
        tester,
        initialPrefs: const {
          kTimerPromotionVerdictKey: 'DENIED|google/emu:16/x:userdebug',
        },
      );
      await revealVerdict(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.devPromotionVerdictDeniedTitle), findsOneWidget);
      expect(find.text(l10n.devPromotionVerdictDeniedSubtitle), findsOneWidget);
    });

    testWidgets('başka bir yapıda ölçülen karar EKRANDA da güvenilmez', (
      tester,
    ) async {
      // Damga bu koşuda `Build.FINGERPRINT` boş olduğu için eşleşmez... ama
      // Dart tarafı damgayı KARŞILAŞTIRMAZ, yalnız varlığını arar: karşılaştırma
      // native tarafın işidir ve orada ölçülür. Burada ölçülen şey, damgasız
      // (yani kaynağı bilinmeyen) bir kaydın ekranda RED gibi görünmemesidir.
      await pumpAbout(
        tester,
        initialPrefs: const {kTimerPromotionVerdictKey: 'DENIED'},
      );
      await revealVerdict(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.devPromotionVerdictUnknownTitle), findsOneWidget);
    });

    testWidgets('üç segmentli seçim şeridi dar telefonda taşmaz', (
      tester,
    ) async {
      await pumpAbout(tester);
      final strip = find.byKey(const Key('developer-panel-choice'));
      await tester.scrollUntilVisible(strip, 240, maxScrolls: 60);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(strip, findsOneWidget);
    });

    testWidgets('"Otomatik"e dönmek anahtarı SİLER, `true` yazmaz', (
      tester,
    ) async {
      // 🔴 KAPATILAN TUZAK. Anahtar iki durumluyken "kapat" diske `true`
      // yazıyordu; `true` native tarafta "zengin paneli zorla" demektir. Yani
      // seçimi bir kez açıp kapatan kullanıcı dinamik paneli KALICI olarak
      // kapatıyor ve geri dönemiyordu — "otomatik"i ifade eden bir değer
      // kalmıyordu.
      final prefs = await pumpAbout(
        tester,
        initialPrefs: const {kTimerPanelExpandedKey: true},
      );
      expect(prefs.getBool(kTimerPanelExpandedKey), isTrue);

      final strip = find.byKey(const Key('developer-panel-choice'));
      await tester.scrollUntilVisible(strip, 240, maxScrolls: 60);
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      await tester.tap(find.text(l10n.devPanelChoiceAuto));
      await tester.pumpAndSettle();

      expect(
        prefs.containsKey(kTimerPanelExpandedKey),
        isFalse,
        reason:
            'Otomatik = anahtar YOK. Herhangi bir değer yazmak üçüncü durumu '
            'yok eder ve tuzağı geri getirir.',
      );
    });
  });
}
