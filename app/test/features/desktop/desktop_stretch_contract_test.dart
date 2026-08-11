// WP-671 — MASAUSTUNDE "MOBIL GERILMESI" KAPISI.
// WP-677 — kapinin KENDISI onarildi + kapsam 5 yuzeyden 15 yuzeye cikti.
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
//
// ============================ NEYI KORUR =====================================
//
// 1. Gercek uygulamayi (`OnlineStudyRoomApp`, in-memory depolarla) 1920x1080 ve
//    2560x1440 pencerede, `TargetPlatform.windows` ile CIZER ve masaustunde
//    kullanilan yuzeyleri tek tek gezer (asagidaki tablo).
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
// - **Bilesen duzeyi tavanlar.** Ayri dosya:
//   `desktop_component_ceiling_contract_test.dart` (WP-677 KUSUR 2). Burasi
//   EKRANI olcer; orasi bir bilesenin disindaki kap ne olursa olsun kendi
//   tavanini tasiyip tasimadigini.
//
// ====================== WP-677: KAPININ KUSURLARI ============================
//
// **KUSUR 1 — kapi GORUNMEYENI olcuyordu.** Sonda dosyasinin bas yorumu
// "karede ne boyandigina bakar" diyordu; gezinme ise yalniz `RenderOffstage`
// atliyordu. Tam ekran bir rota acikken altindaki sekme `Offstage` degildir,
// `Overlay` onu `skipCount` ile paint disi birakir. Olculmus sonuc: basarimlar
// ekraninin "boyanan" metinleri arasinda gezinme seridinin `Ctrl+1…5 · Ctrl+,
// Ayarlar` ipucu (12..159 px) ve profil sekmesinin "Gorunum, Ana Sayfa, sayac
// ve bildirimler" satiri (772..1382 px) vardi — kullanici ikisini de gormuyor.
// Yani basarimlar kapisi fiilen PROFIL sekmesini de kisitliyordu ve duzeltme
// WP'lerini yanlis yone itiyordu. Duzeltme sondadadir (`paintsChild` +
// `_RenderTheater`). Olcum: bu duzeltme basarimlar @2560 ekraninda boyandigi
// sanilan 132 metin parcasindan 26'sini eledi.
//
// **KUSUR 3 — 13 mi 14 mu.** Bu basligin eski hali "basarimlar 2560 -> 14
// ihlal" diyordu; WP-674 ajani ayni ekranda 13 olctu. 2026-08-10'da izole bir
// worktree'de `0981ef4` (WP-673 head — WP-674'un basladigi agac) uzerinde eski
// kapi birebir KOSULDU: **13** dogru sayidir, icerik araligi 2512 px. Eski
// basliktaki 14, icerik araligini **2540 px** goren BASKA bir agactan geliyor
// (WP-671'in yazildigi, WP-672'nin commit'lenmemis olcek calismasini tasiyan
// agac); baslik hangi commit oldugunu hic yazmamisti. Fark tek satirdir ve
// rastlanti degil: `0981ef4`'te `wideRows == 4` ve `fatCards == 4`, yani sayim
// tam olarak `take(5)` / `take(4)` sinirinin dibinde duruyordu — bir tane
// fazla genis satir toplami 13'ten 14'e tasiyor. Bu belirsizlik tekrar
// etmesin diye her kosum artik `WP677MEASURE` satirinda TAVANDAN BAGIMSIZ
// dokumu da yazar (`olcum2=<gercek genis satir sayisi>` vb.).
//
// ============================== ESIKLER ======================================
//
// Hepsi EKRAN pikselidir (kullanicinin gordugu), mantiksal piksel degil.
//
// ================== YUZEY TABLOSU (WP-677'de genisledi) ======================
//
// GEZINEREK acilanlar — gercek kabuk, gercek tiklama:
//   ana pano · saat/alarm · saat/timer · saat/gorevler · gruplar · istatistik
//   kisisel · istatistik grup · profil · basarimlar · ayarlar(panel) · calisma
//   kayitlari(panel)
//
// DOGRUDAN monte edilenler — gercek uygulamada `rootNavigator` uzerine TAM
// EKRAN itilen rotalar; kabuk onlari zaten tamamen ortuyor, dolayisiyla
// `MaterialApp.home` olarak cizmek ayni pencere genisligini verir:
//   dersler · sayac gunlugu
//
// UYGULAMANIN BASKA DURUMU:
//   giris ekrani (oturum yok) · onboarding (oturum var, onboarding bitmemis)
//
// 🔴 WP-677'de EKLENEN yuzeylerin bugun KIRMIZI dusmesi beklenir; hicbiri
// masaustu duzenine cevrilmedi. Sayilari `WP677MEASURE` satirlarindadir.
// =============== WP-677 OLCUMU (2026-08-10, HEAD `079ea74`) ==================
//
// 🔴 KUSUR 3'un dersi: sayi, ALINDIGI AGAC yazilmadan kayda gecmez. Asagidaki
// tablo yukaridaki commit'te olculdu; depo o gun paralel calisiyordu, yani
// baska bir commit'te sayilar farkli olabilir. Guncel deger her zaman
// kosumdaki `WP677MEASURE` satiridir.
//
//   yuzey                        1920            2560
//   ana pano                     0  (1170 px)    0  (1170 px)
//   saat / alarm                 0  (1339 px)    0  (1339 px)
//   saat / timer                 0  (1332 px)    0  (1332 px)
//   saat / gorevler              0  ( 735 px)    0  ( 735 px)
//   gruplar / kamp atesi         0  (1376 px)    0  (1376 px)
//   istatistik / kisisel         0  ( 898 px)    0  ( 898 px)
//   istatistik / grup            1  (1282 px)    1  (1282 px)   <- olu alan
//   profil                       0  (1166 px)    0  (1166 px)
//   basarimlar                   0  (1384 px)    0  (1397 px)
//   ayarlar (panel)              0  ( 844 px)    0  ( 844 px)
//   calisma kayitlari (panel)    1  ( 868 px)    1  ( 868 px)   <- OLCUM 4
//   dersler                      2  (1868 px)    2  (2508 px)   <- OLCUM 1+4
//   sayac gunlugu                1  (1193 px)    2  (1513 px)
//   giris ekrani                 0  (1047 px)    0  (1047 px)
//   onboarding                   0  (1005 px)    0  (1005 px)
//
// KUSUR 1 duzeltmesinin ONCE/SONRA farki (ayni gun, ayni agac):
//   basarimlar 1920 : icerik 12..1405 (1392 px) -> 20..1405 (1384 px)
//   basarimlar 2560 : icerik 12..1417 (1405 px) -> 20..1417 (1397 px)
//   diger 8 olcum degismedi; hicbir iddia kirmiziya donmedi.
// Kucuk gorunen bu fark, ELENEN SEYI gizlemesin: basarimlar ekraninda
// "boyaniyor" sanilan 132 metin parcasindan 26'si dustu ve hepsi seride ya da
// alttaki profil sekmesine aitti (`Ctrl+1…5 · Ctrl+, Ayarlar`, `Gorunum, Ana
// Sayfa, sayac ve bildirimler`, `Cikis Yap`, `Sonraki tac`, ...). Sayi az
// degisti cunku basarimlar ekraninin KENDI icerigi zaten o araligi kapliyordu;
// degisen sey, kapinin artik yanlis ekrani kisitlamiyor olmasi.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/features/profile/session_history_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/features/profile/subjects_screen.dart';
import 'package:online_study_room/features/profile/timer_journal_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
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

