// WP-671 — MASAUSTUNDE "MOBIL GERILMESI" KAPISI.
//
// Sahip v64 Windows surumunu reddetti:
//   "dikey mobil uygulama icin tasarlanan arayuzler yatay pc ekraninda cok kotu
//    duruyor, tamamen mobilin penceresi gibi olmus, hic begenmedim."
//
// Somut sikayetler (sahibin ~2000 px pencerede gordugu):
//   - bir kartta etiket solda, degeri ~1900 px otede sagda; goz satiri kaybediyor
//   - ozet kartlari ~800 px genisliginde ve icinde tek bir "2s" yaziyor
//   - icerik tek sutun; sag ve sol yarilar bos
//
// Bu dosya kusuru DUZELTMEZ. Duzeldiginin nasil anlasilacagini tanimlar.
// **YAZILDIGI GUN KIRMIZI.** Kirmizi olmasi hata degil, isin ta kendisi:
// duzeltme WP'leri bu kapiyi yesile cevirerek ilerler.
//
// ============================ NEYI KORUR =====================================
//
// 1. Gercek uygulamayi (`OnlineStudyRoomApp`, in-memory depolarla) 1920x1080 ve
//    2560x1440 pencerede, `TargetPlatform.windows` ile CIZER ve bes gercek
//    yuzeyi gezer: ana pano, gruplar/kamp atesi, istatistik, profil, basarimlar.
// 2. Iddialarin hepsi CIZILEN KAREDEN okunur; hicbiri kaynak dosyada bir sabit
//    aramaz. Olculen sey boyanan glif kutulari ve boyanan kart kutularidir
//    (bkz. `desktop_stretch_probe.dart` bas yorumu).
// 3. Esikler `docs/design/DESKTOP-UI-SPEC.md` (WP-670) icinden gelir; her biri
//    asagida SPEC bolumuyle birlikte gerekcelendirilir. Uydurma sayi yok.
//
// =========================== NEYI KORUMAZ ====================================
//
// - **Guzellik.** "Iyi duruyor" olculmez. Olculen sey mesafe ve tavan.
// - **Katlanin altini.** Yalnizca ILK karede boyanan icerik olculur; kaydirinca
//   gelen bloklar bu kapinin disindadir.
// - **Mobil dal.** 390x844 mobil agac burada hic cizilmez; SPEC §7'nin "mobil
//   degismez" kurali ayri bir kapinin isidir (SPEC §8/9).
// - **Renk, kontrast, tema.** Uyari rozeti / WP-627 dersleri ayri kapilarda.
// - **Golden.** Bilerek golden YOK: yavas, kirilgan ve piksel farkini SEBEBE
//   baglamaz. Burada her kirmizi bir SAYI ve bir metin verir.
// - **Veri dolu ekranlar.** Bu kosum taze bir hesabin bos durumunu cizer
//   (tek grup tohumlanir). Grafik dolu ekranlarin olcumu ayri bir WP'dir.
// - **Yatay tasma / overflow.** `RenderFlex overflow` ayri bir kapidir.
//
// ============================== ESIKLER ======================================
//
// Hepsi EKRAN pikselidir (kullanicinin gordugu), mantiksal piksel degil. Fark
// onemli: `DesktopProportionalScale` tum agaci `FittedBox` ile buyuttugu surece
// kaynakta 1440 yazan bir kisit ekranda 2160 px olarak boyanir. SPEC §0 o
// olcegi kaldirinca ikisi esitlenir; kapi iki durumda da ayni seyi olcer, yani
// olcek kaldirilmasi tek basina bu kapiyi yesile cevirmez.
//
// ========================= YAZILDIGI GUNKU SAYILAR ===========================
//
// 2026-08-10, WP-672'nin olcek kaldirma calismasi calisma agacindayken olculdu
// (10/10 test kirmizi). Ekran / pencere -> ihlal sayisi, icerik araligi,
// en genis etiket-deger satiri:
//
//   ana pano       1920 -> 9 ihlal, icerik 1564 px, satir 1408 px ("Bugun ozeti" -> "0sn")
//   ana pano       2560 -> 9 ihlal, icerik 1884 px, satir 1408 px
//   gruplar        1920 -> 12 ihlal, icerik 1706 px, satir 1688 px ("Grup gunluk trendi" -> "0sn")
//   gruplar        2560 -> 12 ihlal, icerik 2346 px, satir 2328 px
//   istatistik     1920 -> 2 ihlal, icerik 1264 px, satir 950 px ("Kisisel" -> "Grup")
//   istatistik     2560 -> 3 ihlal, icerik 1744 px, satir 1270 px
//   profil         1920 -> 1 ihlal (yalniz OLCUM 4), icerik 646 px
//   profil         2560 -> 1 ihlal (yalniz OLCUM 4), icerik 646 px
//   basarimlar     1920 -> 6 ihlal, icerik 1872 px, satir 1848 px ("En verimli gun" -> "—")
//   basarimlar     2560 -> 14 ihlal, icerik 2540 px, satir 2488 px
//
// Profil'in yalniz OLCUM 4'ten dusmesi kapinin AYIRT ETTIGININ kanitidir: o
// ekran zaten 760 px'lik bir okuma sutununa bagli, digerleri degil.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../../support/v8_test_setup.dart';
import 'desktop_stretch_probe.dart';

