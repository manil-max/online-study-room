// WP-677 — SONDANIN KENDI SOZLESMESI ("kapiyi koruyan kapi").
//
// ============================ NEDEN VAR ======================================
//
// `desktop_stretch_probe.dart` bas yorumu bir sey IDDIA eder: "karede ne
// boyandigina bakar". 2026-08-10'a kadar bu iddianin hicbir testi yoktu ve
// iddia YANLISTI: sonda, tam ekran bir rotanin ALTINDA kalan sekmenin metnini
// de "boyanmis" sayiyordu (`Overlay` o girisleri `RenderOffstage` ile degil
// `_RenderTheater.skipCount` ile paint disi birakir). Olculmus sonuc:
// basarimlar ekraninin sayilarina gezinme seridinin `Ctrl+1…5` ipucu ve profil
// sekmesinin ayar satirlari karisiyordu.
//
// Kusur bir kez duzeldi. Bu dosya, TEKRAR bozulursa KIRMIZI dussun diye var:
// olcum katmani da bir sozlesmedir ve sozlesmelerin testi olur.
//
// ============================ NE OLCER =======================================
//
// Uc gorunmezlik bicimi, ucu de minik ve KASITLI olarak kurulmus agaclarda:
//   1. opak bir rota altinda kalan taban rota (`_RenderTheater` skip listesi),
//   2. `Offstage` alt agac (tembel sekme ana bilgisayarinin kullandigi yol),
//   3. `Opacity(opacity: 0)` alt agac.
//
// Ucunde de metin AGACTA VARDIR, kutusu ekranla CAKISIR, ama BOYANMAZ.
// Kullanicinin gordugu sey neyse sondanin gordugu de o olmalidir.
//
// ============================ NE OLCMEZ ======================================
//
// Gercek ekranlari. Onlar `desktop_stretch_contract_test.dart`in isi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_stretch_probe.dart';

const String kAltta = 'ALTTAKI-METIN';
const String kUstte = 'USTTEKI-METIN';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  List<String> paintedTexts(WidgetTester tester) =>
      DesktopStretchProbe(tester).paintedTexts().map((t) => t.text).toList();

  testWidgets(
    'opak `OverlayEntry`nin ALTINDA kalan giris boyanmis sayilmaz',
    (tester) async {
      // 🔴 Bu, `Navigator`in tam ekran rota ittiginde kullandigi mekanizmanin
      // ta kendisi: `Overlay` ustteki OPAK girisin altindakileri
      // `_RenderTheater.skipCount` ile paint disi birakir — `Offstage` ile
      // DEGIL. `MaterialPageRoute` ile kurulan bir ornek bu ayrimi gostermez,
      // cunku `ModalRoute` ayrica kendi `Offstage`ini da kurar ve eski (bozuk)
      // gezinme testi tesadufen gecer. Gercek uygulamada olculen sizinti
      // (basarimlar ekraninda gorunen serit ipucu) buradaki yoldan geliyordu.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      final overlayKey = GlobalKey<OverlayState>();
      final bottom = OverlayEntry(
        // `maintainState` sart: aksi halde ustteki opak giris alttakini
        // agactan tamamen dusurur ve test gorunurlugu degil MONTAJI olcer.
        // Gercek uygulamada `ModalRoute.maintainState` varsayilan true'dur —
        // alttaki sekme monte kalir, sadece boyanmaz.
        maintainState: true,
        builder: (_) => const ColoredBox(
          color: Color(0xFF101010),
          child: Center(child: Text(kAltta)),
        ),
      );

      // 🔴 Once YALNIZ taban giris cizilir. Bu adim atlanamaz: `_RenderTheater`
      // atladigi cocuklari LAYOUT'a da sokmaz, yani hic sahnede olmamis bir
      // giris zaten olculemez ve test kendi kendini etkisiz kilar. Gercek
      // uygulamada sekme once cizilir, rota SONRA itilir — boyutu uzerinde
      // kalir ve eski (bozuk) sonda tam da o boyutu olcerdi.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(key: overlayKey, initialEntries: [bottom]),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        paintedTexts(tester),
        contains(kAltta),
        reason:
            'Taban giris tek basinayken bile boyanmiyorsa sonda zaten kirik; '
            'asagidaki iddia hicbir sey kanitlamaz.',
      );

      final top = OverlayEntry(
        opaque: true,
        builder: (_) => const ColoredBox(
          color: Color(0xFF202020),
          child: Center(child: Text(kUstte)),
        ),
      );
      overlayKey.currentState!.insert(top);
      await tester.pumpAndSettle();

      final painted = paintedTexts(tester);
      expect(
        painted,
        contains(kUstte),
        reason: 'Ustteki giris boyaniyor ama sonda onu gormuyor.',
      );
      expect(
        painted,
        isNot(contains(kAltta)),
        reason:
            'Alttaki giris OPAK bir girisin altinda: kullanici onu GORMUYOR. '
            'Sonda hala olcuyorsa, tam ekran rotalarin (basarimlar, dersler, '
            'sayac gunlugu) sayilarina altlarindaki sekmenin genisligi '
            'karisir — WP-677 KUSUR 1 birebir bu.',
      );

      // Widget agacta HALA duruyor: yani ayrim "monte mi" degil "boyaniyor mu".
      expect(
        find.text(kAltta, skipOffstage: false),
        findsOneWidget,
        reason:
            'Alttaki giris agactan dusmus. O zaman bu test gorunurlugu degil '
            'montaji olcuyor demektir ve KUSUR 1 icin kanit degildir.',
      );

      // 🔴 `OverlayEntry` Overlay'den CIKARILMADAN dispose edilemez; sirasi
      // ters olursa test, iddialarla hicbir ilgisi olmayan bir assertion ile
      // duser. Ustelik bu hata iddialar kirmizi oldugu surece GORUNMEZ
      // (TestFailure once firlar) — sabotaj turu yesile donunce ortaya cikti.
      top.remove();
      bottom.remove();
      await tester.pump();
      top.dispose();
      bottom.dispose();
    },
  );

  testWidgets('Offstage alt agac boyanmis sayilmaz', (tester) async {
    await pumpAt(
      tester,
      const Scaffold(
        body: Column(
          children: [
            Text(kUstte),
            Offstage(offstage: true, child: Text(kAltta)),
          ],
        ),
      ),
    );
    final painted = paintedTexts(tester);
    expect(painted, contains(kUstte));
    expect(painted, isNot(contains(kAltta)));
  });

  testWidgets('sifir opaklikli alt agac boyanmis sayilmaz', (tester) async {
    await pumpAt(
      tester,
      const Scaffold(
        body: Column(
          children: [
            Text(kUstte),
            Opacity(opacity: 0, child: Text(kAltta)),
          ],
        ),
      ),
    );
    final painted = paintedTexts(tester);
    expect(painted, contains(kUstte));
    expect(
      painted,
      isNot(contains(kAltta)),
      reason:
          'Opaklik 0 olan metin ekranda YOKTUR; olcume katilirsa bir ekranin '
          'icerik araligi gorunmeyen bir blok yuzunden genis cikar.',
    );
  });
}
