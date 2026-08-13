// WP-680 — GIRIS / KAYIT / KURTARMA / TANITIM EKRANLARI: masaustu duzen kapisi.
//
// Sahip v64 Windows surumunu reddetti: *"dikey mobil uygulama icin tasarlanan
// arayuzler yatay pc ekraninda cok kotu duruyor."* Bu dosya kullanicinin ILK
// gordugu ekranlari olcer — kimlik akisi ve tanitim turu. Bu dort ekranin
// masaustu genisligi bugune kadar HIC olculmemisti.
//
// ============================== DISIPLIN =====================================
//
// 1. Her iddia CIZILEN kutudan okunur (`tester.getRect` / `getSize`).
//    Kaynakta `maxWidth: 760` yazmasi kanit degildir (depo dersi:
//    "kullanicinin GORDUGU satiri test et").
// 2. Masaustu dali `debugDefaultTargetPlatformOverride` ile acilir; bayrak
//    govde BITMEDEN geri alinir (`tearDown` gec kalir ve
//    "foundation debug variable was changed by the test" atar).
// 3. Mobil dal AYNI dosyada olculur. "Masaustunu duzelttim" iddiasinin bedeli
//    mobilin bozulmamasidir (SPEC §7).
// 4. ISLEV KAYBI YOK: giris, kayit, sifre sifirlama, kod ile sifirlama ve
//    tanitim turunun dort adimi ayri ayri sinanir.
//
// ==================== WP-680 ONCESI OLCULEN SAYILAR ==========================
//
// Ayni harness, `devicePixelRatio = 1`, en genis cizilen kutu:
//
// | ekran | 1920 px | 2560 px | 390 px (mobil) |
// |---|---:|---:|---:|
// | `AuthScreen` form sutunu | **380** | **380** | 342 |
// | `RecoveryScreen` | **1872** | **2512** | 342 |
// | `ResetWithCodeScreen` form | **380** | **380** | — |
// | `OnboardingScreen` birincil dugme | **1872** | **2512** | 342 |
//
// 1872 / 7.5 = **250 karakter** (SPEC §2.1); WCAG 2.1 SC 1.4.8 tavani 80
// karakter = 600 px. `AuthScreen` ise ters ucta: 1920 px pencerede icerigin
// tamami 380 px, yani pencerenin **%20**'si.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/auth/entry_desktop_layout.dart';
import 'package:online_study_room/features/auth/recovery_screen.dart';
import 'package:online_study_room/features/auth/reset_with_code_screen.dart';
import 'package:online_study_room/features/onboarding/onboarding_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SPEC §2.3 "Form / ayar satiri" — 600 (etiket olcu tavani) + 160 (kontrol).
const double kFormCapPx = DesktopBreakpoints.maxFormWidth; // 760

/// SPEC §2.3 "Duz metin / prose" — 80 karakter × 7.5 px (WCAG 1.4.8).
const double kProseCapPx = DesktopBreakpoints.maxProseWidth; // 600