/// Bir kartin "dev kutu, tek satir" olcusu: kart genisligi eksi icindeki
/// GERCEK icerik kutusunun genisligi.
///
/// 🔴 **WP-684 KUSUR 2 — olcut degisti, ESIK degismedi.** Eskiden cikarilan
/// sey "en genis tek METIN parcasi" idi. Bu, icerigi metin OLMAYAN kartlari
/// (grafik, isi haritasi, karsilastirma tablosu) yapisal olarak
/// cezalandiriyordu: istatistik/grup @1920'de karsilastirma tablosu karti
/// 684 px genisligindeydi ve hucreleri kartin 13..670 px araligini
/// dolduruyordu, ama en genis METNI 62 px oldugu icin "olu alan 622 px" diye
/// kirmizi dusuyordu (olculdu 2026-08-10, HEAD `72ee426`). Artik cikarilan
/// sey `PaintedCard.contentInk`: boyanan glif **ve** cizim kutularinin
/// birlesimi (bkz. `desktop_stretch_probe.dart` `contentInkOf`).
/// Esik 480 px **aynen** kaldi — gevsetilmedi, dogru sey olculuyor.
/// Olcut tek yonlu daralttI: `contentInk` her zaman en genis metni KAPSAR,
/// yani hicbir kart bu degisiklikle kirmiziya donemez, yalniz yanlis
/// kirmiziIar duser.
///
/// **Bu esik SPEC'te YOK; onu WP-671 sectI.** 480 px = 2 x 240 px kenar. SPEC §4
/// masaustu sayfa kenar boslugunu en genis bantta **24 px** diyor; 240 px onun
/// on kati. Bir kartin her iki yaninda 240 px'ten fazla olu alan varsa o kart
/// icerigine gore degil, PENCEREYE gore boyutlanmistir — sahibin "800 px kart,
/// icinde tek bir 2s" sikayetinin olculebilir hali.
const double kMaxCardDeadWidthPx = 480;

