// WP-671 — "mobil gerilmesi" kapisinin OLCUM katmani.
//
// Buradaki her yardimci, kaynak dosyada ne yazdigina DEGIL, karede NE
// BOYANDIGINA bakar. Sebebi depoda kayitli bir ders: "dogruluk kaynagi
// dogruyken ekran bos olabilir" (0126 uretim regresyonu kapi boyunca yesil
// kaldi). `maxWidth: 1440` yazan bir dosya, o kisitin ekrana ulastigini
// kanitlamaz.
//
// Iki teknik nokta:
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
  const PaintedCard(this.rect, this.widestText, this.label);

  final Rect rect;

  /// Kartin icindeki EN GENIS metnin boyanan genisligi.
  final double widestText;
  final String label;

  /// Kart ne kadar genis, icerigi ne kadar dar: "dev kutu, tek satir" olcusu.
  double get deadWidth => rect.width - widestText;
}

/// Cizilen kareyi olcen sonda.
class DesktopStretchProbe {
  DesktopStretchProbe(this.tester) {
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    screenRect = Offset.zero & screen;
    paneRect = _paneRect();
  }

  final WidgetTester tester;
  late final Rect screenRect;

  /// Sol gezinme paneli. Icerik olcumlerinden dislanir: pane genisligi ayri bir
  /// sozlesmedir (`DesktopNavigationPane.expandedWidth`), icerik sutunu degil.
  late final Rect? paneRect;

  Rect? _paneRect() {
    final found = find
        .byType(DesktopNavigationPane, skipOffstage: true)
        .evaluate();
    if (found.isEmpty) return null;
    final ro = found.first.renderObject;
    if (ro is! RenderBox || !ro.hasSize) return null;
    return _globalRect(ro);
  }

  static Rect _globalRect(RenderBox box) =>
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
  static Rect? _ink(RenderParagraph p) {
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

  /// Cizilen agactaki butun gorunur paragraflari dolasir. `Offstage` alt
  /// agaclari atlanir (tembel sekme ana bilgisayari secilmeyen sekmeleri boyle
  /// saklar; atlanmazsa bes sekmenin metni tek karede toplanir).
  void _walk(RenderObject node, void Function(RenderParagraph) visit) {
    if (node is RenderOffstage && node.offstage) return;
    if (node is RenderParagraph) visit(node);
    node.visitChildren((child) => _walk(child, visit));
  }

  RenderObject? get _root => tester.binding.rootElement?.renderObject;

  List<PaintedText> paintedTexts() {
    final out = <PaintedText>[];
    final root = _root;
    if (root == null) return out;
    _walk(root, (p) {
      final ink = _ink(p);
      if (ink == null || !_isContent(ink)) return;
      out.add(PaintedText(p.text.toPlainText(), ink));
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
  RenderObject? _rowAncestor(RenderObject node) {
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
    final groups = <RenderObject, List<PaintedText>>{};
    final root = _root;
    if (root == null) return const [];
    _walk(root, (p) {
      final ink = _ink(p);
      if (ink == null || !_isContent(ink)) return;
      final row = _rowAncestor(p);
      if (row == null) return;
      groups
          .putIfAbsent(row, () => <PaintedText>[])
          .add(PaintedText(p.text.toPlainText(), ink));
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

  /// OLCUM 3 — cizilen kart yuzeyleri ve icerdikleri en genis metin.
  List<PaintedCard> paintedCards() {
    final out = <PaintedCard>[];
    for (final element in find.byType(Card, skipOffstage: true).evaluate()) {
      final ro = element.renderObject;
      if (ro is! RenderBox || !ro.hasSize) continue;
      final rect = _globalRect(ro);
      if (!_isContent(rect)) continue;
      var widest = 0.0;
      var label = '';
      _walk(ro, (p) {
        final ink = _ink(p);
        if (ink == null || ink.width <= widest) return;
        widest = ink.width;
        label = p.text.toPlainText();
      });
      out.add(PaintedCard(rect, widest, label));
    }
    out.sort((a, b) => b.rect.width.compareTo(a.rect.width));
    return out;
  }

  /// OLCUM 4 — cizilen agacta masaustu yuzey widget'i var mi.
  ///
  /// Kaynak taramasi DEGIL: `find.byType(..., skipOffstage: true)` yalnizca
  /// gercekten monte edilmis ve gorunur olan agaci gorur. Bir ekranin dosyasina
  /// `import` eklemek bu olcumu gecirmez.
  List<String> mountedDesktopSurfaces(List<Type> candidates) {
    final found = <String>[];
    for (final type in candidates) {
      final count = find.byType(type, skipOffstage: true).evaluate().length;
      if (count > 0) found.add('$type x$count');
    }
    return found;
  }
}
