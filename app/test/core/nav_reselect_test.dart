import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/nav_index.dart';

void main() {
  test('aynı sekmeye basınca index değişmez, reselect tick artar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(navIndexProvider), 0);
    expect(container.read(navReselectProvider).tick, 0);

    container.read(navIndexProvider.notifier).setIndex(0);
    expect(container.read(navIndexProvider), 0);
    expect(container.read(navReselectProvider).tabIndex, kHomeTabIndex);
    expect(container.read(navReselectProvider).tick, 1);

    container.read(navIndexProvider.notifier).setIndex(2);
    expect(container.read(navIndexProvider), 2);
    expect(container.read(navReselectProvider).tick, 1);

    container.read(navIndexProvider.notifier).setIndex(2);
    expect(container.read(navIndexProvider), 2);
    expect(container.read(navReselectProvider).tabIndex, 2);
    expect(container.read(navReselectProvider).tick, 2);
  });
}