/// SPEC §6 "BAGLA, ATMA" karar tablosundaki, ekranlara baglanmasi gereken
/// masaustu yuzey widget'lari.
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

/// Bir yuzeyin olculen dokumu.
///
/// 🔴 KUSUR 3'un kaliCI onarimi. `failures.length` iki olcum arasinda
/// karsilastirilabilir bir sayi DEGILDIR: liste `take(5)` / `take(4)` /
/// `take(3)` ile kirpilir, yani bir yuzeyde 4 ile 6 genis satir arasindaki fark
/// toplamda 1 gorunur. Buradaki alanlar kirpilmamis GERCEK sayilardir.
class SurfaceTally {
  SurfaceTally();

  /// OLCUM 1 ihlali (0 ya da 1).
  int span = 0;

  /// Sert tavani asan etiket-deger satirlarinin TAMAMI.
  int rows = 0;

  /// 760 px'i asan kartlarin TAMAMI.
  int cards = 0;

  /// Olu alan tavanini asan kartlarin TAMAMI.
  int hollow = 0;

  /// OLCUM 4 ihlali (0 ya da 1).
  int unbound = 0;

  int get total => span + rows + cards + hollow + unbound;

  @override
  String toString() =>
      'olcum1=$span olcum2=$rows olcum3=$cards olcum3b=$hollow olcum4=$unbound';
}

