// WP-671 — "mobil gerilmesi" kapisinin OLCUM katmani.
// WP-677 — GORUNURLUK duzeltmesi (asagida "KUSUR 1").
//
// Buradaki her yardimci, kaynak dosyada ne yazdigina DEGIL, karede NE
// BOYANDIGINA bakar. Sebebi depoda kayitli bir ders: "dogruluk kaynagi
// dogruyken ekran bos olabilir" (0126 uretim regresyonu kapi boyunca yesil
// kaldi). `maxWidth: 1440` yazan bir dosya, o kisitin ekrana ulastigini
// kanitlamaz.
//
// Uc teknik nokta:
//
//  1. **Ink != kutu.** `Expanded(child: Text('Bugun ozeti'))` icindeki
//     `RenderParagraph`in KUTUSU tum satiri kaplar; boyanan glifler solda
//     kalir. `tester.getRect` kutuyu verir ve etiket-deger mesafesini SIFIR
//     gosterir. Bu yuzden glif kutulari `getBoxesForSelection` ile alinir.
//
//  2. **Ekran koordinati != mantiksal koordinat.** `DesktopProportionalScale`
//     tum agaci `FittedBox` ile buyutuyordu; `RenderBox.size` olcegin ALTINDA
//     kalir, kullanicinin gordugu piksel ise olcegin USTUNDEDIR. Butun
//     olcumler `getTransformTo(null)` ile EKRAN (global) koordinatina cevrilir.
//     Olcek kaldirilinca (SPEC §0) ikisi zaten esitlenir; kapi iki durumda da
//     ayni seyi olcer.
//
//  3. **🔴 KUSUR 1 (WP-677) — "boyanmayan" ile "agacta olmayan" ayni sey
//     DEGIL.** Bu dosya 2026-08-10'a kadar YALAN soyluyordu: bas yorumu
//     "karede ne boyandigina bakar" diyordu ama `_walk` yalniz `RenderOffstage`
//     atliyordu. Tam ekran bir rota (ornegin basarimlar) acikken altindaki
//     sekme `Offstage` DEGILDIR — `Overlay`in render nesnesi `_RenderTheater`
//     onu `skipCount` ile paint/hit-test disinda birakir ama `visitChildren`
//     yine gezer. Sonuc: kapi kullanicinin GORMEDIGI metni olcuyordu.
//
//     Olculmus kanit (duzeltmeden once, basarimlar @1920): "boyanan" en soldaki
//     metin x=12 px'te basliyordu; oysa basarimlar ekraninin kendi icerigi
//     x=232'de basliyor. Aradaki fark, altta duran PROFIL sekmesiydi. Kapi bu
//     yuzden basarimlar ekranina profil sekmesinin genisligini de yaziyor ve
//     duzeltme WP'lerini yanlis yone itiyordu.
//
//     Duzeltme: cocuklar `RenderObject.paintsChild` ile suzulur (bu, `Offstage`
//     + sifir opaklik + kaydirma listesinin canli tutulan ama cizilmeyen
//     ogelerini kapsar) ve `_RenderTheater` icin `visitChildrenForSemantics`
//     kullanilir — cerceve orada zaten YALNIZ sahnedeki (onstage) girisleri
//     gezer. Ayni suzgec `find.byType` sonuclarina da uygulanir
//     ([isPainted]): bir `Card` ya da masaustu yuzey widget'i offstage bir
//     rotanin icindeyse "cizilmis" sayilmaz.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';

/// Ekranda boyanan bir metin parcasi (global koordinat).
class PaintedText {
  const PaintedText(this.text, this.rect);

  final String text;
  final Rect rect;

  @override
  String toString() =>
      '"$text" ${rect.left.toStringAsFixed(0)}..${rect.right.toStringAsFixed(0)}';
}

/// Ayni gorsel satirda duran, en soldaki "etiket" ile en sagdaki "deger".
class LabelValueRow {
  const LabelValueRow(this.label, this.value);

  final PaintedText label;
  final PaintedText value;

  /// SPEC KURAL 2.2'nin olctugu mesafe: etiketin SOL kenari -> degerin SAG
  /// kenari. (Aradaki bosluk degil; satirin tamami.)
  double get span => value.rect.right - label.rect.left;

  /// Gozun atlamak zorunda kaldigi bos aralik.
  double get gap => value.rect.left - label.rect.right;
}

/// Ekranda boyanan bir kart yuzeyi.
class PaintedCard {
  const PaintedCard(this.rect, this.widestText, this.label, this.contentInk);