/// SPEC §2.3 "Izgara / pano toplami".
const double kBandCapPx = DesktopBreakpoints.maxContentWidth; // 1440

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tr = AppLocalizationsTr();

  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> pump(WidgetTester tester, Widget home, Size window) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    // WP-734: `OnboardingScreen` ilk sayfada dil tercihini okur, yani artik
    // `sharedPreferencesProvider`a bagimlidir. Override edilmezse provider
    // hata durumuna duser ve ekran HIC cizilmez -- olculecek kutu da kalmaz.
    SharedPreferences.setMockInitialValues({
      'app_language_preference': AppLanguage.turkish.name,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Bir sonlandiricinin CIZILEN kutulari (global koordinat).
  List<Rect> rects(WidgetTester tester, Finder finder) => [
    for (final element in finder.evaluate())
      tester.getRect(find.byWidget(element.widget)),
  ];

  /// Formun ICINDEKI en genis cizilen kutu.
  ///
  /// `AppBar` bilerek disarida: baslik seridi pencere kromudur, pencereyi
  /// doldurmasi dogrudur (SPEC §6). Olculen sey kullanicinin OKUDUGU/DOLDURDUGU
  /// alandir.
  ({double width, String what}) widestInForm(WidgetTester tester) {
    var widest = 0.0;
    var what = '<yok>';
    for (final type in <Type>[Text, TextField, FilledButton, TextButton]) {
      final finder = find.descendant(
        of: find.byType(Form),
        matching: find.byType(type),
      );
      for (final box in rects(tester, finder)) {
        if (box.width.isFinite && box.width > widest) {
          widest = box.width;
          what = '$type';
        }
      }
    }
    return (width: widest, what: what);
  }

  // ===========================================================================
  // 1) GIRIS / KAYIT — 380 px'lik yuzen sutun yerine marka + form panosu
  // ===========================================================================

  testWidgets(
    'WP-680 (1) AuthScreen 1920: marka ve form panolari YAN YANA, form 760 px',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(tester, const AuthScreen(), const Size(1920, 1080));

      final hero = find.byKey(const ValueKey(kEntryHeroPaneKey));
      final form = find.byKey(const ValueKey(kEntryFormPaneKey));
      expect(
        hero,
        findsOneWidget,
        reason:
            'Masaustu bolmesi acilmadi: ekran hala tek sutun. Duzeltme oncesi '
            'butun icerik 1920 px pencerede 380 px genisligindeydi.',
      );
      expect(form, findsOneWidget, reason: 'Form panosu cizilmedi.');

      final h = tester.getRect(hero);
      final f = tester.getRect(form);

      expect(
        f.left,
        greaterThanOrEqualTo(h.right),
        reason:
            'Panolar yan yana degil: marka ${h.left.toStringAsFixed(0)}..'
            '${h.right.toStringAsFixed(0)}, form ${f.left.toStringAsFixed(0)}..'
            '${f.right.toStringAsFixed(0)}.',
      );
      expect(
        h.width,
        lessThanOrEqualTo(kProseCapPx),
        reason:
            'Marka panosu ${h.width.toStringAsFixed(0)} px; SPEC §2.3 prose '
            'tavani ${kProseCapPx.toStringAsFixed(0)} px.',
      );
      expect(
        f.width,
        lessThanOrEqualTo(kFormCapPx),
        reason:
            'Form panosu ${f.width.toStringAsFixed(0)} px; SPEC §2.3 form '
            'tavani ${kFormCapPx.toStringAsFixed(0)} px.',
      );
      expect(
        f.right - h.left,
        lessThanOrEqualTo(kBandCapPx),
        reason:
            'Toplam icerik ${(f.right - h.left).toStringAsFixed(0)} px; SPEC '
            '§2.3 pano toplami ${kBandCapPx.toStringAsFixed(0)} px.',
      );
      // Pencerenin %20'sinde durmuyor: 1384 / 1920 = %72.
      expect(
        f.right - h.left,
        greaterThan(1000),
        reason:
            'Icerik ${(f.right - h.left).toStringAsFixed(0)} px — hala mobil '
            'penceresi genisliginde. Duzeltme oncesi bu sayi 380 px idi.',
      );
    }),
  );

  testWidgets(
    'WP-680 (2) AuthScreen 2560: bant 1440 tavaninda durur, buyumez',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(tester, const AuthScreen(), const Size(2560, 1440));
      final h = tester.getRect(find.byKey(const ValueKey(kEntryHeroPaneKey)));
      final f = tester.getRect(find.byKey(const ValueKey(kEntryFormPaneKey)));
      expect(f.right - h.left, lessThanOrEqualTo(kBandCapPx));
      expect(f.width, lessThanOrEqualTo(kFormCapPx));
      // Yatayda ortali: iki yanda esit bosluk. Tolerans = oluk (24 px):
      // 1440'lik bant ortalanir, marka panosu kalan 608 px'in ICINDE ortalanir
      // (600 tavani), bu da 4 px'lik bir kayma birakir.
      expect((h.left - (2560 - f.right)).abs(), lessThanOrEqualTo(8));
    }),
  );

  testWidgets(
    'WP-680 (3) AuthScreen 1199 (large ALTI): bolme ACILMAZ, tek sutun kalir',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      // 1200 = DesktopBreakpoints.large. Altinda 760 + 24 + marka sigmaz.
      await pump(tester, const AuthScreen(), const Size(1199, 900));
      expect(
        find.byKey(const ValueKey(kEntryHeroPaneKey)),
        findsNothing,
        reason:
            'Bolme esigi kaymis: 1199 px `large` (1200) ALTINDA, iki pano '
            'sigmaz (1199 - 760 - 24 - 48 = 367 px marka panosu).',
      );
      await pump(tester, const AuthScreen(), const Size(1200, 900));
      expect(
        find.byKey(const ValueKey(kEntryHeroPaneKey)),
        findsOneWidget,
        reason: 'Tam 1200 px `large` esigidir, bolme burada acilmali.',
      );
    }),
  );

  testWidgets('WP-680 (4) AuthScreen: hicbir islev kaybolmadi (masaustu)', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      await pump(tester, const AuthScreen(), const Size(1920, 1080));

      // Giris modu: marka + e-posta + sifre + giris + sifremi unuttum +
      // kayit gecisi + SSS (WP-422, oturumsuz SSS erisimi v55 kazanimi).
      expect(find.text(tr.commonOdakKampi), findsOneWidget);
      expect(find.text(tr.authHesabnaGirisYap), findsOneWidget);
      expect(find.widgetWithText(TextFormField, tr.authEposta), findsOneWidget);
      expect(find.widgetWithText(TextFormField, tr.authSifre), findsOneWidget);
      expect(find.text(tr.authGirisYap), findsOneWidget);
      expect(find.text(tr.authSifremiUnuttum), findsOneWidget);
      expect(find.byKey(const Key('auth-faq-link')), findsOneWidget);
      expect(find.text(tr.authHesabinYokMuKayit), findsOneWidget);

      // Kayit moduna gecis calisiyor ve "Gorunen ad" alani geliyor.
      await tester.tap(find.text(tr.authHesabinYokMuKayit));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, tr.authGorunenAd),
        findsOneWidget,
        reason: 'Kayit modunda gorunen ad alani kayboldu.',
      );
      expect(find.text(tr.authYeniHesapOlustur), findsOneWidget);
      expect(find.text(tr.authKaytOl), findsOneWidget);

      // Bos formda dogrulama hala calisiyor (Form anahtari yalniz ALANLARI
      // sariyor; kimlik blogu disarida kaldi).
      await tester.tap(find.text(tr.authKaytOl));
      await tester.pumpAndSettle();
      expect(
        find.text(tr.authGorunenAdGirin),
        findsOneWidget,
        reason:
            'Form dogrulamasi calismadi — `_formKey` alanlari artik '
            'kapsamiyor olabilir.',
      );
      expect(find.text(tr.authGecerliBirEpostaGirin), findsOneWidget);
      expect(find.text(tr.authSifreEnAz6), findsOneWidget);
    });
  });

  // ===========================================================================
  // 2) KURTARMA + KOD ILE SIFIRLAMA — 1872/2512 px'lik satirlarin sonu
  // ===========================================================================

  for (final w in const [1920.0, 2560.0]) {
    testWidgets(
      'WP-680 (5) RecoveryScreen $w: hicbir kutu ${kFormCapPx.toInt()} px '
      'asmaz',
      (tester) async => onPlatform(TargetPlatform.windows, () async {
        await pump(tester, const RecoveryScreen(), Size(w, 1080));
        final column = find.byKey(const ValueKey(kEntryFormColumnKey));
        expect(
          column,
          findsOneWidget,
          reason: 'Kurtarma ekraninda genislik tavani yok.',
        );
        expect(
          tester.getSize(column).width,
          lessThanOrEqualTo(kFormCapPx),
          reason:
              'Form sutunu ${tester.getSize(column).width.toStringAsFixed(0)} '
              'px. Duzeltme oncesi 1920 px pencerede 1872, 2560 px pencerede '
              '2512 px idi (250 / 335 karakter).',
        );
        final widest = widestInForm(tester);
        expect(
          widest.width,
          lessThanOrEqualTo(kFormCapPx),
          reason:
              'En genis ${widest.what} ${widest.width.toStringAsFixed(0)} px; '
              'SPEC §2.3 form tavani ${kFormCapPx.toStringAsFixed(0)} px.',
        );
        // Islev: aciklama + yeni sifre alani + kaydet dugmesi duruyor.
        expect(find.text(tr.authGuvenliginizIcinYeniBir), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, tr.authYeniSifre),
          findsOneWidget,
        );
        expect(find.text(tr.authSifreyiKaydetVeGiris), findsOneWidget);
      }),
    );
  }

  testWidgets(
    'WP-680 (6) ResetWithCodeScreen 1920: form sutunu 760, uc alan da yerinde',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(tester, const ResetWithCodeScreen(), const Size(1920, 1080));
      final column = find.byKey(const ValueKey(kEntryFormColumnKey));
      expect(column, findsOneWidget);
      final width = tester.getSize(column).width;
      expect(width, lessThanOrEqualTo(kFormCapPx));
      expect(
        width,
        greaterThan(kProseCapPx),
        reason:
            'Sutun ${width.toStringAsFixed(0)} px — hala 380 px\'lik mobil '
            'tavaninda.',
      );
      // WP-287 islevi: e-posta + kod + yeni sifre + dogrula dugmesi.
      expect(find.widgetWithText(TextFormField, tr.authEposta), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, tr.authSifreSifirlamaKodu),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, tr.authYeniSifre),
        findsOneWidget,
      );
      expect(find.text(tr.authKoduDogrulaVeSifirla), findsOneWidget);
    }),
  );

  // ===========================================================================
  // 3) TANITIM TURU — 1872 px'lik dugme ve 250 karakterlik govde
  // ===========================================================================

  testWidgets(
    'WP-680 (7) Onboarding 1920/2560: govde <= 600, eylemler <= 760',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      for (final w in const [1920.0, 2560.0]) {
        await pump(tester, const OnboardingScreen(), Size(w, 1080));

        // 🔴 Olcum TUTAMAKTAN degil, kullanicinin OKUDUGU metinden yapilir.
        // Anahtara bagli bir iddia, duzeltme tumden silindiginde "widget yok"
        // diye kirmizi duser — ama SAYIYI hic gormez. Adim metinlerinin
        // cizilen kutusu, tavan olsa da olmasa da olculebilir.
        final stepTexts = rects(
          tester,
          find.descendant(
            of: find.byType(PageView),
            matching: find.byType(Text),
          ),
        );
        expect(stepTexts, isNotEmpty, reason: '$w px: adim metni cizilmedi.');
        final widestText = stepTexts
            .map((b) => b.width)
            .reduce((a, b) => a > b ? a : b);
        expect(
          widestText,
          lessThanOrEqualTo(kProseCapPx),
          reason:
              '$w px: en genis adim metni ${widestText.toStringAsFixed(0)} px; '
              'SPEC §2.3 prose tavani ${kProseCapPx.toStringAsFixed(0)} px '
              '(WCAG 1.4.8, 80 karakter). Duzeltme oncesi 1864 / 2504 px, '
              'yani ~250 / ~334 karakter.',
        );
        expect(
          find.byKey(const ValueKey(kOnboardingProseKey)),
          findsWidgets,
          reason: '$w px: tanitim govdesinin genislik tavani yok.',
        );

        final actions = find.byKey(const ValueKey(kEntryFormColumnKey));
        expect(
          actions,
          findsOneWidget,
          reason: '$w px: eylem sutununun genislik tavani yok.',
        );
        final button = tester.getRect(find.byType(FilledButton).first);
        expect(
          button.width,
          lessThanOrEqualTo(kFormCapPx),
          reason:
              '$w px: birincil dugme ${button.width.toStringAsFixed(0)} px. '
              'Sebep `FilledButton.styleFrom(minimumSize: Size.fromHeight(48))'
              '` — `Size.fromHeight` genisligi `double.infinity` yapar. '
              'Duzeltme oncesi 1872 / 2512 px.',
        );
      }
    }),
  );

  testWidgets(
    'WP-680 (8) Onboarding masaustu: DORT adimin hepsi hala gezilebiliyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(tester, const OnboardingScreen(), const Size(1920, 1080));

      // Adim 1 — hos geldin
      expect(find.text(tr.onboardingWelcomeTitle), findsOneWidget);
      expect(find.text(tr.onboardingWelcomeBody), findsOneWidget);
      expect(find.text(tr.onboardingSkip), findsOneWidget);
      await tester.tap(find.text(tr.onboardingContinue));
      await tester.pumpAndSettle();

      // Adim 2 — bildirim (izin dugmesine DOKUNULMAZ: gercek servis cagirir)
      expect(find.text(tr.onboardingNotifyTitle), findsOneWidget);
      expect(find.text(tr.onboardingAllowNotifications), findsOneWidget);
      await tester.tap(find.text(tr.onboardingNotNow));
      await tester.pumpAndSettle();

      // Adim 3 — grup
      expect(find.text(tr.onboardingGroupTitle), findsOneWidget);
      expect(find.text(tr.classroomGrupOlustur), findsOneWidget);
      expect(find.text(tr.classroomGrubaKatil), findsOneWidget);
      await tester.tap(find.text(tr.onboardingSkipGroup));
      await tester.pumpAndSettle();

      // Adim 4 — hazir
      expect(find.text(tr.onboardingReadyTitle), findsOneWidget);
      expect(find.text(tr.onboardingStart), findsOneWidget);
    }),
  );

  // ===========================================================================
  // 4) MOBIL REGRESYON — SPEC §7: mobil dal bugunku ciktisini BIREBIR korur
  // ===========================================================================

  testWidgets('WP-680 (9) 390x844 mobil: hicbir sey degismedi', (tester) async {
    await onPlatform(TargetPlatform.android, () async {
      // -- AuthScreen: masaustu bolmesi ACILMAZ, sutun 342 px (olculdu) -------
      await pump(tester, const AuthScreen(), const Size(390, 844));
      expect(
        find.byKey(const ValueKey(kEntryHeroPaneKey)),
        findsNothing,
        reason: 'Masaustu bolmesi mobilde acildi — SPEC §7.',
      );
      final authWidest = widestInForm(tester);
      expect(
        authWidest.width,
        closeTo(342, 1),
        reason:
            'Mobil giris sutunu ${authWidest.width.toStringAsFixed(0)} px; '
            'WP-680 oncesi olculen deger 342 px (390 - 2×24 kenar).',
      );
      expect(find.text(tr.commonOdakKampi), findsOneWidget);
      expect(find.text(tr.authGirisYap), findsOneWidget);

      // -- RecoveryScreen: 358 px (olculdu), 760 tavani devreye girmez -------
      await pump(tester, const RecoveryScreen(), const Size(390, 844));
      final recoveryWidest = widestInForm(tester);
      expect(
        recoveryWidest.width,
        closeTo(342, 1),
        reason:
            'Mobil kurtarma sutunu ${recoveryWidest.width.toStringAsFixed(0)} '
            'px; WP-680 oncesi olculen deger 342 px (390 - 2x24 kenar). 760\'lik tavan mobilde '
            'hicbir kutuyu kucultmemeli.',
      );

      // -- Onboarding: prose tavani ACILMAZ, dugme 342 px (olculdu) ----------
      await pump(tester, const OnboardingScreen(), const Size(390, 844));
      expect(
        find.byKey(const ValueKey(kOnboardingProseKey)),
        findsNothing,
        reason: 'Masaustu prose tavani mobilde acildi — SPEC §7.',
      );
      expect(find.byKey(const ValueKey(kEntryFormColumnKey)), findsNothing);
      expect(
        tester.getSize(find.byType(FilledButton).first).width,
        closeTo(342, 1),
        reason:
            'Mobilde birincil dugme tam genislikte kalmali (390 - 2×24 = 342).',
      );
      expect(find.text(tr.onboardingWelcomeTitle), findsOneWidget);
      expect(find.text(tr.onboardingWelcomeBody), findsOneWidget);
    });
  });
}