void main() {
  final tr = AppLocalizationsTr();

  // 🔴 `debugDefaultTargetPlatformOverride` test GOVDESI BITMEDEN geri
  // alinmali. `_verifyInvariants` tearDown'dan ONCE kosar ve bayrak hala
  // dururken "The value of a foundation debug variable was changed by the
  // test" diye patlar.
  //
  // Bu tuzak bu dosyayi bir kez YALANCI KIRMIZIYA dusurdu: iddialar kirmizi
  // dustugu surece `TestFailure` once firlar ve invariant kontrolu hic
  // gorunmez. `setUp`/`tearDown` cifti bu isi GORMEZ; govdenin ICINDE
  // sarmalayici sart.
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
  ///
  /// 🔴 WP-677 OLCUMU — tek tur YETMIYOR. Dosyanin tamami kosarken "saat /
  /// gorevler @2560" bir kosumda 735 px, digerinde 1060 px icerik olctu ve
  /// ayni iddia bir kosumda yesil bir kosumda kirmizi dustu. Sebep: bir tur
  /// `pumpAndSettle` yalnizca O AN zamanlanmis kareleri tuketir; gec cozulen
  /// bir async saglayici (ya da serit'in 180 ms'lik `AnimatedContainer`i) yeni
  /// kare zamanlayinca olcum yari yolda alinmis oluyor. Uc tur, aralarinda bir
  /// mikro-gorev bosaltma karesiyle, bunu kapatiyor.
  ///
  /// Kararsiz bir kapi, kirik bir kapidan daha kotudur: kirmizi/yesil zar
  /// atmaya donusunce kimse ona bakmaz.
  Future<void> settle(WidgetTester tester) async {
    for (var attempt = 0; attempt < 3; attempt++) {
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
      // Bekleyen mikro-gorevleri (cozulen Future'lari) bosaltir; varsa yeni
      // kare zamanlanir ve bir sonraki tur onu da oturtur.
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void prepareWindow(WidgetTester tester, Size window) {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
  }

  /// Gercek uygulamayi verilen pencerede cizer.
  ///
  /// [signedIn] false ise `AuthGate` giris ekranini cizer; [onboarded] false
  /// ise oturum acilir ama onboarding ekrani ustte kalir (onboarding bayragi
  /// prefs'e yazilmaz).
  Future<void> pumpApp(
    WidgetTester tester,
    Size window, {
    bool signedIn = true,
    bool onboarded = true,
  }) async {
    prepareWindow(tester, window);

    final preferences = await v8SharedPreferences();
    final InMemoryAuthRepository auth = signedIn
        ? await signedInV8AuthRepository(prefs: onboarded ? preferences : null)
        : InMemoryAuthRepository();
    final groupRepository = InMemoryGroupRepository();
    if (signedIn) {
      final profile = (await auth.authStateChanges().first)!;
      // Gruplar sekmesi bos durumda tek satirlik bir bos-durum metni cizer ve
      // hicbir sey olcemez. Kamp atesi + grup kartlari icin bir grup sart.
      await groupRepository.createGroup(name: 'Odak Kampi', creator: profile);
    }

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
          ...desktopInMemoryDataOverrides(),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await settle(tester);
  }

  /// Tam ekran itilen bir rotayi TEK BASINA cizer.
  ///
  /// Bu bir kisaltma degil sadakat karari: `SubjectsScreen`/`TimerJournalScreen`
  /// gercek uygulamada `rootNavigator` uzerine itilir ve kabugu (seridi dahil)
  /// tamamen orter — yani gordugu kap tam olarak pencerenin kendisidir. Ayni
  /// sey basarimlar ekraninda OLCULDU: orada serit boyanmiyor
  /// (`probe.paneRect == null`).
  Future<void> mountFullScreenRoute(
    WidgetTester tester,
    Size window,
    Widget screen,
  ) async {
    prepareWindow(tester, window);
    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);
    final groupRepository = InMemoryGroupRepository();
    final profile = (await auth.authStateChanges().first)!;
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
          ...desktopInMemoryDataOverrides(),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapTab(WidgetTester tester, String tab) async {
    expect(
      find.text(tab),
      findsWidgets,
      reason:
          'Masaustu kabugu cizilmedi: "$tab" sekmesi yok. Kapi bir sey '
          'olcemez; once kabugun ayakta oldugundan emin ol.',
    );
    await tester.tap(find.text(tab).first);
    await settle(tester);
  }

  Future<void> tapOne(WidgetTester tester, Finder finder, String what) async {
    expect(finder, findsWidgets, reason: '$what bulunamadi; yuzey acilamadi.');
    await tester.tap(finder.first);
    await settle(tester);
  }

  // ========================= YUZEY TABLOSU ==================================

  final surfaces =
      <String, Future<DesktopStretchProbe> Function(WidgetTester, Size)>{
        'ana pano': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.homeAnaSayfa);
          return DesktopStretchProbe(tester);
        },
        'saat / alarm': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.desktopSaat);
          return DesktopStretchProbe(tester);
        },
        'saat / timer': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.desktopSaat);
          await tapOne(
            tester,
            find.byKey(const Key('clock_tab_timer')),
            'Saat sekmesindeki timer seridi',
          );
          return DesktopStretchProbe(tester);
        },
        'saat / gorevler': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.desktopSaat);
          await tapOne(
            tester,
            find.byKey(const Key('clock_tab_tasks')),
            'Saat sekmesindeki gorevler seridi',
          );
          return DesktopStretchProbe(tester);
        },
        'gruplar / kamp atesi': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.desktopGruplar);
          return DesktopStretchProbe(tester);
        },
        'istatistik / kisisel': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.statsIstatistik);
          return DesktopStretchProbe(tester);
        },
        'istatistik / grup': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.statsIstatistik);
          await tapOne(
            tester,
            find.widgetWithText(Tab, tr.statsGrup),
            'Istatistik ekranindaki Grup sekmesi',
          );
          return DesktopStretchProbe(tester);
        },
        'profil': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.profileProfil);
          return DesktopStretchProbe(tester);
        },
        'basarimlar': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.profileProfil);
          await tapOne(
            tester,
            find.text(tr.profileRozetlerinSerilerinVeIlerlemen),
            'Profilden basarimlara giris satiri',
          );
          return DesktopStretchProbe(tester);
        },
        'ayarlar (panel)': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.profileProfil);
          await tapOne(
            tester,
            find.widgetWithText(ListTile, tr.profileAyarlar),
            'Profildeki Ayarlar satiri',
          );
          // 🔴 Panel OPAK DEGIL: altindaki profil sekmesi de boyanmaya devam
          // eder ve sonda onu dogru olarak gorur. Kapsam verilmezse ayarlar
          // panelinin sayisi profil sekmesinin sayisiyla toplanir, yani ihlal
          // YANLIS EKRANA yazilir.
          return DesktopStretchProbe(tester, scope: find.byType(SettingsScreen));
        },
        'calisma kayitlari (panel)': (tester, window) async {
          await pumpApp(tester, window);
          await tapTab(tester, tr.profileProfil);
          await tapOne(
            tester,
            find.widgetWithText(ListTile, tr.profileCalismaKayitlarim),
            'Profildeki Calisma kayitlarim satiri',
          );
          return DesktopStretchProbe(
            tester,
            scope: find.byType(SessionHistoryScreen),
          );
        },
        'dersler': (tester, window) async {
          await mountFullScreenRoute(tester, window, const SubjectsScreen());
          return DesktopStretchProbe(tester);
        },
        'sayac gunlugu': (tester, window) async {
          await mountFullScreenRoute(
            tester,
            window,
            const TimerJournalScreen(),
          );
          return DesktopStretchProbe(tester);
        },
        'giris ekrani': (tester, window) async {
          await pumpApp(tester, window, signedIn: false);
          return DesktopStretchProbe(tester);
        },
        'onboarding': (tester, window) async {
          await pumpApp(tester, window, onboarded: false);
          return DesktopStretchProbe(tester);
        },
      };

  for (final window in kWindowSizes) {
    final w = window.width.toInt();
    final h = window.height.toInt();

    for (final entry in surfaces.entries) {
      final label = entry.key;
      final open = entry.value;
      testWidgets(
        '$label @ ${w}x$h — masaustunde mobil gerilmesi yok',
        (tester) async => onWindows(() async {
          final probe = await open(tester, window);

          final failures = <String>[];
          final notes = <String>[];
          final tally = SurfaceTally();

          // ---- OLCUM 1: icerik yatay olarak sinirli mi (SPEC §2.3 = 1440) ----
          final bounds = probe.contentInkBounds();
          if (bounds == null) {
            tally.span++;
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
              tally.span++;
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
          tally.rows = wideRows.length;
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
              'icerik kutusu ${widest.contentInk?.width.toStringAsFixed(0)} px '
              '(icindeki en genis metin '
              '${widest.widestText.toStringAsFixed(0)} px "${widest.label}")',
            );
            // WP-684 ONCE/SONRA: eski (yalniz metin) olcutun ayni kartta ne
            // dedigi. Kirmizi dusurmez; olcut degisiminin etkisi gorunsun.
            final worstOld = cards
                .map((c) => c.textOnlyDeadWidth)
                .reduce((a, b) => a > b ? a : b);
            final worstNew = cards
                .map((c) => c.deadWidth)
                .reduce((a, b) => a > b ? a : b);
            notes.add(
              'olu alan (en kotu kart): yeni olcut '
              '${worstNew.toStringAsFixed(0)} px / eski yalniz-metin olcutu '
              '${worstOld.toStringAsFixed(0)} px',
            );
          }
          final fatCards = cards
              .where((c) => c.rect.width > kMaxCardWidthPx)
              .toList();
          tally.cards = fatCards.length;
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
          tally.hollow = hollow.length;
          for (final card in hollow.take(3)) {
            failures.add(
              'OLCUM 3b (olu alan tavani ${kMaxCardDeadWidthPx.toInt()} px — '
              'esigi WP-671 sectI, SPEC'
              "'te yok): kart ${card.rect.width.toStringAsFixed(0)} px, "
              'GERCEK icerik kutusu (glif + cizim) '
              '${card.contentInk?.width.toStringAsFixed(0)} px, '
              'olu alan ${card.deadWidth.toStringAsFixed(0)} px '
              '(en genis metin ${card.widestText.toStringAsFixed(0)} px '
              '"${card.label}").',
            );
          }

          // ---- OLCUM 4: masaustu yuzeyi bagli mi (SPEC §6) ------------------
          final mounted = probe.mountedDesktopSurfaces(kDesktopSurfaceTypes);
          if (mounted.isEmpty) {
            tally.unbound++;
            failures.add(
              'OLCUM 4 (SPEC §6 "BAGLA, ATMA"): cizilen agacta '
              '${kDesktopSurfaceTypes.join(", ")} widget\'larindan HICBIRI '
              'BOYANMIYOR. Ekran masaustu yuzeyine degil, mobil agacina bagli.',
            );
          } else {
            notes.add('bagli masaustu yuzeyleri: ${mounted.join(", ")}');
          }

          // KUSUR 3: kirpilmamis dokum. Iki olcumu karsilastiran herkes
          // `ihlal=` degil bu satiri okur.
          debugPrint(
            'WP677MEASURE | $label | $w | ihlal=${failures.length} | '
            'dokum[$tally toplam=${tally.total}] | ${notes.join(" ~~ ")}',
          );

          expect(
            failures,
            isEmpty,
            reason:
                '\n=== ${label.toUpperCase()} @ ${w}x$h ===\n'
                'IHLAL (${failures.length}) — kirpilmamis dokum: '
                '$tally toplam=${tally.total}\n'
                '${failures.map((f) => "  - $f").join("\n")}\n'
                'OLCUM:\n'
                '${notes.map((n) => "  · $n").join("\n")}\n',
          );
        }),
      );
    }
  }
}