  final Rect rect;

  /// Kartin icindeki EN GENIS metnin boyanan genisligi. Yalniz RAPOR icin.
  final double widestText;
  final String label;

  /// Kartin GERCEK icerik kutusu: boyanan butun isaretlerin (glif **ve**
  /// cizim) birlesimi. Bos kartta null.
  ///
  /// 🔴 WP-684 KUSUR 2 — [deadWidth] eskiden `rect.width - widestText` idi,
  /// yani olcut olarak **en genis tek METIN parcasini** aliyordu. Bu, icerigi
  /// metin OLMAYAN kartlari (grafik, tablo, isi haritasi) yapisal olarak
  /// cezalandiriyordu: olculdu (2026-08-10, HEAD `72ee426`, istatistik/grup
  /// @1920) karsilastirma tablosu karti 684 px genisligindeydi, hucreleri
  /// [144..317] [321..493] [497..670] px araliklarini dolduruyordu — yani
  /// kartin neredeyse tamami doluydu — ama en genis METNI 62 px oldugu icin
  /// "olu alan 622 px" diye kirmizi dusuyordu. Kapinin kendi yorumu bu esigi
  /// zaten *"WP-671 sectI, SPEC'te yok"* diye isaretliyordu.
  final Rect? contentInk;

  /// Kart ne kadar genis, icerigi ne kadar dar: "dev kutu, tek satir" olcusu.
  double get deadWidth => rect.width - (contentInk?.width ?? 0);

  /// Eski (WP-671) olcut. Kirmizi dusurmez; ONCE/SONRA karsilastirmasi icin
  /// dokume yazilir.
  double get textOnlyDeadWidth => rect.width - widestText;
}

/// ============================ GORUNURLUK ===================================
///
/// Bu bolumdeki uc yardimci KUSUR 1'in duzeltmesidir; hem sonda (`_walk`) hem
/// de `find.byType` tabanli olcumler bunlari kullanir.

/// `Overlay`in render nesnesi. Sinif OZELDIR (`_RenderTheater`,
/// `packages/flutter/lib/src/widgets/overlay.dart:1194`), disari acilmis bir
/// tipi yoktur; bu yuzden tur ADIYLA taninir.
///
/// Neden ozel muamele: `_RenderTheater.visitChildren` BUTUN girisleri gezer
/// (a.g.e. :1553), oysa boyanan yalniz `skipCount`'tan sonrakilerdir. Cerceve
/// ayni ayrimi `visitChildrenForSemantics` icinde zaten yapar (a.g.e. :1564,
/// `_firstOnstageChild`) — biz de onu kullaniriz.
bool _isTheater(RenderObject node) =>
    node.runtimeType.toString() == '_RenderTheater';

/// [parent] bu kareyi cizerken [child]'i BOYAR mi?
bool _parentPaints(RenderObject parent, RenderObject child) {
  if (_isTheater(parent)) {
    var onstage = false;
    parent.visitChildrenForSemantics((candidate) {
      if (identical(candidate, child)) onstage = true;
    });
    return onstage;
  }
  // `RenderOffstage` (offstage), `RenderOpacity`/`RenderAnimatedOpacity`
  // (alpha 0), `RenderTransform` (tekil matris) ve
  // `RenderSliverMultiBoxAdaptor` (canli tutulan ama cizilmeyen oge) bu
  // yontemi override eder. Varsayilan `true`dur.
  return parent.paintsChild(child);
}

/// [node] kokten kendisine kadar her adimda boyaniyor mu?
///
/// `find.byType(..., skipOffstage: true)` bu soruyu YANITLAMAZ: finder yalnizca
/// `Offstage` widget'ini bilir, `Overlay`in atladigi girisleri bilmez.
bool isPainted(RenderObject node) {
  var child = node;
  var parent = child.parent;
  while (parent != null) {
    if (!_parentPaints(parent, child)) return false;
    child = parent;
    parent = parent.parent;
  }
  return true;
}

/// Cizilen kareyi olcen sonda.
class DesktopStretchProbe {
  /// [scope] verilirse olcum o alt agacla SINIRLANIR.
  ///
  /// Neden gerekli: `showDesktopPanel` ile acilan yuzeyler (Ayarlar, Calisma
  /// kayitlarim) OPAK DEGILDIR — altlarindaki sekme de boyanmaya devam eder ve
  /// dogru olarak [walk] tarafindan gorulur. Kapsam verilmezse o yuzeyin sayisi
  /// altindaki sekmenin sayisiyla toplanir ve ihlal YANLIS EKRANA yazilir.
  /// Kapsam verildiginde serit dislama da kapanir: panelin icinde serit yoktur.
  DesktopStretchProbe(this.tester, {this.scope}) {
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    screenRect = Offset.zero & screen;
    paneRect = scope == null ? _paneRect() : null;
  }

