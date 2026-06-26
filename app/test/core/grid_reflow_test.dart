import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/grid/grid_reflow.dart';

void main() {
  group('placeGridItem', () {
    test('bos hedefte diger kartlari oynatmaz', () {
      final result = placeGridItem(
        items: const [
          GridItemBounds(id: 'a', x: 0, y: 0, w: 3, h: 2),
          GridItemBounds(id: 'b', x: 3, y: 0, w: 3, h: 2),
        ],
        id: 'a',
        x: 0,
        y: 2,
        w: 3,
        h: 2,
        columns: 6,
      );

      expect(result, const [
        GridItemBounds(id: 'a', x: 0, y: 2, w: 3, h: 2),
        GridItemBounds(id: 'b', x: 3, y: 0, w: 3, h: 2),
      ]);
    });

    test('carpisan komsuyu asagi iter', () {
      final result = placeGridItem(
        items: const [
          GridItemBounds(id: 'a', x: 0, y: 0, w: 3, h: 2),
          GridItemBounds(id: 'b', x: 0, y: 2, w: 3, h: 2),
        ],
        id: 'a',
        x: 0,
        y: 1,
        w: 3,
        h: 2,
        columns: 6,
      );

      expect(result, const [
        GridItemBounds(id: 'a', x: 0, y: 1, w: 3, h: 2),
        GridItemBounds(id: 'b', x: 0, y: 3, w: 3, h: 2),
      ]);
    });

    test('zincir carpisma asagi dogru yayilir', () {
      final result = placeGridItem(
        items: const [
          GridItemBounds(id: 'a', x: 0, y: 0, w: 6, h: 2),
          GridItemBounds(id: 'b', x: 0, y: 2, w: 6, h: 2),
          GridItemBounds(id: 'c', x: 0, y: 4, w: 6, h: 2),
        ],
        id: 'a',
        x: 0,
        y: 1,
        w: 6,
        h: 2,
        columns: 6,
      );

      expect(result, const [
        GridItemBounds(id: 'a', x: 0, y: 1, w: 6, h: 2),
        GridItemBounds(id: 'b', x: 0, y: 3, w: 6, h: 2),
        GridItemBounds(id: 'c', x: 0, y: 5, w: 6, h: 2),
      ]);
    });

    test('bosluklari kendiliginden sikistirmaz', () {
      final result = placeGridItem(
        items: const [
          GridItemBounds(id: 'a', x: 0, y: 0, w: 3, h: 2),
          GridItemBounds(id: 'b', x: 0, y: 8, w: 3, h: 2),
        ],
        id: 'a',
        x: 3,
        y: 0,
        w: 3,
        h: 2,
        columns: 6,
      );

      expect(result[1], const GridItemBounds(id: 'b', x: 0, y: 8, w: 3, h: 2));
    });

    test('hedefi sutun ve minimum boyut sinirlarina kirpar', () {
      final result = placeGridItem(
        items: const [GridItemBounds(id: 'a', x: 0, y: 0, w: 3, h: 2)],
        id: 'a',
        x: 9,
        y: -3,
        w: 12,
        h: 0,
        columns: 6,
      );

      expect(
        result.single,
        const GridItemBounds(id: 'a', x: 0, y: 0, w: 6, h: 1),
      );
    });
  });
}