/// SPEC §2.3, "Izgara / pano toplami" satiri: **1440 px**.
/// (`DesktopBreakpoints.maxContentWidth` — 1440 = 3 x 480 sutun.)
///
/// Bir masaustu ekraninin icerigi pencere genisledikce sonsuza kadar
/// yayilamaz; artan yer sola/saga esit bosluk olur.
const double kMaxContentSpanPx = 1440;

/// SPEC KURAL 2.2 sert tavani: **600 px** = 80 karakter x 7.5 px.
/// Kaynak: WCAG 2.1 SC 1.4.8 ("Width is no more than 80 characters or glyphs").
/// SPEC'in hedef degeri 496 px'tir (Bringhurst 66ch); bu kapi **sert tavani**
/// olcer, yani en musamahakar sinirI. 496'yi ayrica raporlar ama kirmizi
/// dusurmez — hedefi kapiya cevirmek duzeltme WP'sinin isi.
const double kMaxLabelValueSpanPx = 600;

/// SPEC §2.3, "Form / ayar satiri": **760 px**
/// (= `DesktopSurface.readingWidth`, zaten kodda ve testli).
///
/// Tek bir kart yuzeyi icin depodaki EN MUSAMAHAKAR tavan budur; SPEC ayrica
/// istatistik dosemesi icin 320, grafik karti icin 720 diyor. Kapi 760 kullanir
/// ki daha sikI tavanlar duzeltme sirasinda ayri ayri baglanabilsin.
const double kMaxCardWidthPx = 760;

/// Bir kartin "dev kutu, tek satir" olcusu: kart genisligi eksi icindeki en
/// genis metnin genisligi.
///
/// **Bu esik SPEC'te YOK; onu ben sectim.** 480 px = 2 x 240 px kenar. SPEC §4
/// masaustu sayfa kenar boslugunu en genis bantta **24 px** diyor; 240 px onun
/// on kati. Bir kartin her iki yaninda 240 px'ten fazla olu alan varsa o kart
/// icerigine gore degil, PENCEREYE gore boyutlanmistir — sahibin "800 px kart,
/// icinde tek bir 2s" sikayetinin olculebilir hali. SPEC bu olcuyu bir gun
/// tanimlarsa bu sabit ona uyumlanacak.
const double kMaxCardDeadWidthPx = 480;

/// SPEC §6 "BAGLA, ATMA" karar tablosundaki, ekranlara baglanmasi gereken
/// masaustu yuzey widget'lari.
///
/// SPEC olcumu: bu 8 API'nin `lib/` icinde **tek bir cagri yeri yok**; dosyayi
/// hayatta tutan tek sey kendi izole testi. Kapi bunu CIZILEN agacta arar —
/// `import` eklemek ya da izole bir testte monte etmek gecirmez.
const List<Type> kDesktopSurfaceTypes = <Type>[
  DesktopPageScaffold,
  DesktopContent,
  DesktopMasterDetail,
  DesktopPanel,
  DesktopResponsiveColumns,
  DesktopSectionList,
  DesktopContextPanel,
];

/// Kapinin cizdigi pencere boyutlari. Sahip ~2000 px'te sikayet etti; 1920 en
/// yaygin masaustu, 2560 SPEC'in `xlarge` (>=1600) bandinin ortasi.
const List<Size> kWindowSizes = <Size>[Size(1920, 1080), Size(2560, 1440)];

enum Surface { home, groups, stats, profile, achievements }