  final WidgetTester tester;

  /// Olcumun sinirlandigi alt agac; null ise butun kare.
  final Finder? scope;

  late final Rect screenRect;

  /// Sol gezinme paneli. Icerik olcumlerinden dislanir: pane genisligi ayri bir
  /// sozlesmedir (`DesktopNavigationPane.expandedWidth`), icerik sutunu degil.
  ///
  /// 🔴 Yalnizca GERCEKTEN boyaniyorsa dislanir. Tam ekran bir rota serit'i
  /// ortuyorsa serit yoktur; o durumda ekranin sol yarisi da olculmelidir.
  late final Rect? paneRect;

  Rect? _paneRect() {
    for (final element
        in find.byType(DesktopNavigationPane, skipOffstage: true).evaluate()) {
      final ro = element.renderObject;
      if (ro is! RenderBox || !ro.hasSize) continue;
      if (!isPainted(ro)) continue;
      return globalRect(ro);
    }
    return null;
  }

  static Rect globalRect(RenderBox box) =>
      MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

  /// `Icon` da bir `RenderParagraph`tir (ikon fontunun ozel kullanim alanindaki
  /// tek bir kod noktasini cizer). Metin olcumlerine karismamali: bir ikonu
  /// "etiket" ya da "deger" saymak kapiyi anlamsizlastirir.
  static bool _isIconGlyph(String text) {
    final trimmed = text.trim();
    if (trimmed.runes.length != 1) return false;
    final code = trimmed.runes.first;
    // Unicode Private Use Area — MaterialIcons/Cupertino kod noktalari.
    return code >= 0xE000 && code <= 0xF8FF;
  }

  /// [p]'nin ekranda boyanan glif kutusu; bos/ikon/gorunmez ise null.
  static Rect? ink(RenderParagraph p) {
    if (!p.hasSize) return null;
    final text = p.text.toPlainText();
    if (text.trim().isEmpty || _isIconGlyph(text)) return null;
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    if (boxes.isEmpty) return null;
    var local = boxes.first.toRect();
    for (final box in boxes.skip(1)) {
      local = local.expandToInclude(box.toRect());
    }
    return MatrixUtils.transformRect(p.getTransformTo(null), local);
  }

  bool _isContent(Rect rect) {
    if (!rect.overlaps(screenRect)) return false;
    final pane = paneRect;
    if (pane != null && rect.center.dx < pane.right) return false;
    return true;
  }

  /// Cizilen agactaki butun BOYANAN paragraflari dolasir.
  ///
  /// Boyanmayan alt agaclar atlanir: `Offstage` (tembel sekme ana bilgisayari
  /// secilmeyen sekmeleri boyle saklar), sifir opaklik, ve `Overlay`in
  /// ustundeki opak rotanin altinda kalan girisleri (bkz. dosya basi KUSUR 1).
  static void walk(RenderObject node, void Function(RenderParagraph) visit) {
    if (node is RenderParagraph) visit(node);
    node.visitChildren((child) {
      if (!_parentPaints(node, child)) return;
      walk(child, visit);
    });
  }

  RenderObject? get _root {
    final scope = this.scope;
    if (scope == null) return tester.binding.rootElement?.renderObject;
    final found = scope.evaluate();
    if (found.isEmpty) return null;
    return found.first.renderObject;
  }

  /// [matching]'i kapsamla sinirlar.
  Finder _within(Finder matching) {
    final scope = this.scope;
    if (scope == null) return matching;
    return find.descendant(of: scope, matching: matching, matchRoot: true);
  }

  List<PaintedText> paintedTexts() {
    final out = <PaintedText>[];
    final root = _root;
    if (root == null) return out;
    walk(root, (p) {
      final rect = ink(p);
      if (rect == null || !_isContent(rect)) return;
      out.add(PaintedText(p.text.toPlainText(), rect));
    });
    return out;
  }

