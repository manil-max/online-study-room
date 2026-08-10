import 'package:flutter/material.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../desktop/desktop_page_scaffold.dart';

/// WP-680 — kullanicinin ILK gordugu ekranlarin (giris / kayit / sifre
/// kurtarma / tanitim turu) masaustu duzen ilkeleri.
///
/// SPEC: `docs/design/DESKTOP-UI-SPEC.md` §2.3 + §3 A3 + §4. Buradaki hicbir
/// sayi uydurma degildir; hepsi [DesktopBreakpoints]ten, yani SPEC §2.1 olcu
/// turetiminden gelir.
///
/// 🔴 OLCULEN KUSUR (WP-680 oncesi, ayni harness, `devicePixelRatio = 1`):
///
/// | ekran | 1920 px pencere | 2560 px pencere |
/// |---|---:|---:|
/// | `RecoveryScreen` en genis cizilen kutu | **1872 px** | **2512 px** |
/// | `OnboardingScreen` birincil dugme | **1872 px** | **2512 px** |
/// | `OnboardingScreen` govde metni | **1872 px** | **2512 px** |
/// | `AuthScreen` form sutunu | 380 px (pencerenin **%20**'si) | 380 px |
///
/// 1872 / 7.5 = **250 karakter** (SPEC §2.1: 1 karakter ≈ 7.5 px). WCAG 2.1
/// SC 1.4.8 tavani 80 karakter = 600 px. Yani kurtarma ve tanitim ekranlari
/// tavani **uc kattan fazla** asiyordu. `AuthScreen` ise ters ucta: pencerenin
/// %80'i bos, form ortada yuzuyor.
///
/// Iki kusur da ayni cumlenin sonucu (SPEC §5.1): *ekranlar mobil icin yazildi,
/// masaustunde yalnizca buyutuldu.*

/// [EntryDesktopSplit] panolarinin test tutamaklari. Kaynakta `maxWidth: 760`
/// yazmasi kanit degildir; test **cizilen kutuyu** bu anahtarlardan okur.
const String kEntryHeroPaneKey = 'entry-hero-pane';
const String kEntryFormPaneKey = 'entry-form-pane';

/// [EntryFormColumn] tutamagi.
const String kEntryFormColumnKey = 'entry-form-column';

/// SPEC §4: masaustu izgara olugu 24 px (WinUI: >640 px pencerede 24 epx).
const double kEntrySplitGutter = 24;

/// SPEC §4: sayfa kenar bosluğu 24 px (≥1440 bandi).
const double kEntryPagePadding = 24;

/// Iki panoya (marka + form) ayrilma esigi.
///
/// [DesktopBreakpoints.large] = 1200, M3'un "bir `large` pencere iki pane
/// tasiyabilir" kurali (SPEC §1.2). Altinda tek sutun kalir: 1200 − 760 (form)
/// − 24 (oluk) − 2×24 (kenar) = 344 px, bir markanin sigacagi en dar pano.
bool entryUsesDesktopSplit(BuildContext context) =>
    isDesktopWindow &&
    MediaQuery.sizeOf(context).width >= DesktopBreakpoints.large;

/// Tek sutunlu masaustu formu: SPEC §2.3 "Form / ayar satiri" = **760 px**.
///
/// Mobilde etkisizdir: 390 px pencerede kullanilabilir genislik zaten 342 px,
/// yani 760'lik tavan hicbir kutuyu kucultmez (olculdu, bkz. WP-680 testi).
class EntryFormColumn extends StatelessWidget {
  const EntryFormColumn({
    required this.child,
    this.maxWidth = DesktopBreakpoints.maxFormWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  /// Tavani [DesktopContent] uygular — SPEC §6 "BAGLA, ATMA": bu yuzeyler
  /// kodda vardi ama `lib/` icinde tek bir cagri yeri yoktu. Elle bir
  /// `Align + ConstrainedBox` yazmak ayni pikseli uretir ama SPEC §6'nin
  /// istedigi baglantiyi kurmaz (WP-671 kapisinin OLCUM 4'u tam bunu olcer).
  @override
  Widget build(BuildContext context) => DesktopContent(
    maxWidth: maxWidth,
    padding: EdgeInsets.zero,
    // 🔴 Olcum tutamagi `SizedBox(width: infinity)`, `ConstrainedBox` DEGIL.
    // Ikinci bir tavan koymak kapiyi SABOTAJA KAPALI yapardi: disaridaki
    // tavan silinse bile ic kutu 760'ta kalir, test yesil yanardi. Sonsuz
    // genislik istemek ise kabin GERCEK tavanini olcer.
    child: SizedBox(
      key: const ValueKey(kEntryFormColumnKey),
      width: double.infinity,
      child: child,
    ),
  );
}

/// Marka panosu + form panosu — `large` (≥1200) ve ustunde giris/kayit ekrani.
///
/// Neden bolme: `AuthScreen` iki **bagimsiz** blok tasir (kimlik bloku: ikon +
/// uygulama adi + mod alt basligi; form bloku: alanlar + dugmeler + baglantilar).
/// SPEC §3 A3 uyarisi tam da bunu soyler: *"A3 yalniz gercekten tek nesneli
/// ekranlarda kullanilir; birden cok bagimsiz blok tasiyan ekranlar A3 degil
/// A2'dir."* Blok **tasinir**, uretilmez: tek bir metin, ikon ya da dugme
/// eklenmez / silinmez / gizlenmez (SPEC §7).
///
/// Genislik toplami: 600 (prose tavani) + 24 (oluk) + 760 (form tavani) =
/// **1384 ≤ 1440** ([DesktopBreakpoints.maxContentWidth]). Hepsi 4'un kati.
class EntryDesktopSplit extends StatelessWidget {
  const EntryDesktopSplit({required this.hero, required this.form, super.key});

  final Widget hero;
  final Widget form;

  @override
  Widget build(BuildContext context) => Center(
    // SPEC §6: bant [DesktopContent]'ten gelir, elle yazilmis bir
    // `ConstrainedBox`tan degil.
    child: DesktopContent(
      maxWidth: DesktopBreakpoints.maxContentWidth,
      padding: const EdgeInsets.all(kEntryPagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                key: const ValueKey(kEntryHeroPaneKey),
                constraints: const BoxConstraints(
                  maxWidth: DesktopBreakpoints.maxProseWidth,
                ),
                child: hero,
              ),
            ),
          ),
          const SizedBox(width: kEntrySplitGutter),
          SizedBox(
            key: const ValueKey(kEntryFormPaneKey),
            width: DesktopBreakpoints.maxFormWidth,
            child: form,
          ),
        ],
      ),
    ),
  );
}
