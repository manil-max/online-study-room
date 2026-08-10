// WP-678 — saat/Araclar sekmesinin OLCUM katmani.
//
// WP-671'in `test/features/desktop/desktop_stretch_probe.dart` sondasiyla ayni
// teknigi kullanir; **kopyalanmasinin sebebi bagimsizliktir**: o dosya baska bir
// lane tarafindan ayni anda degistiriliyor (`git status` 2026-08-10:
// `M app/test/features/desktop/desktop_stretch_probe.dart`) ve bu kapinin
// kirmizi/yesil olmasi baska bir ajanin yarim commit'ine bagli olamaz.
//
// Iki teknik nokta (ikisi de WP-671'de olculdu):
//
//  1. **Ink != kutu.** `Expanded(child: Text('Alarm'))` icindeki
//     `RenderParagraph`in KUTUSU tum satiri kaplar; boyanan glifler solda kalir.
//     `tester.getRect` etiket-deger mesafesini SIFIR gosterir. Bu yuzden glif
//     kutulari `getBoxesForSelection` ile alinir.
//  2. **Ekran koordinati != mantiksal koordinat.** Butun olcumler
//     `getTransformTo(null)` ile global (ekran) koordinatina cevrilir.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';

/// Ekranda boyanan bir metin parcasi (global koordinat).
class PaintedText {
  const PaintedText(this.text, this.rect);

  final String text;
  final Rect rect;
}

/// Ayni gorsel satirda duran, en soldaki "etiket" ile en sagdaki "deger".
class LabelValueRow {
  const LabelValueRow(this.label, this.value);

  final PaintedText label;
  final PaintedText value;

  /// SPEC KURAL 2.2'nin olctugu mesafe: etiketin SOL kenari -> degerin SAG
  /// kenari.
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

  /// Kart ne kadar genis, icerigi ne kadar dar.
  double get deadWidth => rect.width - widestText;
}

/// Cizilen kareyi olcen sonda.
class ClockStretchProbe {
  ClockStretchProbe(this.tester) {
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    screenRect = Offset.zero & screen;
    paneRect = _paneRect();
  }

  final WidgetTester tester;
  late final Rect screenRect;

  /// Sol gezinme paneli. Icerik olcumlerinden dislanir: pane genisligi ayri bir
  /// sozlesmedir, icerik sutunu degil.
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

  static Rect _globalRect(RenderBox box) => MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );

  /// `Icon` da bir `RenderParagraph`tir. Bir ikonu "etiket" ya da "deger"
  /// saymak kapiyi anlamsizlastirir; ozel kullanim alanindaki tek kod noktali
  /// paragraflar atlanir.
  static bool _isIconGlyph(String text) {
    final trimmed = text.trim();
    if (trimmed.runes.length != 1) return false;
    final code = trimmed.runes.first;
    return code >= 0xE000 && code <= 0xF8FF;
  }

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
  /// [maxValueChars]: sagdaki metnin "deger" sayilmasi icin ust sinir. SPEC
  /// KURAL 2.2 bir *etiket-deger satirini* tarif eder, duz metni degil.
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

  /// Verilen tipten cizilen (offstage olmayan) widget'in global kutusu.
  Rect? globalRectOf(Finder finder) {
    final found = finder.evaluate();
    if (found.isEmpty) return null;
    final ro = found.first.renderObject;
    if (ro is! RenderBox || !ro.hasSize) return null;
    return _globalRect(ro);
  }
}