  /// OLCUM 1 — icerigin ekranda kapladigi yatay aralik.
  ///
  /// En soldaki glif ile en sagdaki glif arasi. Bir ekranin icerigi pencereyle
  /// birlikte sonsuza kadar buyuyorsa bu sayi da buyur; sinirlanmissa sabit
  /// kalir.
  Rect? contentInkBounds() {
    Rect? union;
    for (final t in paintedTexts()) {
      union = union == null ? t.rect : union.expandToInclude(t.rect);
    }
    return union;
  }

  /// Bir render dugumunun en yakin "satir" atasi (yatay `Flex` ya da
  /// `ListTile`). Gruplama bunun uzerinden yapilir; yoksa iki AYRI kartta ayni
  /// y'de duran metinler yanlislikla "ayni satir" sayilirdi.
  static RenderObject? _rowAncestor(RenderObject node) {
    var current = node.parent;
    while (current != null) {
      if (current is RenderFlex && current.direction == Axis.horizontal) {
        return current;
      }
      if (current.runtimeType.toString().contains('ListTile')) return current;
      current = current.parent;
    }
    return null;
  }

  /// OLCUM 2 — ayni satirdaki etiket/deger ciftleri.
  ///
  /// [maxValueChars]: sagdaki metnin "deger" sayilmasi icin ust sinir. Bu kasti
  /// bir daraltmadir: SPEC KURAL 2.2 bir *etiket-deger satirini* tarif eder,
  /// duz metni degil. Sinir olmasa iki cumlelik bir paragraf + buton da ihlal
  /// sayilir ve kapi yalan soylerdi.
  List<LabelValueRow> labelValueRows({int maxValueChars = 16}) {
    final root = _root;
    if (root == null) return const [];
    return labelValueRowsIn(root, accept: _isContent, maxValueChars: maxValueChars);
  }

  /// [root] alt agacindaki etiket-deger satirlari. Hem tam ekran olcumu hem de
  /// IZOLE bilesen olcumu (WP-677 KUSUR 2) ayni kodu kullanir.
  static List<LabelValueRow> labelValueRowsIn(
    RenderObject root, {
    bool Function(Rect rect)? accept,
    int maxValueChars = 16,
  }) {
    final groups = <RenderObject, List<PaintedText>>{};
    walk(root, (p) {
      final rect = ink(p);
      if (rect == null) return;
      if (accept != null && !accept(rect)) return;
      final row = _rowAncestor(p);
      if (row == null) return;
      groups
          .putIfAbsent(row, () => <PaintedText>[])
          .add(PaintedText(p.text.toPlainText(), rect));
    });

    final rows = <LabelValueRow>[];
    for (final items in groups.values) {
      if (items.length < 2) continue;
      items.sort((a, b) => a.rect.left.compareTo(b.rect.left));
      for (var i = 0; i + 1 < items.length; i++) {
        final a = items[i];
        final b = items[i + 1];
        final tolerance =
            (a.rect.height < b.rect.height ? a.rect.height : b.rect.height) / 2;
        if ((a.rect.center.dy - b.rect.center.dy).abs() > tolerance) continue;
        if (b.text.trim().length > maxValueChars) continue;
        rows.add(LabelValueRow(a, b));
      }
    }
    rows.sort((a, b) => b.span.compareTo(a.span));
    return rows;
  }

  /// En ince cizgi kalinligi: bundan ince bir kutu **isaret degil, cetveldir**.
  ///
  /// `Divider` bir `RenderDecoratedBox`tur ve kabinin tamamini kaplar (yuksekligi
  /// `thickness`, varsayilan 1 px). Sayilsaydi, icinde bir ayrac bulunan HER
  /// kart otomatik olarak "dolu" gorunur ve olcut sessizce olurdu.
  /// 4 px, SPEC §4'un "butun olculer 4'un kati" (WinUI) tabanidir.
  static const double kMinMarkExtent = 4;

  /// [node] ekrana bir sey CIZER mi (kap degil, isaret)?
  static bool _isMark(RenderObject node) =>
      node is RenderCustomPaint ||
      node is RenderImage ||
      node is RenderDecoratedBox;

  /// [node] altinda baska bir isaret ya da metin var mi?
  ///
  /// Bu, "cizim" ile "kap" arasindaki ayrimin TEK olcutudur: bir cizim
  /// YAPRAKTIR. Icinde metin ya da baska cizim tasiyan bir `RenderDecoratedBox`
  /// bir arka plan/kap'tir, cizilen icerik degildir — icerigi zaten cocuklari
  /// temsil eder.
  static bool _hasMarkOrTextDescendant(RenderObject node) {
    var found = false;
    void visit(RenderObject current) {
      if (found) return;
      current.visitChildren((child) {
        if (found) return;
        if (!_parentPaints(current, child)) return;
        if (child is RenderParagraph || _isMark(child)) {
          found = true;
          return;
        }
        visit(child);
      });
    }

    visit(node);
    return found;
  }

