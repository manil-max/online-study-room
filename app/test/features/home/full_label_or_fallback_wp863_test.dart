// WP-863 — "(sen)" SEÇİCİSİ (WP-857) GENİŞLİK DEĞİŞİNCE ERİŞİLEBİLİRLİK
// AĞACINI DA GÜNCELLER; İÇSEL/KURU ÖLÇÜMLERİ ÇİZİMLE TUTARLIDIR.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/home/widgets/leaderboard_card.dart';

const _style = TextStyle(fontSize: 14, fontFamily: 'Roboto');

Widget _host(double width, {TextDirection dir = TextDirection.ltr}) =>
    Directionality(
      textDirection: dir,
      child: Center(
        child: SizedBox(
          width: width,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FullLabelOrFallback(
              full: const Text(
                'Deniz (sen)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style,
              ),
              fallback: const Text(
                'Deniz',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style,
              ),
            ),
          ),
        ),
      ),
    );

List<String> _labels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  final root = tester.binding.rootPipelineOwner;
  final owners = <PipelineOwner>[];
  void collect(PipelineOwner owner) {
    owners.add(owner);
    owner.visitChildren(collect);
  }

  collect(root);
  for (final owner in owners) {
    final node = owner.semanticsOwner?.rootSemanticsNode;
    if (node != null) visit(node);
  }
  return labels;
}

void main() {
  testWidgets('genişlik daralınca ekran okuyucu da kısa adı okur', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(400));
    expect(_labels(tester), contains('Deniz (sen)'));

    await tester.pumpWidget(_host(60));
    expect(find.text('Deniz'), findsOneWidget);
    final labels = _labels(tester);
    expect(labels, contains('Deniz'));
    expect(labels, isNot(contains('Deniz (sen)')));

    await tester.pumpWidget(_host(400));
    final wide = _labels(tester);
    expect(wide, contains('Deniz (sen)'));
    expect(wide, isNot(contains('Deniz')));
    handle.dispose();
  });

  testWidgets('kuru düzen ve içsel ölçüler gerçek düzenle aynı', (
    tester,
  ) async {
    for (final width in [400.0, 60.0]) {
      await tester.pumpWidget(_host(width));
      final box = tester.renderObject<RenderBox>(
        find.byType(FullLabelOrFallback),
      );
      final constraints = box.constraints;
      expect(box.getDryLayout(constraints), box.size, reason: 'w=$width');
      expect(
        box.getMaxIntrinsicHeight(constraints.maxWidth),
        box.size.height,
        reason: 'w=$width',
      );
    }
  });

  testWidgets('taban çizgisine hizalı satırın kuru düzeni düşmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Row(
            key: const Key('row'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('1.', style: TextStyle(fontSize: 22)),
              FullLabelOrFallback(
                full: const Text('Deniz (sen)', style: _style),
                fallback: const Text('Deniz', style: _style),
              ),
            ],
          ),
        ),
      ),
    );
    final row = tester.renderObject<RenderBox>(find.byKey(const Key('row')));
    expect(row.getDryLayout(row.constraints), row.size);
  });

  testWidgets('dokunma yalnız çizilen etikete gider (RTL dahil)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(60, dir: TextDirection.rtl));
    final box = tester.renderObject<RenderBox>(
      find.byType(FullLabelOrFallback),
    );
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.size.center(Offset.zero));
    final hitParagraphs = result.path
        .map((e) => e.target)
        .whereType<RenderParagraph>()
        .map((p) => p.text.toPlainText())
        .toList();
    expect(hitParagraphs, ['Deniz']);
  });
}
