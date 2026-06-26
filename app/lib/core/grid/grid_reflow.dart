class GridItemBounds {
  const GridItemBounds({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  }) : assert(w >= 1),
       assert(h >= 1);

  final String id;
  final int x;
  final int y;
  final int w;
  final int h;

  GridItemBounds copyWith({int? x, int? y, int? w, int? h}) {
    return GridItemBounds(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
    );
  }

  bool overlaps(GridItemBounds other) {
    return x < other.x + other.w &&
        x + w > other.x &&
        y < other.y + other.h &&
        y + h > other.y;
  }

  @override
  bool operator ==(Object other) =>
      other is GridItemBounds &&
      other.id == id &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(id, x, y, w, h);

  @override
  String toString() => 'GridItemBounds($id, x:$x y:$y w:$w h:$h)';
}

List<GridItemBounds> placeGridItem({
  required List<GridItemBounds> items,
  required String id,
  required int x,
  required int y,
  required int w,
  required int h,
  required int columns,
}) {
  assert(columns >= 1);
  final index = items.indexWhere((item) => item.id == id);
  if (index < 0) return items;

  final result = [...items];
  final target = _clamp(
    result[index],
    x: x,
    y: y,
    w: w,
    h: h,
    columns: columns,
  );
  result[index] = target;

  final queue = <String>[id];
  var guard = 0;
  while (queue.isNotEmpty) {
    if (guard++ > result.length * result.length * 4) {
      throw StateError('Grid reflow loop detected');
    }

    final currentId = queue.removeAt(0);
    final current = result.firstWhere((item) => item.id == currentId);
    final colliders =
        result
            .where((item) => item.id != current.id && current.overlaps(item))
            .toList()
          ..sort((a, b) {
            final byY = a.y.compareTo(b.y);
            if (byY != 0) return byY;
            return a.x.compareTo(b.x);
          });

    for (final collider in colliders) {
      final colliderIndex = result.indexWhere((item) => item.id == collider.id);
      final moved = _clamp(
        collider,
        x: collider.x,
        y: current.y + current.h,
        w: collider.w,
        h: collider.h,
        columns: columns,
      );
      if (moved != collider) {
        result[colliderIndex] = moved;
        queue.add(moved.id);
      }
    }
  }

  return result;
}

GridItemBounds _clamp(
  GridItemBounds item, {
  required int x,
  required int y,
  required int w,
  required int h,
  required int columns,
}) {
  final safeW = w.clamp(1, columns);
  return item.copyWith(
    x: x.clamp(0, columns - safeW),
    y: y < 0 ? 0 : y,
    w: safeW,
    h: h < 1 ? 1 : h,
  );
}