  /// Bir kartin GERCEK icerik kutusu: boyanan glif kutulari **ve** YAPRAK
  /// cizim kutularinin birlesimi.
  ///
  /// Iki sey bilerek DISARIDA:
  ///
  ///  · **Kartin kendi yuzeyi.** Her `Card` icin kart genisliginde bir
  ///    `RenderPhysicalShape` (Material govdesi) ve bir `RenderCustomPaint`
  ///    (Material'in kenarlik boyayicisi) cizilir — olculdu, istisnasiz.
  ///    Sayilsalardi olu alan HER kartta ~0 cikar, yani olcut kendini
  ///    kapatirdi (sahte yesil). Ikisi de icerigin ATASIDIR, yani yaprak
  ///    degildir; [_hasMarkOrTextDescendant] onlari eler. Kart genisligine
  ///    bakan bir kural yerine bunu kullanmak gerekliydi: `Card` varsayilan
  ///    olarak 4 px kenar payi tasir, yani yuzey kartin kendisinden 8 px
  ///    dardir ve genislik karsilastirmasi onu KACIRIR (olculdu: kart 1400,
  ///    yuzey 1392 — ilk denemede tam olarak bu sahte yesili uretti).
  ///
  ///  · **Kil payi cizgiler.** [kMinMarkExtent]'ten ince kutular icerik
  ///    degildir. `Divider` kabin tamamini kaplayan bir `RenderDecoratedBox`
  ///    cizer ve YAPRAKTIR; sayilsaydi icinde ayrac bulunan her kart "dolu"
  ///    gorunurdu.
  static Rect? contentInkOf(RenderBox card) {
    Rect? union;
    void add(Rect r) {
      union = union == null ? r : union!.expandToInclude(r);
    }

    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        final r = ink(node);
        if (r != null) add(r);
      } else if (node is RenderBox && node.hasSize && _isMark(node)) {
        final r = globalRect(node);
        final isHairline =
            r.height < kMinMarkExtent || r.width < kMinMarkExtent;
        if (!isHairline && !_hasMarkOrTextDescendant(node)) add(r);
      }
      node.visitChildren((child) {
        if (!_parentPaints(node, child)) return;
        visit(child);
      });
    }

    visit(card);
    return union;
  }

  /// OLCUM 3 — cizilen kart yuzeyleri ve icerdikleri icerik kutusu.
  List<PaintedCard> paintedCards() {
    final out = <PaintedCard>[];
    for (final element
        in _within(find.byType(Card, skipOffstage: true)).evaluate()) {
      final ro = element.renderObject;
      if (ro is! RenderBox || !ro.hasSize) continue;
      // 🔴 KUSUR 1: finder offstage bir ROTANIN icindeki karti da bulur.
      if (!isPainted(ro)) continue;
      final rect = globalRect(ro);
      if (!_isContent(rect)) continue;
      var widest = 0.0;
      var label = '';
      walk(ro, (p) {
        final rect = ink(p);
        if (rect == null || rect.width <= widest) return;
        widest = rect.width;
        label = p.text.toPlainText();
      });
      out.add(PaintedCard(rect, widest, label, contentInkOf(ro)));
    }
    out.sort((a, b) => b.rect.width.compareTo(a.rect.width));
    return out;
  }

  /// OLCUM 4 — cizilen agacta masaustu yuzey widget'i var mi.
  ///
  /// Kaynak taramasi DEGIL: `find.byType(..., skipOffstage: true)` yalnizca
  /// gercekten monte edilmis agaci gorur, [isPainted] ise ustune "ve su anda
  /// BOYANIYOR" sartini koyar. Bir ekranin dosyasina `import` eklemek de,
  /// altta duran baska bir sekmede monte olmus olmak da bu olcumu gecirmez.
  List<String> mountedDesktopSurfaces(List<Type> candidates) {
    final found = <String>[];
    for (final type in candidates) {
      var count = 0;
      for (final element
          in _within(find.byType(type, skipOffstage: true)).evaluate()) {
        final ro = element.renderObject;
        if (ro == null || !isPainted(ro)) continue;
        count++;
      }
      if (count > 0) found.add('$type x$count');
    }
    return found;
  }
}