void main() {
  final tr = AppLocalizationsTr();

  // 🔴 `debugDefaultTargetPlatformOverride` test GOVDESI BITMEDEN geri
  // alinmali. `_verifyInvariants` tearDown'dan ONCE kosar ve bayrak hala
  // dururken "The value of a foundation debug variable was changed by the
  // test" diye patlar.
  //
  // Bu tuzak bu dosyayi bir kez YALANCI KIRMIZIYA dusurdu: iddialar kirmizi
  // dustugu surece `TestFailure` once firlar ve invariant kontrolu hic
  // gorunmez. Sabotaj turunda iddialar yesile donunce asil hata ortaya cikti —
  // yani duzeltme ajanlari kapiyi gecirdiginde test YINE kirmizi kalacakti ve
  // sebep kod degil bu bayrak olacakti. `setUp`/`tearDown` cifti bu isi
  // GORMEZ; govdenin ICINDE sarmalayici sart.
  Future<void> onWindows(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Kamp atesi sahnesi surekli animasyonludur; `pumpAndSettle` orada asla
  /// oturmaz. Once oturmayi dener, olmazsa sabit sayida kare cizer.
  Future<void> settle(WidgetTester tester) async {
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

  /// Gercek uygulamayi Windows platformunda, verilen pencere boyutunda cizer ve
  /// istenen yuzeye gider.
  Future<DesktopStretchProbe> openSurface(
    WidgetTester tester, {
    required Size window,
    required Surface surface,
  }) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);

    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);
    final groupRepository = InMemoryGroupRepository();
    final profile = (await auth.authStateChanges().first)!;
    // Gruplar sekmesi bos durumda tek satirlik bir bos-durum metni cizer ve
    // hicbir sey olcemez. Kamp atesi + grup kartlari icin bir grup sart.
    await groupRepository.createGroup(name: 'Odak Kampi', creator: profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(groupRepository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          deviceIntegrationServiceProvider.overrideWithValue(
            V8TestDeviceIntegrationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await settle(tester);

    final tab = switch (surface) {
      Surface.home => tr.homeAnaSayfa,
      Surface.groups => tr.desktopGruplar,
      Surface.stats => tr.statsIstatistik,
      Surface.profile || Surface.achievements => tr.profileProfil,
    };
    expect(
      find.text(tab),
      findsWidgets,
      reason:
          'Masaustu kabugu cizilmedi: "$tab" sekmesi yok. Kapi bir sey '
          'olcemez; once kabugun ayakta oldugundan emin ol.',
    );
    await tester.tap(find.text(tab).first);
    await settle(tester);

    if (surface == Surface.achievements) {
      final entry = find.text(tr.profileRozetlerinSerilerinVeIlerlemen);
      expect(
        entry,
        findsWidgets,
        reason:
            'Profilden basarimlara giris satiri bulunamadi; basarimlar ekrani '
            'olculemedi.',
      );
      await tester.tap(entry.first);
      await settle(tester);
    }

    return DesktopStretchProbe(tester);
  }

  String label(Surface surface) => switch (surface) {
    Surface.home => 'ana pano',
    Surface.groups => 'gruplar / kamp atesi',
    Surface.stats => 'istatistik',
    Surface.profile => 'profil',
    Surface.achievements => 'basarimlar',
  };

  for (final window in kWindowSizes) {
    final w = window.width.toInt();
    final h = window.height.toInt();

    for (final surface in Surface.values) {
      testWidgets(
        '${label(surface)} @ ${w}x$h — masaustunde mobil gerilmesi yok',
        (tester) async => onWindows(() async {
          final probe = await openSurface(
            tester,
            window: window,
            surface: surface,
          );

          final failures = <String>[];
          final notes = <String>[];

          // ---- OLCUM 1: icerik yatay olarak sinirli mi (SPEC §2.3 = 1440) ----
          final bounds = probe.contentInkBounds();
          if (bounds == null) {
            failures.add(
              'OLCUM 1: ekranda hic boyanmis metin yok — yuzey cizilmemis.',
            );
          } else {
            notes.add(
              'icerik araligi: ${bounds.width.toStringAsFixed(0)} px '
              '(${bounds.left.toStringAsFixed(0)}..'
              '${bounds.right.toStringAsFixed(0)}), pencere $w px',
            );
            if (bounds.width > kMaxContentSpanPx) {
              failures.add(
                'OLCUM 1 (SPEC §2.3 izgara tavani ${kMaxContentSpanPx.toInt()} px): '
                'icerik ekranda ${bounds.width.toStringAsFixed(0)} px yayiliyor '
                '(${(bounds.width - kMaxContentSpanPx).toStringAsFixed(0)} px asim). '
                'Icerik sutunu pencereyle birlikte buyuyor.',
              );
            }
          }

          // ---- OLCUM 2: etiket-deger mesafesi (SPEC KURAL 2.2 = 600) --------
          final rows = probe.labelValueRows();
          final wideRows = rows
              .where((r) => r.span > kMaxLabelValueSpanPx)
              .toList();
          if (rows.isNotEmpty) {
            final worst = rows.first;
            notes.add(
              'en genis etiket-deger satiri: ${worst.span.toStringAsFixed(0)} px '
              '(bos aralik ${worst.gap.toStringAsFixed(0)} px) '
              '${worst.label.text} -> ${worst.value.text}',
            );
            if (worst.span > 496 && worst.span <= kMaxLabelValueSpanPx) {
              notes.add(
                'not: SPEC hedefi 496 px (Bringhurst 66ch) asildi ama sert '
                'tavan 600 px asilmadi — kapi kirmizi DUSURMEZ.',
              );
            }
          }
          for (final row in wideRows.take(5)) {
            failures.add(
              'OLCUM 2 (SPEC KURAL 2.2 sert tavan ${kMaxLabelValueSpanPx.toInt()} px '
              '= 80 karakter, WCAG 1.4.8): '
              '"${row.label.text}" -> "${row.value.text}" satiri '
              '${row.span.toStringAsFixed(0)} px; aradaki bos aralik '
              '${row.gap.toStringAsFixed(0)} px. Etiket ile degeri arasindaki '
              'goz sicramasi satiri kaybettiriyor.',
            );
          }
          if (wideRows.length > 5) {
            failures.add(
              'OLCUM 2: ayni yuzeyde ${wideRows.length} satirin hepsi tavani '
              'asiyor (ilk 5 tanesi yukarida).',
            );
          }

          // ---- OLCUM 3: dev kart / tek satirlik icerik ----------------------
          final cards = probe.paintedCards();
          if (cards.isNotEmpty) {
            final widest = cards.first;
            notes.add(
              'en genis kart: ${widest.rect.width.toStringAsFixed(0)} px, '
              'icindeki en genis metin ${widest.widestText.toStringAsFixed(0)} px '
              '("${widest.label}")',
            );
          }
          final fatCards = cards
              .where((c) => c.rect.width > kMaxCardWidthPx)
              .toList();
          for (final card in fatCards.take(4)) {
            failures.add(
              'OLCUM 3 (SPEC §2.3 form/ayar sutunu ${kMaxCardWidthPx.toInt()} px): '
              'kart ${card.rect.width.toStringAsFixed(0)} px genisliginde, '
              'icindeki en genis metin sadece '
              '${card.widestText.toStringAsFixed(0)} px ("${card.label}").',
            );
          }
          if (fatCards.length > 4) {
            failures.add(
              'OLCUM 3: ${fatCards.length} kart tavani asiyor '
              '(ilk 4 tanesi yukarida).',
            );
          }
          final hollow = cards
              .where((c) => c.deadWidth > kMaxCardDeadWidthPx)
              .toList();
          for (final card in hollow.take(3)) {
            failures.add(
              'OLCUM 3b (olu alan tavani ${kMaxCardDeadWidthPx.toInt()} px — '
              'esigi WP-671 sectI, SPEC'
              "'te yok): kart ${card.rect.width.toStringAsFixed(0)} px, "
              'icerigi ${card.widestText.toStringAsFixed(0)} px, '
              'olu alan ${card.deadWidth.toStringAsFixed(0)} px '
              '("${card.label}").',
            );
          }

          // ---- OLCUM 4: masaustu yuzeyi bagli mi (SPEC §6) ------------------
          final mounted = probe.mountedDesktopSurfaces(kDesktopSurfaceTypes);
          if (mounted.isEmpty) {
            failures.add(
              'OLCUM 4 (SPEC §6 "BAGLA, ATMA"): cizilen agacta '
              '${kDesktopSurfaceTypes.join(", ")} widget\'larindan HICBIRI yok. '
              'Ekran masaustu yuzeyine degil, mobil agacina bagli.',
            );
          } else {
            notes.add('bagli masaustu yuzeyleri: ${mounted.join(", ")}');
          }

          expect(
            failures,
            isEmpty,
            reason:
                '\n=== ${label(surface).toUpperCase()} @ ${w}x$h ===\n'
                'IHLAL (${failures.length}):\n'
                '${failures.map((f) => "  - $f").join("\n")}\n'
                'OLCUM:\n'
                '${notes.map((n) => "  · $n").join("\n")}\n',
          );
        }),
      );
    }
  }
}
